import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// 应用数据库。
///
/// 约定：
/// - 表定义集中在 `tables.dart`，DAO 逻辑集中在 `daos.dart`，本文件只管连接与迁移；
/// - 每升一次 schemaVersion，必须在 `onUpgrade` 里显式写迁移，不允许丢数据；
/// - 测试用 `AppDatabase.memory()`，生产用 `AppDatabase.openFile()`。
@DriftDatabase(
  tables: [
    HistoryEntries,
    FavoriteEntries,
    SettingEntries,
    CatalogCacheEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 纯内存库，供单元测试使用。
  AppDatabase.memory() : super(NativeDatabase.memory());

  /// 当前 schema 版本。
  /// v1：history / favorites / settings
  /// v2：+ catalog_cache（元数据缓存）
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(catalogCacheEntries);
          }
          if (from < 3) {
            await m.addColumn(historyEntries, historyEntries.source);
            await m.addColumn(favoriteEntries, favoriteEntries.source);
          }
          if (from < 4) {
            // 主键从 (bangumi_id[, episode]) 改成 (source, bangumi_id[, episode])。
            // SQLite 不能改主键，只能重建表再把数据搬过去。
            await customStatement('''
CREATE TABLE "history_entries_new" (
  "bangumi_id" INTEGER NOT NULL,
  "episode" INTEGER NOT NULL,
  "source" TEXT NOT NULL DEFAULT 'cycani',
  "title" TEXT NOT NULL DEFAULT '',
  "episode_title" TEXT NOT NULL DEFAULT '',
  "cover" TEXT NOT NULL DEFAULT '',
  "position_seconds" INTEGER NOT NULL DEFAULT 0,
  "duration_seconds" INTEGER NOT NULL DEFAULT 0,
  "updated_at" TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP),
  PRIMARY KEY ("source", "bangumi_id", "episode")
)''');
            await customStatement('''
INSERT INTO history_entries_new
  (bangumi_id, episode, source, title, episode_title, cover, position_seconds, duration_seconds, updated_at)
SELECT bangumi_id, episode, source, title, episode_title, cover, position_seconds, duration_seconds, updated_at
FROM history_entries''');
            await customStatement('DROP TABLE history_entries');
            await customStatement(
                'ALTER TABLE history_entries_new RENAME TO history_entries');

            await customStatement('''
CREATE TABLE "favorite_entries_new" (
  "bangumi_id" INTEGER NOT NULL,
  "title" TEXT NOT NULL,
  "cover" TEXT NOT NULL DEFAULT '',
  "category" TEXT NOT NULL DEFAULT 'want',
  "total_episodes" INTEGER NOT NULL DEFAULT 0,
  "source" TEXT NOT NULL DEFAULT 'cycani',
  "updated_at" TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP),
  PRIMARY KEY ("source", "bangumi_id")
)''');
            await customStatement('''
INSERT INTO favorite_entries_new
  (bangumi_id, title, cover, category, total_episodes, source, updated_at)
SELECT bangumi_id, title, cover, category, total_episodes, source, updated_at
FROM favorite_entries''');
            await customStatement('DROP TABLE favorite_entries');
            await customStatement(
                'ALTER TABLE favorite_entries_new RENAME TO favorite_entries');
          }
        },
        beforeOpen: (details) async {
          // 外键约束默认关闭，需要每连接显式打开
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// 生产入口：后台 isolate 打开，避免阻塞 UI。
  static AppDatabase openFile(File file) {
    return AppDatabase(NativeDatabase.createInBackground(file));
  }
}
