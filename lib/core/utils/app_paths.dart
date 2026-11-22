import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 应用数据目录的唯一入口。
///
/// 统一在这里兜底：插件不可用（例如单元测试）时退回到临时目录，
/// 避免上层到处写 try/catch。
class AppPaths {
  AppPaths._();

  static Directory? _supportCache;

  static Future<Directory> supportDir() async {
    final cached = _supportCache;
    if (cached != null) return cached;

    Directory dir;
    try {
      dir = await getApplicationSupportDirectory();
    } catch (_) {
      dir = Directory(p.join(Directory.systemTemp.path, 'anime_client'));
    }
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _supportCache = dir;
    return dir;
  }

  static Future<Directory> logsDir() async {
    final base = await supportDir();
    final dir = Directory(p.join(base.path, 'logs'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// SQLite 数据库文件（drift 使用）。
  static Future<File> databaseFile() async {
    final base = await supportDir();
    return File(p.join(base.path, 'anime_client.sqlite'));
  }
}
