import 'package:drift/drift.dart';

import 'app_database.dart';

/// 追番分类。存储用英文 key，展示用中文 label，两者解耦。
enum FavoriteCategory {
  want('want', '想看'),
  watching('watching', '在看'),
  watched('watched', '看过');

  const FavoriteCategory(this.key, this.label);

  final String key;
  final String label;

  static FavoriteCategory fromKey(String? key) {
    return FavoriteCategory.values.firstWhere(
      (e) => e.key == key,
      orElse: () => FavoriteCategory.want,
    );
  }
}

/// 观看历史读写。
class HistoryDao {
  HistoryDao(this._db);

  final AppDatabase _db;

  /// 记录/更新播放进度（同一番剧同一集只保留一条）。
  Future<void> saveProgress({
    required int bangumiId,
    required int episode,
    required int positionSeconds,
    required int durationSeconds,
    String title = '',
    String episodeTitle = '',
    String cover = '',
  }) {
    return _db.into(_db.historyEntries).insertOnConflictUpdate(
          HistoryEntriesCompanion.insert(
            bangumiId: bangumiId,
            episode: episode,
            title: Value(title),
            episodeTitle: Value(episodeTitle),
            cover: Value(cover),
            positionSeconds: Value(positionSeconds),
            durationSeconds: Value(durationSeconds),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// 最近观看，按更新时间倒序。
  Stream<List<HistoryEntry>> watchRecent({int limit = 30}) {
    final query = _db.select(_db.historyEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
      ..limit(limit);
    return query.watch();
  }

  Future<List<HistoryEntry>> recent({int limit = 30}) {
    final query = _db.select(_db.historyEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
      ..limit(limit);
    return query.get();
  }

  Future<HistoryEntry?> find(int bangumiId, int episode) {
    final query = _db.select(_db.historyEntries)
      ..where((t) => t.bangumiId.equals(bangumiId) & t.episode.equals(episode));
    return query.getSingleOrNull();
  }

  Future<int> count() async {
    final expr = _db.historyEntries.bangumiId.count();
    final query = _db.selectOnly(_db.historyEntries)..addColumns([expr]);
    final row = await query.getSingle();
    return row.read(expr) ?? 0;
  }

  Future<int> removeEpisode(int bangumiId, int episode) {
    final stmt = _db.delete(_db.historyEntries)
      ..where((t) => t.bangumiId.equals(bangumiId) & t.episode.equals(episode));
    return stmt.go();
  }

  Future<int> clearAll() => _db.delete(_db.historyEntries).go();
}

/// 追番列表读写。
class FavoritesDao {
  FavoritesDao(this._db);

  final AppDatabase _db;

  Future<void> upsert({
    required int bangumiId,
    required String title,
    String cover = '',
    FavoriteCategory category = FavoriteCategory.want,
    int totalEpisodes = 0,
  }) {
    return _db.into(_db.favoriteEntries).insertOnConflictUpdate(
          FavoriteEntriesCompanion.insert(
            bangumiId: Value(bangumiId),
            title: title,
            cover: Value(cover),
            category: Value(category.key),
            totalEpisodes: Value(totalEpisodes),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<int> remove(int bangumiId) {
    final stmt =
        _db.delete(_db.favoriteEntries)..where((t) => t.bangumiId.equals(bangumiId));
    return stmt.go();
  }

  Future<FavoriteEntry?> find(int bangumiId) {
    final query = _db.select(_db.favoriteEntries)
      ..where((t) => t.bangumiId.equals(bangumiId));
    return query.getSingleOrNull();
  }

  Stream<List<FavoriteEntry>> watchAll() {
    final query = _db.select(_db.favoriteEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch();
  }

  Stream<List<FavoriteEntry>> watchByCategory(FavoriteCategory category) {
    final query = _db.select(_db.favoriteEntries)
      ..where((t) => t.category.equals(category.key))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch();
  }

  Future<int> count() async {
    final expr = _db.favoriteEntries.bangumiId.count();
    final query = _db.selectOnly(_db.favoriteEntries)..addColumns([expr]);
    final row = await query.getSingle();
    return row.read(expr) ?? 0;
  }
}

/// 键值设置。
class SettingsDao {
  SettingsDao(this._db);

  final AppDatabase _db;

  Future<String?> get(String key) async {
    final query = _db.select(_db.settingEntries)
      ..where((t) => t.key.equals(key));
    final row = await query.getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watch(String key) {
    final query = _db.select(_db.settingEntries)
      ..where((t) => t.key.equals(key));
    return query.watchSingleOrNull().map((row) => row?.value);
  }

  Future<void> set(String key, String value) {
    return _db.into(_db.settingEntries).insertOnConflictUpdate(
          SettingEntriesCompanion.insert(key: key, value: value),
        );
  }

  Future<int> remove(String key) {
    final stmt =
        _db.delete(_db.settingEntries)..where((t) => t.key.equals(key));
    return stmt.go();
  }
}
