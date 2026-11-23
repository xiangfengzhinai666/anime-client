import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/danmaku_models.dart';

/// 弹幕渲染层（自绘）。
///
/// 设计要点：
/// - 位置由外部 `position` 驱动，内部用 Ticker 插值，暂停/倍速都平滑；
/// - 滚动弹幕、顶部弹幕、底部弹幕**各自独立分配轨道**，互不重叠；
/// - 滚动时长 = 基准 / (滚动速度 × 播放倍速)，所以"跟随倍速"时弹幕也会更快；
/// - seek（位置大幅跳变）整体重建，避免残留。
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
    this.showScroll = true,
    this.showTop = true,
    this.showBottom = true,
    this.areaRatio = 1.0,
    this.density = 1.0,
    this.topMargin = 0,
    this.bottomMargin = 0,
    this.outlineWidth = 1.2,
  });

  final List<DanmakuItem> items;
  final Duration position;
  final bool playing;
  final double playbackRate;
  final double opacity;
  final double fontSize;

  /// 滚动速度倍率（越大越快）。
  final double speedFactor;
  final int maxOnScreen;
  final RegExp? blockedPattern;
  final bool enabled;
  final bool showScroll;
  final bool showTop;
  final bool showBottom;

  /// 弹幕区域占屏幕高度比例。
  final double areaRatio;
  final double density;
  final double topMargin;
  final double bottomMargin;
  final double outlineWidth;

  bool allows(DanmakuMode mode) {
    switch (mode) {
      case DanmakuMode.scroll:
        return showScroll;
      case DanmakuMode.top:
        return showTop;
      case DanmakuMode.bottom:
        return showBottom;
    }
  }

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuLine {
  _DanmakuLine({
    required this.item,
    required this.lane,
    required this.width,
    required this.startMs,
    required this.travelMs,
  });

  final DanmakuItem item;
  final int lane;
  final double width;
  final int startMs;
  final int travelMs;

  int get endMs => startMs + travelMs;
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  static const int baseTravelMs = 8000;

  late final Ticker _ticker;
  final List<_DanmakuLine> _lines = [];
  final Map<String, TextPainter> _measureCache = {};

  /// 带颜色/描边的最终 TextPainter 缓存。每帧重排文字是主要 CPU 开销。
  final Map<String, _PaintedText> _paintCache = {};

  int _cursor = 0;
  Duration _lastPosition = Duration.zero;
  DateTime _lastSyncAt = DateTime.now();
  double _interpMs = 0;
  int _laneCount = 12;

  /// 只让 CustomPaint 重绘，不重建整棵子树。
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  int _lastRepaintMs = 0;
  int _tickCount = 0;

  /// 当前滚动时长（受滚动速度与播放倍速影响）。
  int get _travelMs {
    final factor =
        math.max(0.1, widget.speedFactor * math.max(0.25, widget.playbackRate));
    return (baseTravelMs / factor).round().clamp(1200, 40000);
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final delta = widget.position.inMilliseconds - _lastPosition.inMilliseconds;
    if (delta.abs() > 3000 || delta < -500) {
      _reset(widget.position);
    }
    if (widget.position.inMilliseconds != _lastPosition.inMilliseconds) {
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
    _paintCache.clear();
    _cursor = 0;
    _lastPosition = position;
    _lastSyncAt = DateTime.now();
    _interpMs = position.inMilliseconds.toDouble();
    while (_cursor < widget.items.length &&
        widget.items[_cursor].timeMs < _interpMs) {
      _cursor++;
    }
  }

  void _onTick(Duration elapsed) {
    if (!widget.enabled || widget.items.isEmpty) return;
    final elapsedMs = DateTime.now().difference(_lastSyncAt).inMilliseconds;
    _interpMs = _lastPosition.inMilliseconds +
        (widget.playing ? elapsedMs * widget.playbackRate : 0);

    _schedule();
    _prune();

    // 30fps 重绘即可，弹幕移动肉眼看不出 60fps 差异
    final nowMs = elapsed.inMilliseconds;
    if (nowMs - _lastRepaintMs < 33) return;
    _lastRepaintMs = nowMs;
    _tickCount++;
    if (mounted) _repaint.value = _tickCount;
  }

  int get _effectiveLimit =>
      (widget.maxOnScreen * widget.density).clamp(10, widget.maxOnScreen).round();

  void _schedule() {
    while (_cursor < widget.items.length) {
      final item = widget.items[_cursor];
      if (item.timeMs > _interpMs) break;
      _cursor++;

      if (widget.blockedPattern?.hasMatch(item.text) ?? false) continue;
      if (!widget.allows(item.mode)) continue;
      if (_lines.length >= _effectiveLimit) continue;

      final lane = _findLane(item.timeMs, item.mode);
      if (lane == null) continue;

      final painter = _measure(item.text);
      _lines.add(_DanmakuLine(
        item: item,
        lane: lane,
        width: painter.width,
        startMs: item.timeMs,
        travelMs: _travelMs,
      ));
    }
  }

  int? _findLane(int startMs, DanmakuMode mode) {
    for (var lane = 0; lane < _laneCount; lane++) {
      var occupied = false;
      for (final line in _lines) {
        if (line.item.mode != mode || line.lane != lane) continue;
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

  _PaintedText _paint(DanmakuItem item) {
    final key = '${item.text}|${item.color}|${widget.opacity}|${widget.outlineWidth}';
    final cached = _paintCache[key];
    if (cached != null) return cached;

    final base = _measure(item.text);
    final style = base.text?.style;
    final text = base.text?.toPlainText() ?? '';
    final color = Color(0xFF000000 | item.color)
        .withValues(alpha: widget.opacity);
    final main = TextPainter(
      text: TextSpan(text: text, style: style?.copyWith(color: color)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    TextPainter? outline;
    if (widget.outlineWidth > 0) {
      outline = TextPainter(
        text: TextSpan(
          text: text,
          style: style?.copyWith(
            color: Colors.black.withValues(alpha: widget.opacity * 0.9),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    }
    final painted = _PaintedText(main: main, outline: outline);
    if (_paintCache.length > 800) _paintCache.clear();
    _paintCache[key] = painted;
    return painted;
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
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final usable = constraints.maxHeight * widget.areaRatio -
            widget.topMargin -
            widget.bottomMargin;
        _laneCount = math.max(1, (usable / (widget.fontSize + 14)).floor());
        return IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _DanmakuPainter(
                repaint: _repaint,
                lines: _lines,
              nowMs: _interpMs,
              width: constraints.maxWidth,
              fontSize: widget.fontSize,
              opacity: widget.opacity,
              measure: _measure,
              paintedText: _paint,
                topMargin: widget.topMargin,
                bottomMargin: widget.bottomMargin,
                outlineWidth: widget.outlineWidth,
              ),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }
}

class _DanmakuPainter extends CustomPainter {
  _DanmakuPainter({
    required Listenable repaint,
    required this.lines,
    required this.nowMs,
    required this.width,
    required this.fontSize,
    required this.opacity,
    required this.measure,
    required this.paintedText,
    required this.topMargin,
    required this.bottomMargin,
    required this.outlineWidth,
  }) : super(repaint: repaint);

  final List<_DanmakuLine> lines;
  final double nowMs;
  final double width;
  final double fontSize;
  final double opacity;
  final TextPainter Function(String) measure;
  final _PaintedText Function(DanmakuItem) paintedText;
  final double topMargin;
  final double bottomMargin;
  final double outlineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;
    final laneHeight = fontSize + 14;
    final topPadding = topMargin + 8;

    for (final line in lines) {
      final progress =
          (nowMs - line.startMs) / line.travelMs;
      if (progress < 0 || progress > 1) continue;

      final painted = paintedText(line.item);

      switch (line.item.mode) {
        case DanmakuMode.scroll:
          final x = width - (width + line.width) * progress;
          final y = topPadding + line.lane * laneHeight;
          _draw(canvas, painted, Offset(x, y));
          break;
        case DanmakuMode.top:
          final x = (width - line.width) / 2;
          final y = topPadding + line.lane * laneHeight;
          _draw(canvas, painted, Offset(x, y));
          break;
        case DanmakuMode.bottom:
          final x = (width - line.width) / 2;
          final y = size.height -
              bottomMargin -
              topPadding -
              (line.lane + 1) * laneHeight;
          _draw(canvas, painted, Offset(x, y));
          break;
      }
    }
  }

  void _draw(Canvas canvas, _PaintedText painted, Offset offset) {
    if (painted.outline != null) {
      painted.outline!.paint(canvas, offset + Offset(outlineWidth, outlineWidth));
    }
    painted.main.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_DanmakuPainter oldDelegate) => false;
}

class _PaintedText {
  _PaintedText({required this.main, this.outline});

  final TextPainter main;
  final TextPainter? outline;
}
