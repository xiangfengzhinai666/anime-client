import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/daos.dart';
import '../../catalog/data/bili_catalog.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/cycani_catalog.dart';
import '../../catalog/data/source_match.dart';
import 'danmaku_models.dart';

/// 弹幕数据层：按需从多个源拉取并合并。
///
/// 源的能力现状：
/// - [DanmakuSource.server]：次元城自带弹幕（无需登录，实测一集约 600 条）；
/// - [DanmakuSource.bilibili]：用标题匹配 B 站番剧，再按集号取 cid，拉公开弹幕 XML；
/// - [DanmakuSource.bilibiliHkTw]：需要港澳台季 id，目前依赖弹弹play 或后续逆向；
/// - [DanmakuSource.tencent]：需要 vid，暂缓；
/// - [DanmakuSource.dandanplay]：需要 developer appId/appSecret（用户配置）。
class DanmakuRepository {
  DanmakuRepository({
    required ApiClient client,
    required BiliCatalog bili,
    required CatalogCacheDao cache,
    required AppLogger logger,
  })  : _client = client,
        _bili = bili,
        _cache = cache,
        _logger = logger;



  final ApiClient _client;
  final BiliCatalog _bili;
  final CatalogCacheDao _cache;
  final AppLogger _logger;

  static const Duration _ttl = Duration(hours: 24);

  /// 拉取一集的多源弹幕。
  ///
  /// [internalId] 形如 `cycani:3862`，[sectionId] 是次元城的分集 id。
  Future<DanmakuBundle> load({
    required String internalId,
    required String sectionId,
    required int episodeIndex,
    required AnimeSummary summary,
    required Set<DanmakuSource> sources,
    String? dandanplayAppId,
    String? dandanplayAppSecret,
  }) async {
    final failed = <DanmakuSource>{};
    final merged = <DanmakuItem>[];
    final seen = <String>{};

    void absorb(List<DanmakuItem> items) {
      for (final item in items) {
        final key = '${item.timeMs}|${item.text}';
        if (seen.add(key)) merged.add(item);
      }
    }

    for (final source in sources) {
      _logger.debug('danmaku', '开始拉取 ${source.label}');
      try {
        final items = await _loadOne(
          source: source,
          internalId: internalId,
          sectionId: sectionId,
          episodeIndex: episodeIndex,
          summary: summary,
          appId: dandanplayAppId,
          appSecret: dandanplayAppSecret,
        );
        _logger.debug('danmaku', '${source.label} 返回 ${items.length} 条');
        if (items.isEmpty) {
          failed.add(source);
        } else {
          absorb(items);
        }
      } catch (e) {
        _logger.warn('danmaku', '${source.label} 拉取失败：$e');
        failed.add(source);
      }
    }

    merged.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return DanmakuBundle(items: merged, failedSources: failed);
  }

  Future<List<DanmakuItem>> _loadOne({
    required DanmakuSource source,
    required String internalId,
    required String sectionId,
    required int episodeIndex,
    required AnimeSummary summary,
    String? appId,
    String? appSecret,
  }) async {
    switch (source) {
      case DanmakuSource.server:
        return _loadCycani(sectionId);
      case DanmakuSource.bilibili:
        return _loadBilibili(summary, episodeIndex, DanmakuSource.bilibili);
      case DanmakuSource.bilibiliHkTw:
        // 港澳台季 id 还拿不到，先复用主站 cid；没有就当作无数据
        return _loadBilibili(summary, episodeIndex, DanmakuSource.bilibiliHkTw);
      case DanmakuSource.dandanplay:
        return _loadDandanplay(
            summary.title, episodeIndex, appId, appSecret);
      case DanmakuSource.tencent:
        return const [];
    }
  }

  // ---------------------------------------------------------------- 次元城

  Future<List<DanmakuItem>> _loadCycani(String sectionId) async {
    final cacheKey = 'danmaku:cycani:$sectionId';
    final cached = await _cache.get(cacheKey, ttl: _ttl);
    if (cached != null) {
      final raw = cached['items'];
      if (raw is String) return DanmakuItem.decodeList(raw);
    }

    final all = <DanmakuItem>[];
    var page = 1;
    while (page <= 20) {
      final json = await _client.getJson(
        '${CycaniCatalog.base}/api/sections/$sectionId/danmaku',
        query: {'page': page, 'page_size': 200},
        headers: CycaniCatalog.appHeaders,
        tag: 'cycani-danmaku',
      );
      final data = json['data'];
      if (data is! Map) break;
      final items = data['items'];
      if (items is! List || items.isEmpty) break;

      all.addAll(parseCycaniDanmaku(items));
      final count = (data['count'] as num?)?.toInt() ?? all.length;
      if (all.length >= count || items.length < 200) break;
      page++;
    }

    if (all.isNotEmpty) {
      await _cache.put(cacheKey, {'items': DanmakuItem.encodeList(all)});
    }
    return all;
  }

