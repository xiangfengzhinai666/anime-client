import '../../core/storage/app_database.dart';

/// 同一部番只保留最近的一条观看记录（输入需按时间倒序）。
///
/// 首页「继续观看」和历史页都用它，避免同一部番重复出现。
List<HistoryEntry> latestPerShow(List<HistoryEntry> items) {
  final seen = <String>{};
  final out = <HistoryEntry>[];
  for (final item in items) {
    if (seen.add('${item.source}:${item.bangumiId}')) out.add(item);
  }
  return out;
}
