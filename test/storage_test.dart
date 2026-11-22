import 'package:anime_client/core/storage/daos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  late HistoryDao history;
  late FavoritesDao favorites;
  late SettingsDao settings;

  setUp(() {
    final db = newMemoryDatabase();
    addTearDown(db.close);
    history = HistoryDao(db);
    favorites = FavoritesDao(db);
    settings = SettingsDao(db);
  });

  test('观看历史：写入两条后按时间倒序读出，重复集数会覆盖', () async {
    await history.saveProgress(
      bangumiId: 1,
      episode: 1,
      positionSeconds: 30,
      durationSeconds: 1440,
      title: '葬送的芙莉莲',
    );
    await history.saveProgress(
      bangumiId: 1,
      episode: 2,
      positionSeconds: 10,
      durationSeconds: 1440,
      title: '葬送的芙莉莲',
    );

    var rows = await history.recent();
    expect(rows.length, 2);
    expect(rows.first.episode, 2, reason: '最近更新的排最前');

    // 同一集再次写入 → 覆盖而不是新增
    await history.saveProgress(
      bangumiId: 1,
      episode: 1,
      positionSeconds: 600,
      durationSeconds: 1440,
      title: '葬送的芙莉莲',
    );

    rows = await history.recent();
    expect(rows.length, 2);
    final ep1 = await history.find(1, 1);
    expect(ep1?.positionSeconds, 600);
    expect(await history.count(), 2);
  });

  test('观看历史：可按番剧+集数删除，也可整表清空', () async {
    await history.saveProgress(
        bangumiId: 2, episode: 3, positionSeconds: 1, durationSeconds: 100);
    await history.saveProgress(
        bangumiId: 2, episode: 4, positionSeconds: 1, durationSeconds: 100);

    expect(await history.removeEpisode(2, 3), 1);
    expect(await history.count(), 1);

    expect(await history.clearAll(), 1);
    expect(await history.count(), 0);
  });

  test('追番：写入后可按分类查询，重复写入更新分类', () async {
    await favorites.upsert(
        bangumiId: 10,
        title: '孤独摇滚',
        category: FavoriteCategory.want,
        totalEpisodes: 12);
    await favorites.upsert(
        bangumiId: 11,
        title: '无职转生',
        category: FavoriteCategory.watching);

    expect((await favorites.watchByCategory(FavoriteCategory.want).first)
        .single
        .title, '孤独摇滚');

    await favorites.upsert(
        bangumiId: 10,
        title: '孤独摇滚',
        category: FavoriteCategory.watched);

    final want = await favorites.watchByCategory(FavoriteCategory.want).first;
    final watched =
        await favorites.watchByCategory(FavoriteCategory.watched).first;
    expect(want, isEmpty);
    expect(watched.single.bangumiId, 10);
    expect(await favorites.count(), 2);

    expect(await favorites.remove(10), 1);
    expect(await favorites.count(), 1);
  });

  test('设置：写入后读取一致，覆盖生效', () async {
    await settings.set('theme_mode', 'dark');
    expect(await settings.get('theme_mode'), 'dark');

    await settings.set('theme_mode', 'light');
    expect(await settings.get('theme_mode'), 'light');

    expect(await settings.get('not_exist'), isNull);
    expect(await settings.remove('theme_mode'), 1);
    expect(await settings.get('theme_mode'), isNull);
  });
}
