import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('首页展示真实卡片（假数据源）', (tester) async {
    final db = newMemoryDatabase();
    addTearDown(db.close);
    useDesktopSize(tester);

    await bootApp(tester, db);

    expect(find.text('葬送的芙莉莲'), findsWidgets);
    expect(find.text('正在连载'), findsOneWidget);
    expect(find.text('高分推荐'), findsOneWidget);

    await shutdownApp(tester);
  });

  testWidgets('点卡片进入详情页：显示简介与分集', (tester) async {
    final db = newMemoryDatabase();
    addTearDown(db.close);
    useDesktopSize(tester);

    await bootApp(tester, db);

    await tester.tap(find.text('葬送的芙莉莲').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('简介'), findsOneWidget);
    expect(find.textContaining('寿命逾千年'), findsOneWidget);
    expect(find.text('剧集'), findsOneWidget);
    expect(find.text('从第 1 集开始'), findsOneWidget);

    // 分集按钮存在（第 1/2 集）
    expect(find.widgetWithText(OutlinedButton, '1'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, '2'), findsWidgets);

    await shutdownApp(tester);
  });

  testWidgets('搜索：输入关键词后展示结果并标注来源', (tester) async {
    final db = newMemoryDatabase();
    addTearDown(db.close);
    useDesktopSize(tester);

    await bootApp(tester, db);

    await tester.tap(find.text('搜索').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField), '芙莉莲');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('的结果'), findsOneWidget);
    // 假数据里两条结果都带来源角标
    expect(find.text('B站'), findsWidgets);

    await shutdownApp(tester);
  });

  testWidgets('索引：默认加载一页并显示到底提示', (tester) async {
    final db = newMemoryDatabase();
    addTearDown(db.close);
    useDesktopSize(tester);

    await bootApp(tester, db);

    await tester.tap(find.text('索引').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('番剧列表'), findsOneWidget);
    expect(find.textContaining('已经到底了'), findsOneWidget);

    await shutdownApp(tester);
  });

  testWidgets('数据源报错时显示错误态和重试按钮', (tester) async {
    final db = newMemoryDatabase();
    addTearDown(db.close);
    useDesktopSize(tester);

    await tester.pumpWidget(buildTestApp(
      db,
      repository: FakeCatalogRepository(error: Exception('模拟断网')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('数据加载失败'), findsWidgets);
    expect(find.text('重试'), findsWidgets);

    await shutdownApp(tester);
  });
}
