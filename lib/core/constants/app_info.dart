/// 应用元信息：名称、版本、仓库地址。
///
/// 单一来源，避免各处硬编码字符串。版本升级时只改这里（后续接入
/// `package_info_plus` 后改为运行时读取）。
class AppInfo {
  AppInfo._();

  static const String name = 'anime_client';
  static const String displayName = 'Anime Client';
  static const String version = '0.1.0';
  static const String description = '追番客户端（个人自用）';
  static const String repository = 'https://github.com/xiangfengzhinai666/anime-client';
  static const String stage = 'S1';
}
