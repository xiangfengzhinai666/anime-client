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
