import '../../../core/logging/app_logger.dart';
import '../../../core/storage/daos.dart';
import 'anilist_catalog.dart';
import 'bili_catalog.dart';
import 'catalog_merge.dart';
import 'cycani_catalog.dart';
import 'catalog_models.dart';

/// 元数据仓库：把 B 站与 AniList 合成一个「番剧档案」入口。
///
/// 策略（S2）：
/// - 搜索：含中日文字符的查询走 B 站（中文命中率最高）；纯拉丁字母的查询
///   两边都查，B 站优先，AniList 补缺；B 站失败时退回 AniList。
/// - 索引/排行：只用 B 站（AniList 没有"本季/排行"这种中文运营维度）。
/// - 详情：按 `source:id` 前缀路由到对应源，结果落库缓存 6 小时。
/// - 补充：B 站条目会用日文原名去 AniList 找同番，补角色表与简介。
abstract class CatalogRepository {
  Future<CatalogPage> search(String keyword, {int page});

  Future<CatalogPage> browse({
    int page,
    int pageSize,
    int year,
    int area,
    int isFinish,
    String order,
  });

  Future<AnimeDetail> detail(String internalId, {bool force});

  Future<AnimeDetail?> enrich(AnimeDetail detail);

  /// 当季新番（中文标题 + 更新进度）。
  Future<CatalogPage> seasonNow({int limit});

  /// 已更新集数（仅次元城）。
  Future<int?> progressOf(String internalId);
}

