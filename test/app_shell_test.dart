import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('宽屏启动：显示侧栏与首页，无底部导航', (tester) async {
    final db = newMemoryDatabase();
    addTearDown(db.close);
    useDesktopSize(tester);

    await bootApp(tester, db);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('开始追番'), findsOneWidget);
    expect(find.text('继续观看'), findsOneWidget);

    await shutdownApp(tester);
  });

  testWidgets('窄屏启动：显示底部导航栏', (tester) async {
    final db = newMemoryDatabase();
    addTearDown(db.close);
    useMobileSize(tester);

    await bootApp(tester, db);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await shutdownApp(tester);
  });

  testWidgets('点击侧栏「索引」切换到索引页', (tester) async {
    final db = newMemoryDatabase();
    addTearDown(db.close);
    useDesktopSize(tester);

    await bootApp(tester, db);

    await tester.tap(find.text('索引').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('按排序、连载状态浏览（年份筛选接口不支持，已移除）'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsWidgets);

    await shutdownApp(tester);
  });

  testWidgets('点击侧栏「追番」显示三种分类页签', (tester) async {
    final db = newMemoryDatabase();
    addTearDown(db.close);
    useDesktopSize(tester);

    await bootApp(tester, db);

    await tester.tap(find.text('追番').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('想看'), findsWidgets);
    expect(find.text('在看'), findsWidgets);
    expect(find.text('看过'), findsWidgets);

    await shutdownApp(tester);
  });

  testWidgets('切换主题为浅色：立即生效并写入设置表', (tester) async {
    final db = newMemoryDatabase();
    addTearDown(db.close);
    useDesktopSize(tester);

    await bootApp(tester, db);

    await tester.tap(find.byTooltip('设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('外观'), findsOneWidget);

    await tester.tap(find.text('浅色'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);

    // 落库校验：真实异步写，放到 runAsync 里等
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final row = await db.select(db.settingEntries).getSingleOrNull();
      expect(row?.key, 'theme_mode');
      expect(row?.value, 'light');
    });

    await shutdownApp(tester);
  });
}
