import 'package:anime_client/app/providers/app_providers.dart';
import 'package:anime_client/core/storage/app_database.dart';
import 'package:anime_client/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 内存数据库（drift / sqlite3 的 native 绑定由包自身提供）。
AppDatabase newMemoryDatabase() => AppDatabase.memory();

/// 把应用挂到内存数据库上。
Widget buildTestApp(AppDatabase db) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: const AnimeClientApp(),
  );
}

/// 桌面尺寸（走侧栏布局）。
void useDesktopSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 窄屏尺寸（走底部导航）。
void useMobileSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 860);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 启动应用并等待首帧稳定（不用 pumpAndSettle，避免无限动画卡住）。
Future<void> bootApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(buildTestApp(db));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// 卸载组件树，让 drift 的流查询释放定时器（否则测试结束会报 timersPending）。
Future<void> shutdownApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}