/// 默认实现：B 站 + AniList + 本地缓存。
class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({
    required this.bili,
    required this.anilist,
    required this.cycani,
    required this.cache,
    required this.logger,
  });

  static final RegExp _cjk = RegExp(r'[\u4e00-\u9fff\u3040-\u30ff]');

  final BiliCatalog bili;
  final AniListCatalog anilist;
  final CycaniCatalog cycani;
  final CatalogCacheDao cache;
  final AppLogger logger;

  // ---------------------------------------------------------------- 搜索

  @override
  Future<CatalogPage> search(String keyword, {int page = 1}) async {
    final kw = keyword.trim();
    if (kw.isEmpty) {
      return const CatalogPage(items: [], page: 1, hasMore: false);
    }

    // 两个源都查：中文/西文一视同仁。
    // 之前按语言分流（中文只查 B 站）是错的——AniList 的中文索引虽然漏个别标题
    // （如「芙莉莲」），但大多数中文名能命中；B 站则受版权限制漏番。
    final results = await Future.wait([
      _safeBiliSearch(kw, page),
      _safeAniListSearch(kw, page),
    ]);
    final biliPage = results[0];
    final aniListPage = results[1];

    // 日文桥：B 站结果自带 org_title（日文原名），用它去 AniList 补全所有季。
    // 例：B 站只有「芙莉莲」S1，AniList 能补出 S2 / 迷你动画。
    final bridged = page == 1 ? await _bridgeSeasons(biliPage.items) : const <AnimeSummary>[];

    final merged = CatalogMerger.merge(
      biliPage.items,
      [...aniListPage.items, ...bridged],
      trace: (message) => logger.debug('merge', message),
    );
    logger.debug(
      'merge',
      '主源 ${biliPage.items.length} 条 → 合并后 ${merged.length} 条',
    );

    return CatalogPage(
      items: merged,
      page: page,
      hasMore: biliPage.hasMore || aniListPage.hasMore,
    );
  }

  Future<CatalogPage> _safeBiliSearch(String keyword, int page) async {
    try {
      return await bili.search(keyword, page: page);
    } catch (e) {
      logger.warn('catalog', 'B 站搜索失败（$keyword）：$e');
      return const CatalogPage(items: [], page: 1, hasMore: false);
    }
  }

  Future<CatalogPage> _safeAniListSearch(String keyword, int page) async {
    try {
      return await anilist.search(keyword, page: page);
    } catch (e) {
      logger.warn('catalog', 'AniList 搜索失败（$keyword）：$e');
      return CatalogPage(
        items: const [],
        page: 1,
        hasMore: false,
        source: CatalogSource.anilist,
      );
    }
  }

  /// 用 B 站结果的日文原名去 AniList 找同系列全部季。
  ///
  /// 只取前 2 条，避免请求数膨胀；失败静默（不影响主结果）。
  Future<List<AnimeSummary>> _bridgeSeasons(List<AnimeSummary> biliItems) async {
    final jpTitles = <String>{};
    for (final item in biliItems.take(2)) {
      final jp = item.subtitle.trim();
      if (jp.isEmpty) continue;
      // 只要日文（含假名）或罗马音，中文副标题没有桥接价值
      if (_cjk.hasMatch(jp) || RegExp(r'[A-Za-z]').hasMatch(jp)) {
        jpTitles.add(jp);
      }
    }

    final bridged = <AnimeSummary>[];
    for (final title in jpTitles) {
      try {
        final page = await anilist.search(title, perPage: 12);
        logger.debug('catalog', '日文桥「$title」→ ${page.items.length} 条');
        bridged.addAll(page.items);
      } catch (e) {
        logger.warn('catalog', '日文桥失败（$title）：$e');
      }
    }
    return bridged;
  }

  // ---------------------------------------------------------------- 索引

  @override
  /// 番剧索引。
  ///
  /// `year` 目前会被 B 站接口忽略（实测：2023/2025/2026 返回同一份结果），
  /// 保留参数是为了将来换源或接口恢复；UI 不再暴露年份筛选。
  Future<CatalogPage> browse({
    int page = 1,
    int pageSize = 24,
    int year = -1,
    int area = -1,
    int isFinish = -1,
    String order = '3',
  }) {
    return bili.index(
      page: page,
      pageSize: pageSize,
      year: year,
      area: area,
      isFinish: isFinish,
      order: order,
    );
  }

  // ---------------------------------------------------------------- 详情

  @override
  Future<AnimeDetail> detail(String internalId, {bool force = false}) async {
    if (!force) {
      final cached = await cache.get(internalId);
      if (cached != null) {
        try {
          final detail = AnimeDetail.fromJson(cached);
          // 次元城的分集必须带 sectionId 才能换播放地址。
          // 旧版本缓存里的分集没有这个字段，遇到就当作过期重新拉。
          final staleCycani = detail.summary.source == CatalogSource.cycani &&
              detail.episodes.isNotEmpty &&
              detail.episodes.every((e) => e.sectionId.isEmpty);
          if (!staleCycani) return detail;
          logger.debug('catalog', '缓存缺少 sectionId，重新拉取 $internalId');
        } catch (e) {
          logger.warn('catalog', '缓存解析失败，重新拉取：$e');
        }
      }
    }

    final parts = internalId.split(':');
    final source = CatalogSource.parse(parts.first);
    final sourceId = parts.length > 1 ? parts.sublist(1).join(':') : '';

    final detail = switch (source) {
      CatalogSource.bili => await bili.detail(sourceId),
      CatalogSource.anilist => await anilist.detail(sourceId),
      CatalogSource.cycani => await cycani.detail(sourceId),
    };

    await cache.put(internalId, detail.toJson());
    return detail;
  }

  final Map<String, (int, DateTime)> _progressCache = {};

  /// 已更新集数（仅次元城有；其它源返回 null）。
  ///
  /// 会话内缓存 30 分钟，避免首页/列表反复请求。
  @override
  Future<int?> progressOf(String internalId) async {
    final cached = _progressCache[internalId];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < const Duration(minutes: 30)) {
      return cached.$1;
    }
    final parts = internalId.split(':');
    if (parts.length != 2 ||
        CatalogSource.parse(parts.first) != CatalogSource.cycani) {
      return null;
    }
    final value = await cycani.episodeProgress(parts.last);
    if (value != null) {
      _progressCache[internalId] = (value, DateTime.now());
    }
    return value;
  }

  /// 当季新番：次元城周表（中文标题 + 更新进度）。
  ///
  /// 排序：年份新→旧 → 评分高→低 → 标题，避免周表原顺序看起来随机。
  @override
  Future<CatalogPage> seasonNow({int limit = 12}) async {
    final items = await cycani.weekly()
      ..sort((a, b) {
        final yearCmp = (b.year ?? 0).compareTo(a.year ?? 0);
        if (yearCmp != 0) return yearCmp;
        final scoreCmp = (b.score ?? 0).compareTo(a.score ?? 0);
        if (scoreCmp != 0) return scoreCmp;
        return a.title.compareTo(b.title);
      });

    return CatalogPage(
      items: items.take(limit).toList(),
      page: 1,
      hasMore: false,
      source: CatalogSource.cycani,
    );
  }

  /// 用 AniList 给 B 站条目"补档案"（角色表、更完整的简介）。
  ///
  /// 匹配保守：只认日文原名/副标题，年份相差不超过 1 年；
  /// 找不到就返回 null，绝不硬配。
  @override
  Future<AnimeDetail?> enrich(AnimeDetail detail) async {
    if (detail.summary.source != CatalogSource.bili) return null;
    if (detail.characters.isNotEmpty) return null;

    // AniList 只认罗马音/日文名，中文名搜不到（实测 0 条）。
    // B 站详情不一定带 jp_title，这里再借一次 B 站搜索拿 org_title。
    var jpTitle = detail.originalTitle.trim();
    if (jpTitle.isEmpty) {
      jpTitle = await _lookupJapaneseTitle(detail.summary.title);
    }

    final candidates = <String>{
      if (jpTitle.isNotEmpty) jpTitle,
      if (detail.summary.subtitle.isNotEmpty) detail.summary.subtitle,
      if (!_cjk.hasMatch(detail.summary.title)) detail.summary.title,
    };

    for (final candidate in candidates) {
      try {
        final page = await anilist.search(candidate, perPage: 5);
        logger.debug(
          'catalog',
          'AniList 补充匹配「$candidate」→ ${page.items.length} 条',
        );
        for (final item in page.items) {
          final matched = TitleMatcher.sameShow(
            titleA: detail.summary.title,
            titleB: item.title,
            yearA: detail.summary.year,
            yearB: item.year,
            episodesA: detail.summary.totalEpisodes,
            episodesB: item.totalEpisodes,
          );
          // 标题可能对不上（中文 vs 罗马音），年份 + 集数一致也接受
          final yearEquals = detail.summary.year != null &&
              detail.summary.year == item.year &&
              detail.summary.totalEpisodes != null &&
              detail.summary.totalEpisodes == item.totalEpisodes;
          if (matched || yearEquals) {
            logger.info('catalog', 'AniList 命中：${item.title}（${item.sourceId}）');
            return await anilist.detail(item.sourceId);
          }
        }
      } catch (e) {
        logger.warn('catalog', 'AniList 补充失败（$candidate）：$e');
      }
    }
    return null;
  }

  /// 用 B 站搜索补出日文原名（`org_title`）。
  ///
  /// 只取第一条带 org_title 的结果；失败返回空串，不影响详情页。
  Future<String> _lookupJapaneseTitle(String title) async {
    try {
      final page = await bili.search(title, page: 1, pageSize: 5);
      for (final item in page.items) {
        final candidate = item.subtitle.trim();
        if (candidate.isNotEmpty && _cjk.hasMatch(candidate)) {
          return candidate;
        }
      }
    } catch (e) {
      logger.debug('catalog', '取日文原名失败（$title）：$e');
    }
    return '';
  }
}
