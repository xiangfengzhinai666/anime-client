import 'package:anime_client/core/logging/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('日志：写入后进入环形缓冲，超过上限丢弃最旧的', () {
    final logger = AppLogger(maxBuffered: 3);

    logger.info('test', 'a');
    logger.warn('test', 'b');
    logger.error('test', 'c');
    logger.debug('test', 'd');

    expect(logger.buffer.length, 3);
    expect(logger.buffer.first.message, 'b', reason: '最旧的 a 被挤出');
    expect(logger.buffer.last.message, 'd');
  });

  test('日志：minLevel 过滤掉低级别', () {
    final logger = AppLogger(minLevel: LogLevel.warn);

    logger.debug('test', 'debug 不该出现');
    logger.info('test', 'info 不该出现');
    logger.warn('test', 'warn 要出现');
    logger.error('test', 'error 要出现');

    expect(logger.buffer.length, 2);
    expect(logger.buffer.map((e) => e.level),
        [LogLevel.warn, LogLevel.error]);
  });

  test('日志：格式化包含时间、级别、标签', () {
    final logger = AppLogger();
    logger.info('boot', '启动完成');
    final line = logger.buffer.single.format();

    expect(line.contains('INFO'), isTrue);
    expect(line.contains('[boot]'), isTrue);
    expect(line.contains('启动完成'), isTrue);
  });
}
