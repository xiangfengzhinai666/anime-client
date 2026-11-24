import 'package:anime_client/core/storage/daos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  late dynamic db;

  setUp(() {
    db = newMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('S5 数据层加固：主键带来源', () {
    test('同一 id 不同来源是两条独立的追番', () async {
      final dao = FavoritesDao(db);
      await dao.upsert(
        bangumiId: 2109,
        title: '孤独摇滚！',
        category: FavoriteCategory.watching,
        source: 'cycani',
      );
      await dao.upsert(
        bangumiId: 2109,
        title: 'B站同名番',
        category: FavoriteCategory.want,
        source: 'bili',
      );

      final all = await dao.watchAll().first;
      expect(all.length, 2);
      expect(
        await dao.find(2109, source: 'cycani'),
        isNotNull,
      );
      expect((await dao.find(2109, source: 'bili'))!.title, 'B站同名番');

      // 只删次元城那条，B 站的还在
      await dao.remove(2109, source: 'cycani');
      final left = await dao.watchAll().first;
      expect(left.length, 1);
      expect(left.single.source, 'bili');
    });

    test('同一 id 不同来源的观看记录互不覆盖', () async {
      final dao = HistoryDao(db);
      await dao.saveProgress(
        bangumiId: 166,
        episode: 1,
        positionSeconds: 100,
        durationSeconds: 1440,
        title: '次元城 166',
        source: 'cycani',
      );
      await dao.saveProgress(
        bangumiId: 166,
        episode: 1,
        positionSeconds: 600,
        durationSeconds: 1440,
        title: 'AniList 166',
        source: 'anilist',
      );

      final rows = await dao.recent();
      expect(rows.length, 2);
      expect(
        (await dao.find(166, 1, source: 'cycani'))!.positionSeconds,
        100,
      );
      expect(
        (await dao.find(166, 1, source: 'anilist'))!.positionSeconds,
        600,
      );

      await dao.removeEpisode(166, 1, source: 'cycani');
      final left = await dao.recent();
      expect(left.length, 1);
      expect(left.single.source, 'anilist');
    });

    test('同源同集重复保存只留一条，位置更新', () async {
      final dao = HistoryDao(db);
      for (final pos in [10, 20, 30]) {
        await dao.saveProgress(
          bangumiId: 2109,
          episode: 1,
          positionSeconds: pos,
          durationSeconds: 1440,
          source: 'cycani',
        );
      }
      final rows = await dao.recent();
      expect(rows.length, 1);
      expect(rows.single.positionSeconds, 30);
    });
  });
}
