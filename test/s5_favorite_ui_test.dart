import 'package:anime_client/core/storage/daos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('详情页追番：加入后能取消（回归：null 值不触发菜单）', (tester) async {
    final db = newMemoryDatabase();
    addTearDown(db.close);
    useDesktopSize(tester);

    await bootApp(tester, db);

    // 进详情页
    await tester.tap(find.text('葬送的芙莉莲').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 打开追番菜单 -> 选「在看」
    await tester.tap(find.byIcon(Icons.bookmark_add_outlined).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('在看').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final dao = FavoritesDao(db);
    // 在 fake async 环境里读数据库要包一层 runAsync，否则永远等不到
    final saved = await tester.runAsync(() => dao.watchAll().first);
    expect(saved!.length, 1);
    expect(saved.single.category, FavoriteCategory.watching.key);

    // 再打开菜单 -> 取消追番（这里以前点了没反应）
    await tester.tap(find.byIcon(Icons.bookmark_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('取消追番').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final after = await tester.runAsync(() => dao.watchAll().first);
    expect(after, isEmpty);

    await shutdownApp(tester);
  });
}
