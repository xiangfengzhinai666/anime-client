import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/daos.dart';

/// 应用级 Provider 汇总。
///
/// 约定：
/// - 只有一个「数据源」入口（数据库 / 日志），其余 DAO 都从这里派生；
/// - 数据库实例在 main() 打开，通过 override 注入，便于测试替换成内存库。

final appLoggerProvider = Provider<AppLogger>((ref) => appLogger);

/// 必须在 `ProviderScope(overrides: ...)` 中注入，否则使用时报错。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider 需要在 main() 中 override');
});

final historyDaoProvider = Provider<HistoryDao>(
  (ref) => HistoryDao(ref.watch(appDatabaseProvider)),
);

final favoritesDaoProvider = Provider<FavoritesDao>(
  (ref) => FavoritesDao(ref.watch(appDatabaseProvider)),
);

final settingsDaoProvider = Provider<SettingsDao>(
  (ref) => SettingsDao(ref.watch(appDatabaseProvider)),
);

/// 最近观看（首页/我的页用）。
final recentHistoryProvider = StreamProvider<List<HistoryEntry>>(
  (ref) => ref.watch(historyDaoProvider).watchRecent(limit: 20),
);

/// 全部追番。
final favoritesProvider = StreamProvider<List<FavoriteEntry>>(
  (ref) => ref.watch(favoritesDaoProvider).watchAll(),
);

/// 主题模式控制器：读写在 settings 表，重启后保持。
class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController(this._settings, this._logger) : super(ThemeMode.dark) {
    _restore();
  }

  static const String storageKey = 'theme_mode';

  final SettingsDao _settings;
  final AppLogger _logger;

  Future<void> _restore() async {
    try {
      final saved = await _settings.get(storageKey);
      if (!mounted || saved == null) return;
      state = _parse(saved);
    } catch (e, st) {
      _logger.error('theme', '读取主题设置失败', e, st);
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      await _settings.set(storageKey, mode.name);
      _logger.info('theme', '主题切换为 ${mode.name}');
    } catch (e, st) {
      _logger.error('theme', '保存主题设置失败', e, st);
    }
  }

  static ThemeMode _parse(String value) {
    return ThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ThemeMode.dark,
    );
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  return ThemeController(
    ref.watch(settingsDaoProvider),
    ref.watch(appLoggerProvider),
  );
});

/// 某番的追番状态（null = 未追）。
final favoriteStatusProvider =
    Provider.family<FavoriteCategory?, int>((ref, bangumiId) {
  final items = ref.watch(favoritesProvider).valueOrNull ?? const [];
  for (final item in items) {
    if (item.bangumiId == bangumiId) {
      return FavoriteCategory.fromKey(item.category);
    }
  }
  return null;
});
