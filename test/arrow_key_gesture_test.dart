import 'package:anime_client/features/play/arrow_key_gesture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

KeyDownEvent _down() => const KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.arrowRight,
      logicalKey: LogicalKeyboardKey.arrowRight,
      timeStamp: Duration.zero,
    );

KeyUpEvent _up() => const KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.arrowRight,
      logicalKey: LogicalKeyboardKey.arrowRight,
      timeStamp: Duration.zero,
    );

void main() {
  late int shortPress;
  late int longStart;
  late int longEnd;
  late ArrowKeyHoldGesture gesture;

  setUp(() {
    shortPress = 0;
    longStart = 0;
    longEnd = 0;
    gesture = ArrowKeyHoldGesture(
      threshold: const Duration(milliseconds: 120),
      onShortPress: () => shortPress++,
      onLongPressStart: () => longStart++,
      onLongPressEnd: () => longEnd++,
    );
  });

  tearDown(() => gesture.dispose());

  test('短按 → 只触发一次跳转', () async {
    gesture.handle(_down());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    gesture.handle(_up());

    expect(shortPress, 1);
    expect(longStart, 0);
    expect(longEnd, 0);
  });

  test('长按 → 进入倍速，松开时还原，不触发跳转', () async {
    gesture.handle(_down());
    await Future<void>.delayed(const Duration(milliseconds: 220));
    expect(longStart, 1);

    gesture.handle(_up());
    expect(longEnd, 1);
    expect(shortPress, 0);
  });

  test('按住期间的自动重复事件不会重复触发', () async {
    gesture.handle(_down());
    for (var i = 0; i < 5; i++) {
      gesture.handle(_down());
    }
    await Future<void>.delayed(const Duration(milliseconds: 220));
    expect(longStart, 1);
    gesture.handle(_up());
    expect(longEnd, 1);
  });

  test('其它按键不受影响', () {
    final handled = gesture.handle(const KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.space,
      logicalKey: LogicalKeyboardKey.space,
      timeStamp: Duration.zero,
    ));
    expect(handled, isFalse);
    expect(shortPress, 0);
  });
}
