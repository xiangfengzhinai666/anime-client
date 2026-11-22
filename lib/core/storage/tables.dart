import 'package:drift/drift.dart';

/// 观看历史：一部番的一集一行，按「番剧 + 集数」唯一。
class HistoryEntries extends Table {
  IntColumn get bangumiId => integer()();
  IntColumn get episode => integer()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get episodeTitle => text().withDefault(const Constant(''))();
  TextColumn get cover => text().withDefault(const Constant(''))();
  IntColumn get positionSeconds => integer().withDefault(const Constant(0))();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {bangumiId, episode};
}

/// 追番：一部番一行，category 为 want / watching / watched。
class FavoriteEntries extends Table {
  IntColumn get bangumiId => integer()();
  TextColumn get title => text()();
  TextColumn get cover => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant('want'))();
  IntColumn get totalEpisodes => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {bangumiId};
}

/// 键值设置：主题、播放偏好、弹幕偏好等。
class SettingEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
