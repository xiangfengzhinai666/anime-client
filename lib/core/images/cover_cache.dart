import 'dart:io';

/// 图片缓存接口。
///
/// 抽出接口的目的：UI 只依赖 `get(url)`，测试里可以注入"永不联网"的实现。
abstract class CoverCache {
  Future<File?> get(String url);
  Future<int> sizeBytes();
  Future<void> clear();
}
