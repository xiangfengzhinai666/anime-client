import 'package:anime_client/core/storage/daos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  late CatalogCacheDao cache;

  setUp(() {
    final db = newMemoryDatabase();
    addTearDown(db.close);
    cache = CatalogCacheDao(db);
  });

  test('写入后能读出同样的 JSON', () async {
    await cache.put('bili:1', {'a': 1, 'b': '中文'});
    final loaded = await cache.get('bili:1');

    expect(loaded, isNotNull);
    expect(loaded!['a'], 1);
    expect(loaded['b'], '中文');
    expect(await cache.count(), 1);
  });

  test('ttl 为 0 视为过期', () async {
    await cache.put('bili:1', {'a': 1});
    final loaded = await cache.get('bili:1', ttl: Duration.zero);
    expect(loaded, isNull);
  });

  test('同一个 id 覆盖写入不新增行', () async {
    await cache.put('bili:1', {'v': 1});
    await cache.put('bili:1', {'v': 2});

    expect(await cache.count(), 1);
    expect((await cache.get('bili:1'))!['v'], 2);
  });

  test('prune 清理过期缓存，clear 清空', () async {
    await cache.put('bili:1', {'a': 1});
    await cache.put('bili:2', {'a': 2});

    // 全部视为过期
    final removed = await cache.prune(olderThan: Duration.zero);
    expect(removed, 2);
    expect(await cache.count(), 0);

    await cache.put('bili:3', {'a': 3});
    expect(await cache.clear(), 1);
    expect(await cache.count(), 0);
  });
}
