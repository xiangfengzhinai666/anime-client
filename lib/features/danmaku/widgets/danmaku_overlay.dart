import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/danmaku_models.dart';

/// 弹幕渲染层（自绘）。
///
/// 设计要点：
/// - 位置由外部传入的 `position` 驱动，内部用 Ticker 插值，保证暂停/倍速都平滑；
/// - 轨道分配是"增量式"的：新弹幕进来时找一条尾部已清空的轨道，找不到就丢弃（同屏上限）；
/// - seek（位置大幅跳变）时整体重建，避免残留。
class DanmakuOverlay extends StatefulWidget {
  const DanmakuOverlay({
    super.key,
    required this.items,
    required this.position,
    required this.playing,
    this.playbackRate = 1.0,
    this.opacity = 0.85,
    this.fontSize = 22,
    this.speedFactor = 1.0,
    this.maxOnScreen = 80,
    this.blockedPattern,
    this.enabled = true,
  });

  final List<DanmakuItem> items;

  /// 播放器当前进度。
  final Duration position;
  final bool playing;
  final double playbackRate;

  /// 0~1。
  final double opacity;
  final double fontSize;

  /// 滚动速度倍率（越大越快）。
  final double speedFactor;
  final int maxOnScreen;

  /// 屏蔽词正则（已拼接）。
  final RegExp? blockedPattern;
  final bool enabled;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuLine {
  _DanmakuLine({
    required this.item,
    required this.lane,
    required this.width,
    required this.startMs,
  });

  final DanmakuItem item;
  final int lane;
  final double width;
  final int startMs;

  /// 完全离开屏幕的时间（毫秒，弹幕时间轴）。
  int get endMs => startMs + _DanmakuOverlayState.travelMs;
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  static const int travelMs = 8000;

  late final Ticker _ticker;
  final List<_DanmakuLine> _lines = [];
  final Map<String, TextPainter> _measureCache = {};

  /// 已经调度到第几条。
  int _cursor = 0;

  /// 上一次对齐的播放位置（用于 seek 检测）。
  Duration _lastPosition = Duration.zero;
  DateTime _lastSyncAt = DateTime.now();
  double _interpMs = 0;
  int _laneCount = 12;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // seek：位置跳变超过 3 秒（或往回），整体重建
    final delta = widget.position.inMilliseconds - _lastPosition.inMilliseconds;
    if (delta.abs() > 3000 || delta < -500) {
      _reset(widget.position);
    }
    if (widget.position.inMilliseconds !=
        _lastPosition.inMilliseconds) {
      _lastPosition = widget.position;
      _lastSyncAt = DateTime.now();
    }
    if (oldWidget.items != widget.items) {
      _reset(widget.position);
    }
  }

  void _reset(Duration position) {
    _lines.clear();
    _measureCache.clear();
    _cursor = 0;
    _lastPosition = position;
    _lastSyncAt = DateTime.now();
    _interpMs = position.inMilliseconds.toDouble();
    // 把游标推到当前位置之前
    while (_cursor < widget.items.length &&
        widget.items[_cursor].timeMs < _interpMs) {
      _cursor++;
    }
  }

  void _onTick(Duration _) {
    if (!widget.enabled || widget.items.isEmpty) return;
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastSyncAt).inMilliseconds;
    _interpMs = _lastPosition.inMilliseconds +
        (widget.playing ? elapsedMs * widget.playbackRate : 0);

    _schedule();
    _prune();

    if (mounted) setState(() {});
  }

  void _schedule() {
    final untilMs = _interpMs;
    while (_cursor < widget.items.length) {
      final item = widget.items[_cursor];
      if (item.timeMs > untilMs) break;
      if (widget.blockedPattern?.hasMatch(item.text) ?? false) {
        _cursor++;
        continue;
      }
      if (_lines.length >= widget.maxOnScreen) {
        _cursor++;
        continue;
      }
      final lane = _findLane(item.timeMs);
      if (lane == null) {
        _cursor++;
        continue;
      }
      final painter = _measure(item.text);
      _lines.add(_DanmakuLine(
        item: item,
        lane: lane,
        width: painter.width,
        startMs: item.timeMs,
      ));
      _cursor++;
    }
  }

  int? _findLane(int startMs) {
    for (var lane = 0; lane < _laneCount; lane++) {
      var occupied = false;
      for (final line in _lines) {
        if (line.lane != lane) continue;
        if (line.endMs > startMs) {
          occupied = true;
          break;
        }
      }
      if (!occupied) return lane;
    }
    return null;
  }

  void _prune() {
    _lines.removeWhere((line) => line.endMs <= _interpMs);
  }

  TextPainter _measure(String text) {
    final cached = _measureCache[text];
    if (cached != null) return cached;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    if (_measureCache.length > 400) _measureCache.clear();
    _measureCache[text] = painter;
    return painter;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        _laneCount = math.max(
          1,
          ((constraints.maxHeight * 0.8) / (widget.fontSize + 14)).floor(),
        );
        return IgnorePointer(
          child: CustomPaint(
            painter: _DanmakuPainter(
              lines: _lines,
              nowMs: _interpMs,
              width: constraints.maxWidth,
              fontSize: widget.fontSize,
              opacity: widget.opacity,
              measure: _measure,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _DanmakuPainter extends CustomPainter {
  _DanmakuPainter({
    required this.lines,
    required this.nowMs,
    required this.width,
    required this.fontSize,
    required this.opacity,
    required this.measure,
  });

  final List<_DanmakuLine> lines;
  final double nowMs;
  final double width;
  final double fontSize;
  final double opacity;
  final TextPainter Function(String) measure;

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;
    final laneHeight = fontSize + 14;
    final topPadding = size.height * 0.06;

    for (final line in lines) {
      final progress = (nowMs - line.startMs) / _DanmakuOverlayState.travelMs;
      if (progress < 0 || progress > 1) continue;

      final painter = measure(line.item.text);
      final color = Color(0xFF000000 | line.item.color)
          .withValues(alpha: opacity);

      switch (line.item.mode) {
        case DanmakuMode.scroll:
          final x = width - (width + line.width) * progress;
          final y = topPadding + line.lane * laneHeight;
          _drawWithShadow(canvas, painter, color, Offset(x, y));
          break;
        case DanmakuMode.top:
          final x = (width - line.width) / 2;
          _drawWithShadow(canvas, painter, color, Offset(x, topPadding));
          break;
        case DanmakuMode.bottom:
          final x = (width - line.width) / 2;
          final y = size.height - (fontSize + 12) - topPadding;
          _drawWithShadow(canvas, painter, color, Offset(x, y));
          break;
      }
    }
  }

  void _drawWithShadow(
    Canvas canvas,
    TextPainter painter,
    Color color,
    Offset offset,
  ) {
    final shadow = TextPainter(
      text: TextSpan(
        text: painter.text?.toPlainText() ?? '',
        style: painter.text?.style?.copyWith(
          color: Colors.black.withValues(alpha: opacity * 0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    shadow.paint(canvas, offset + const Offset(1.2, 1.2));
    final real = TextPainter(
      text: TextSpan(
        text: painter.text?.toPlainText() ?? '',
        style: painter.text?.style?.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    real.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_DanmakuPainter oldDelegate) => true;
}
