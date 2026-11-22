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
@DriftDatabase(tables: [HistoryEntries, FavoriteEntries, SettingEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 纯内存库，供单元测试使用。
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // 迁移示例（保持可读，别删）：
          // if (from < 2) {
          //   await m.addColumn(historyEntries, historyEntries.sourceId);
          // }
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