  // ---------------------------------------------------------------- B 站

  Future<List<DanmakuItem>> _loadBilibili(
    AnimeSummary summary,
    int episodeIndex,
    DanmakuSource source,
  ) async {
    final cid = await _resolveBilibiliCid(summary, episodeIndex);
    if (cid == null) return const [];

    final cacheKey = 'danmaku:bili:$cid';
    final cached = await _cache.get(cacheKey, ttl: _ttl);
    if (cached != null) {
      final raw = cached['items'];
      if (raw is String) return DanmakuItem.decodeList(raw);
    }

    final bytes = await _client.getBytes(
      'https://api.bilibili.com/x/v1/dm/list.so?oid=$cid',
      headers: const {'Referer': 'https://www.bilibili.com/'},
    );
    final xml = decodeDanmakuBytes(bytes);
    final items = parseBilibiliDanmakuXml(xml, source: source);
    if (items.isNotEmpty) {
      await _cache.put(cacheKey, {'items': DanmakuItem.encodeList(items)});
    }
    return items;
  }

  /// 标题 → B 站番剧 → 第 N 集的 cid（带缓存）。
  Future<int?> _resolveBilibiliCid(
    AnimeSummary summary,
    int episodeIndex,
  ) async {
    final title = summary.title;
    final mappingKey = 'danmaku:bili-map:$title';
    final cached = await _cache.get(mappingKey, ttl: const Duration(days: 7));
    String? seasonId = cached?['season_id'] as String?;

    if (seasonId == null || seasonId.isEmpty) {
      try {
        // 标题带「第三季」这类后缀时，B 站搜索往往直接 0 结果，
        // 所以复用换源那套：生成变体、多查几次、再打分挑最像的。
        final found = <AnimeSummary>[];
        for (final query in titleQueryVariants(title).take(6)) {
          try {
            final page = await _bili.search(query, pageSize: 10);
            found.addAll(page.items);
          } catch (_) {}
          if (found.isNotEmpty) {
            final best = pickBestCandidate(summary, found);
            if (best != null && matchScore(summary, best) >= 6) break;
          }
        }
        // 按分数排序，逐个试：标题最像的可能是预告/特番（分集为 0）
        final ranked = found.toList()
          ..sort((a, b) => matchScore(summary, b).compareTo(matchScore(summary, a)));
        if (ranked.isEmpty) {
          _logger.debug('danmaku', 'B 站没有匹配到「$title」');
          return null;
        }

        for (final candidate in ranked.take(4)) {
          final cid = await _tryBilibiliSeason(candidate.sourceId, episodeIndex);
          if (cid != null) {
            seasonId = candidate.sourceId;
            _logger.debug(
              'danmaku',
              'B 站匹配「$title」→「${candidate.title}」(season=$seasonId, cid=$cid)',
            );
            await _cache.put(mappingKey, {'season_id': seasonId});
            return cid;
          }
        }
        _logger.debug('danmaku', 'B 站候选都没有可用分集（$title）');
        return null;
      } catch (e) {
        _logger.warn('danmaku', 'B 站番剧匹配失败（$title）：$e');
        return null;
      }
    }

    return _tryBilibiliSeason(seasonId, episodeIndex);
  }

  /// 取某个 season 第 N 集的 cid；分集为空/无 cid 时返回 null。
  Future<int?> _tryBilibiliSeason(String seasonId, int episodeIndex) async {
    try {
      final detail = await _bili.detail(seasonId);
      if (detail.episodes.isEmpty) return null;
      AnimeEpisode? target;
      for (final ep in detail.episodes) {
        if (ep.index == episodeIndex) {
          target = ep;
          break;
        }
      }
      target ??= detail.episodes.first;
      if (target.cid == 0) return null;
      _logger.debug(
        'danmaku',
        'season=$seasonId 分集 ${detail.episodes.length} 个，第 $episodeIndex 集 cid=${target.cid}',
      );
      return target.cid;
    } catch (e) {
      _logger.debug('danmaku', 'season=$seasonId 取分集失败：$e');
      return null;
    }
  }

  // ---------------------------------------------------------------- 弹弹play

  Future<List<DanmakuItem>> _loadDandanplay(
    String title,
    int episodeIndex,
    String? appId,
    String? appSecret,
  ) async {
    if (appId == null || appId.isEmpty || appSecret == null || appSecret.isEmpty) {
      return const [];
    }
    // 具体签名与解析在拿到 key 后补全（见 S4 报告）
    return const [];
  }
}
