import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app/providers/app_providers.dart';
import 'app/routing/app_router.dart';
import 'app/theme/app_theme.dart';
import 'core/constants/app_info.dart';
import 'core/error/error_handling.dart';
import 'core/logging/app_logger.dart';
import 'core/storage/app_database.dart';
import 'core/utils/app_paths.dart';
import 'dev/screenshot.dart';

/// 启动顺序（不要随意调换）：
/// 1. 绑定 → 2. 安装全局错误兜底 → 3. 日志落盘 → 4. 打开数据库
/// → 5. runApp（注入数据库）→ 6. 开发期截图钩子
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      MediaKit.ensureInitialized();
      await windowManager.ensureInitialized();
      installGlobalErrorHandlers(appLogger);
      await appLogger.initFileSink();

      appLogger.info(
        'boot',
        '${AppInfo.displayName} ${AppInfo.version} 启动（${AppInfo.stage}）',
      );

      final database = await _openDatabase();

      runApp(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const AnimeClientApp(),
        ),
      );

      scheduleScreenshot();
    },
    (error, stack) {
      // Zone 兜底：runApp 之外的异步异常
      appLogger.error('zone', '未捕获的异步异常', error, stack);
    },
  );
}

Future<AppDatabase> _openDatabase() async {
  try {
    final file = await AppPaths.databaseFile();
    final db = AppDatabase.openFile(file);
    appLogger.info('db', '数据库就绪：${file.path}');
    return db;
  } catch (e, st) {
    // 打不开磁盘库时降级到内存库，保证应用仍可用（数据不持久）
    appLogger.error('db', '数据库打开失败，降级为内存库', e, st);
    return AppDatabase.memory();
  }
}

/// 应用根组件：主题 + 路由。
class AnimeClientApp extends ConsumerWidget {
  const AnimeClientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppInfo.displayName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // 截图边界放在最外层，任何路由（包括详情页/设置页）都能被抓到
        return RepaintBoundary(
          key: appShotKey,
          child: MediaQuery(
            // 桌面端固定 1.0 缩放，避免系统字体放大把布局撑坏
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
