import 'dart:async';

import 'package:flutter/services.dart';

/// 方向键 → 的长按/短按手势。
///
/// - 短按（< threshold）：跳 5 秒；
/// - 长按（≥ threshold）：进入 2 倍速，松开还原。
///
/// 单独抽出来是为了能单测：播放器本体的依赖（libmpv）在测试环境跑不起来。
class ArrowKeyHoldGesture {
  ArrowKeyHoldGesture({
    required this.onShortPress,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    this.threshold = const Duration(milliseconds: 350),
  });

  final void Function() onShortPress;
  final void Function() onLongPressStart;
  final void Function() onLongPressEnd;
  final Duration threshold;

  bool _held = false;
  bool _longActive = false;
  Timer? _timer;

  /// 返回 true 表示这个事件已被处理。
  bool handle(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.arrowRight) return false;

    if (event is KeyDownEvent) {
      if (_held) return true; // 系统自动重复
      _held = true;
      _longActive = false;
      _timer?.cancel();
      _timer = Timer(threshold, () {
        if (!_held || _longActive) return;
        _longActive = true;
        onLongPressStart();
      });
      return true;
    }

    if (event is KeyUpEvent) {
      _held = false;
      _timer?.cancel();
      if (_longActive) {
        _longActive = false;
        onLongPressEnd();
      } else {
        onShortPress();
      }
      return true;
    }

    return true;
  }

  void dispose() {
    _timer?.cancel();
  }
}
