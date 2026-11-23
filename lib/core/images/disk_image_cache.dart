import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../logging/app_logger.dart';
import '../network/api_client.dart';
import '../utils/app_paths.dart';
import 'cover_cache.dart';

/// 封面图磁盘缓存（LRU，按总大小淘汰）。
///
/// 为什么不引第三方包：
/// - 只需要"下载到本地 + 复用 + 限大小"，逻辑很少；
/// - 自己持有 ApiClient，能统一超时/日志/代理行为；
/// - 方便测试（可直接指定缓存目录）。
class DiskImageCache implements CoverCache {
  DiskImageCache({
    required this.client,
    required this.logger,
    this.maxBytes = 200 * 1024 * 1024,
    this.maxAge = const Duration(days: 30),
  });

  final ApiClient client;
  final AppLogger logger;
  final int maxBytes;
  final Duration maxAge;

  final Map<String, Future<File?>> _inflight = {};
  Directory? _dir;
  int _knownBytes = 0;
  int _downloadsSincePrune = 0;

  Future<Directory> _ensureDir() async {
    final cached = _dir;
    if (cached != null) return cached;

    final base = await AppPaths.cacheDir();
    final dir = Directory(p.join(base.path, 'covers'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dir = dir;
    await _refreshSize();
    await _pruneIfNeeded(force: true);
    return dir;
  }

  /// 命中返回本地文件；未命中则下载（并发去重）。
  @override
  Future<File?> get(String url) async {
    if (url.isEmpty) return null;
    final dir = await _ensureDir();
    final file = File(p.join(dir.path, _keyFor(url)));

    if (file.existsSync()) {
      // 触摸一下 mtime，让 LRU 把它当成"最近用过"
      try {
        file.setLastModifiedSync(DateTime.now());
      } catch (_) {}
      return file;
    }

    final running = _inflight[url];
    if (running != null) return running;

    final future = _download(url, file);
    _inflight[url] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(url);
    }
  }

  Future<File?> _download(String url, File file) async {
    try {
      final bytes = await client.getBytes(url);
      if (bytes.isEmpty) return null;
      await file.writeAsBytes(bytes, flush: true);
      _knownBytes += bytes.length;
      _downloadsSincePrune++;
      if (_downloadsSincePrune >= 20) {
        _downloadsSincePrune = 0;
        await _pruneIfNeeded();
      }
      return file;
    } catch (e) {
      logger.warn('image', '封面下载失败：$e');
      return null;
    }
  }

  String _keyFor(String url) => sha1.convert(utf8.encode(url)).toString();

  Future<void> _refreshSize() async {
    final dir = _dir;
    if (dir == null) return;
    var total = 0;
    for (final entity in dir.listSync()) {
      if (entity is File) total += entity.lengthSync();
    }
    _knownBytes = total;
  }

  Future<void> _pruneIfNeeded({bool force = false}) async {
    final dir = _dir;
    if (dir == null) return;
    if (!force && _knownBytes <= maxBytes) return;

    final files = dir
        .listSync()
        .whereType<File>()
        .map((f) => (file: f, stat: f.statSync()))
        .toList()
      ..sort((a, b) => a.stat.modified.compareTo(b.stat.modified));

    final cutoff = DateTime.now().subtract(maxAge);
    var total = _knownBytes;
    final target = (maxBytes * 0.8).round();

    for (final entry in files) {
      final expired = entry.stat.modified.isBefore(cutoff);
      if (!expired && total <= target) break;
      try {
        final size = entry.stat.size;
        entry.file.deleteSync();
        total -= size;
      } catch (_) {}
    }
    _knownBytes = total < 0 ? 0 : total;
  }

  /// 供设置页展示。
  @override
  Future<int> sizeBytes() async {
    await _ensureDir();
    await _refreshSize();
    return _knownBytes;
  }

  /// 清空缓存。
  @override
  Future<void> clear() async {
    final dir = _dir;
    if (dir == null) return;
    for (final entity in dir.listSync()) {
      try {
        entity.deleteSync(recursive: true);
      } catch (_) {}
    }
    _knownBytes = 0;
  }
}
