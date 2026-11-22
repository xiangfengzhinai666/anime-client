import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../utils/app_paths.dart';

enum LogLevel {
  debug('DEBUG'),
  info('INFO'),
  warn('WARN'),
  error('ERROR');

  const LogLevel(this.label);
  final String label;
}

/// 一条日志记录。
@immutable
class LogRecord {
  const LogRecord({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
  });

  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  String format() {
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(time);
    return '$ts ${level.label.padRight(5)} [$tag] $message';
  }

  @override
  String toString() => format();
}

/// 轻量日志器：内存环形缓冲 + 控制台 + 按天切分的文件。
///
/// 设计取舍：
/// - 不引入第三方日志包，保持依赖最小；
/// - 文件写入失败（权限/磁盘）只降级，绝不影响业务；
/// - 内存缓冲供后续「诊断」页面展示。
class AppLogger {
  AppLogger({this.minLevel = LogLevel.debug, this.maxBuffered = 500});

  final LogLevel minLevel;
  final int maxBuffered;

  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  static final DateFormat _timeFmt = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  final List<LogRecord> _buffer = <LogRecord>[];
  final StreamController<LogRecord> _controller =
      StreamController<LogRecord>.broadcast();

  Directory? _logDir;
  IOSink? _sink;
  String? _sinkDate;
  bool _fileEnabled = false;

  List<LogRecord> get buffer => List.unmodifiable(_buffer);
  Stream<LogRecord> get stream => _controller.stream;
  bool get fileEnabled => _fileEnabled;

  /// 初始化文件落盘。任何异常都只降级，不向外抛。
  Future<void> initFileSink({int keepDays = 5}) async {
    try {
      final dir = await AppPaths.logsDir();
      _logDir = dir;
      _rotateOldFiles(dir, keepDays);
      _openSinkForToday();
      _fileEnabled = true;
    } catch (e) {
      _fileEnabled = false;
      debugPrint('[logger] 文件日志不可用：$e');
    }
  }

  void _rotateOldFiles(Directory dir, int keepDays) {
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith('app_') || !name.endsWith('.log')) continue;
      if (entity.statSync().modified.isBefore(cutoff)) {
        try {
          entity.deleteSync();
        } catch (_) {
          // 删不掉就算了
        }
      }
    }
  }

  void _openSinkForToday() {
    final dir = _logDir;
    if (dir == null) return;
    final today = _dateFmt.format(DateTime.now());
    if (_sink != null && _sinkDate == today) return;
    try {
      _sink?.close();
    } catch (_) {}
    _sink = File(p.join(dir.path, 'app_$today.log'))
        .openWrite(mode: FileMode.append);
    _sinkDate = today;
  }

  void log(LogLevel level, String tag, String message) {
    if (level.index < minLevel.index) return;

    final record = LogRecord(
      time: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );

    _buffer.add(record);
    if (_buffer.length > maxBuffered) {
      _buffer.removeRange(0, _buffer.length - maxBuffered);
    }
    if (!_controller.isClosed) _controller.add(record);

    debugPrint('${_timeFmt.format(record.time)} ${record.level.label.padRight(5)} [$tag] $message');

    if (_fileEnabled) {
      _openSinkForToday();
      try {
        _sink?.writeln(record.format());
      } catch (_) {
        // 写失败不影响业务
      }
    }
  }

  void debug(String tag, String message) => log(LogLevel.debug, tag, message);
  void info(String tag, String message) => log(LogLevel.info, tag, message);
  void warn(String tag, String message) => log(LogLevel.warn, tag, message);
  void error(String tag, String message, [Object? error, StackTrace? stack]) {
    final buffer = StringBuffer(message);
    if (error != null) buffer.write(' | $error');
    if (stack != null) buffer.write('\n$stack');
    log(LogLevel.error, tag, buffer.toString());
  }

  Future<void> dispose() async {
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    await _controller.close();
  }
}

/// 全局默认实例：main() 里初始化文件落盘；测试里可直接用（不落盘）。
final AppLogger appLogger = AppLogger();
