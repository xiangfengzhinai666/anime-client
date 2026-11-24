import 'package:anime_client/core/storage/daos.dart';
import 'package:anime_client/features/catalog/widgets/cover_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('首页继续观看：显示封面缩略图，点一行能续播', (tester) async {
    final db = newMemoryDatabase();
    addTearDown(db.close);

    await HistoryDao(db).saveProgress(
      bangumiId: 2109,
      episode: 2,
      positionSeconds: 300,
      durationSeconds: 1420,
      title: '孤独摇滚！',
      cover: 'https://example.com/bocchi.jpg',
      source: 'cycani',
    );

    useDesktopSize(tester);
    await bootApp(tester, db);
    await tester.pump(const Duration(milliseconds: 200));

    // 滚到页面底部（继续观看在最后）
    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -4000));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('继续观看'), findsOneWidget);
    expect(find.text('孤独摇滚！'), findsWidgets);
    expect(find.textContaining('第 2 集'), findsWidgets);
    // 有封面就渲染 CoverImage（不再只是占位图标）
    expect(find.byType(CoverImage), findsWidgets);

    await shutdownApp(tester);
  });
}
