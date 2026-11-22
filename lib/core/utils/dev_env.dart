import 'dart:io';

/// 开发期环境开关（仅从进程环境变量读取，生产无副作用）。
///
/// 用途：让自动化流程能驱动应用截图、指定起始页。
class DevEnv {
  DevEnv._();

  static const String shotKey = 'DSH_SHOT';
  static const String shotTabKey = 'DSH_SHOT_TAB';
  static const String shotDelayKey = 'DSH_SHOT_DELAY_MS';

  static Map<String, String> get _env =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux
          ? Platform.environment
          : const {};

  /// 截图输出路径；为空表示正常启动。
  static String? get shotPath {
    final v = _env[shotKey];
    return (v == null || v.isEmpty) ? null : v;
  }

  static bool get isScreenshotMode => shotPath != null;

  /// 起始标签页下标（截图时用来逐页取图）。
  static int get initialTabIndex {
    final v = int.tryParse(_env[shotTabKey] ?? '');
    return (v ?? 0).clamp(0, 8);
  }

  static Duration get shotDelay {
    final v = int.tryParse(_env[shotDelayKey] ?? '');
    return Duration(milliseconds: (v ?? 900).clamp(100, 10000));
  }
}
