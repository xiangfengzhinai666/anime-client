import '../../../core/logging/app_logger.dart';
import '../../../core/storage/daos.dart';
import 'bili_catalog.dart';
import 'catalog_models.dart';
import 'source_match.dart';

/// B 站分集匹配：给定一个（可能来自别的站的）番剧条目，找到 B 站对应番剧的分集。
///
/// 用途：
/// - 弹幕：拿 cid 拉弹幕；
/// - 详情页剧集卡片：补每集封面/时长/播出日期（次元城只有 id/title）。
///
/// 匹配策略复用换源那套：标题变体 → 打分（年份/集数/季号/剧场版）→ 逐个试 season，
/// 分集为空就换下一个。结果按标题缓存 7 天。
class BiliEpisodeMatcher {
  BiliEpisodeMatcher(this._bili, this._cache, this._logger);

  final BiliCatalog _bili;
  final CatalogCacheDao _cache;
  final AppLogger _logger;

  static const Duration _ttl = Duration(days: 7);

  /// 返回匹配到的 B 站分集；匹配不到返回 null。
  Future<List<AnimeEpisode>?> match(AnimeSummary summary) async {
    final cacheKey = 'bili-episodes:${summary.title}';
    final cached = await _cache.get(cacheKey, ttl: _ttl);
    if (cached != null) {
      final raw = cached['episodes'];
      if (raw is List) {
        final episodes = raw
            .whereType<Map>()
            .map((e) => AnimeEpisode.fromJson(e.cast<String, dynamic>()))
            .toList();
        if (episodes.isNotEmpty) return episodes;
      }
    }

    final found = <AnimeSummary>[];
    for (final query in titleQueryVariants(summary.title).take(6)) {
      try {
        final page = await _bili.search(query, pageSize: 10);
        found.addAll(page.items);
      } catch (e) {
        _logger.debug('matcher', 'B 站搜索失败（$query）：$e');
      }
      if (found.isNotEmpty) {
        final best = pickBestCandidate(summary, found);
        if (best != null && matchScore(summary, best) >= 6) break;
      }
    }

    if (found.isEmpty) {
      _logger.debug('matcher', 'B 站没有搜到「${summary.title}」');
      return null;
    }

    final ranked = found.toList()
      ..sort((a, b) => matchScore(summary, b).compareTo(matchScore(summary, a)));

    for (final candidate in ranked.take(4)) {
      if (!isReliableMatch(summary, candidate)) {
        _logger.debug(
          'matcher',
          '跳过不可信匹配「${candidate.title}」(year=${candidate.year})',
        );
        continue;
      }
      try {
        final detail = await _bili.detail(candidate.sourceId);
        if (detail.episodes.isEmpty) continue;
        _logger.debug(
          'matcher',
          '「${summary.title}」→ B 站「${candidate.title}」(${detail.episodes.length} 集)',
        );
        await _cache.put(cacheKey, {
          'episodes': detail.episodes.map((e) => e.toJson()).toList(),
        });
        return detail.episodes;
      } catch (e) {
        _logger.debug('matcher', 'season ${candidate.sourceId} 取分集失败：$e');
      }
    }
    return null;
  }
}
