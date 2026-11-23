import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_providers.dart';
import '../../core/images/disk_image_cache.dart';
import '../../core/images/cover_cache.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/daos.dart';
import 'data/anilist_catalog.dart';
import 'data/bili_catalog.dart';
import 'data/bili_episode_matcher.dart';
import 'data/bili_wbi.dart';
import 'data/catalog_merge.dart';
import 'data/catalog_models.dart';
import 'data/catalog_repository.dart';
import 'data/cycani_catalog.dart';

/// 网络与元数据层的依赖装配。
///
/// 约定：页面只依赖 `catalogRepositoryProvider` 与下面几个 FutureProvider，
/// 不直接 new 任何 provider / client，换源只改这一处。

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(logger: ref.watch(appLoggerProvider));
});

final biliWbiProvider = Provider<BiliWbi>((ref) {
  return BiliWbi(ref.watch(apiClientProvider));
});

final biliCatalogProvider = Provider<BiliCatalog>((ref) {
  return BiliCatalog(
    ref.watch(apiClientProvider),
    ref.watch(biliWbiProvider),
  );
});

final anilistCatalogProvider = Provider<AniListCatalog>((ref) {
  return AniListCatalog(ref.watch(apiClientProvider));
});

final cycaniCatalogProvider = Provider<CycaniCatalog>((ref) {
  return CycaniCatalog(ref.watch(apiClientProvider));
});

final catalogCacheDaoProvider = Provider<CatalogCacheDao>((ref) {
  return CatalogCacheDao(ref.watch(appDatabaseProvider));
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepositoryImpl(
    bili: ref.watch(biliCatalogProvider),
    anilist: ref.watch(anilistCatalogProvider),
    cycani: ref.watch(cycaniCatalogProvider),
    cache: ref.watch(catalogCacheDaoProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

/// B 站分集匹配（弹幕 cid、剧集卡片补图都用它）。
final biliEpisodeMatcherProvider = Provider<BiliEpisodeMatcher>((ref) {
  return BiliEpisodeMatcher(
    ref.watch(biliCatalogProvider),
    ref.watch(catalogCacheDaoProvider),
    ref.watch(appLoggerProvider),
  );
});

/// 次元城条目的分集补全信息（封面/时长/日期），按集号索引。
final episodeMetaProvider =
    FutureProvider.family<Map<int, AnimeEpisode>, String>((ref, internalId) async {
  final detail = await ref.watch(animeDetailProvider(internalId).future);
  if (detail.summary.source != CatalogSource.cycani) {
    return const <int, AnimeEpisode>{};
  }
  final episodes =
      await ref.watch(biliEpisodeMatcherProvider).match(detail.summary);
  if (episodes == null) return const <int, AnimeEpisode>{};
  return {for (final ep in episodes) ep.index: ep};
});

final diskImageCacheProvider = Provider<CoverCache>((ref) {
  return DiskImageCache(
    client: ref.watch(apiClientProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

/// 首页：当季新番（次元城周表，中文标题 + 更新进度）。
///
/// 为什么不用 B 站连载中：那个池子里混着柯南/海绵宝宝这类长寿番，
/// 且 B 站受版权限制，当季新番大量缺失。
final homeSeasonProvider = FutureProvider<CatalogPage>((ref) {
  return ref.watch(catalogRepositoryProvider).seasonNow(limit: 12);
});

/// 首页：热门推荐（按追番人数，含连载）。
final homePopularProvider = FutureProvider<CatalogPage>((ref) {
  return ref.watch(catalogRepositoryProvider).browse(
        page: 1,
        pageSize: 12,
        order: '3',
      );
});

/// 首页：日漫老番（已完结），**每天随机**抽取。
///
/// 取 B 站 `is_finish=1 & order=1`（这一维出来的多是犬夜叉/超电磁炮/刀剑神域这类
/// 真正的老番，而不是按"追番人数"排在前的当季热门），抓 3 页约 72 部，
/// 同系列去重后按「当天日期」做种子洗牌 —— 同一天打开看到的结果稳定，跨天就换一批。
final homeClassicProvider = FutureProvider<CatalogPage>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);

  final pages = await Future.wait([
    for (var page = 1; page <= 3; page++)
      repo.browse(page: page, pageSize: 24, isFinish: 1, order: '1'),
  ]);

  final all = <AnimeSummary>[];
  for (final page in pages) {
    all.addAll(page.items);
  }

  final distinct = CatalogMerger.distinctSeries(all);
  // 以日期为种子：同一天内稳定，跨天自动换一批
  final now = DateTime.now();
  final seed = now.year * 10000 + now.month * 100 + now.day;
  distinct.shuffle(Random(seed));

  return CatalogPage(items: distinct, page: 1, hasMore: false);
});

/// 卡片上的"更新至第 N 话"（仅次元城有数据）。
final animeProgressProvider =
    FutureProvider.family<int?, String>((ref, internalId) {
  return ref.watch(catalogRepositoryProvider).progressOf(internalId);
});

/// 详情：按 `source:id` 拉取并缓存。
final animeDetailProvider =
    FutureProvider.family<AnimeDetail, String>((ref, internalId) {
  return ref.watch(catalogRepositoryProvider).detail(internalId);
});

/// 详情补充：用 AniList 补角色/简介，失败返回 null。
final animeEnrichmentProvider =
    FutureProvider.family<AnimeDetail?, String>((ref, internalId) async {
  final detail = await ref.watch(animeDetailProvider(internalId).future);
  return ref.watch(catalogRepositoryProvider).enrich(detail);
});

/// 搜索分页状态的参数对象（用于 family 缓存）。
class SearchQuery {
  const SearchQuery(this.keyword, this.page);

  final String keyword;
  final int page;

  @override
  bool operator ==(Object other) =>
      other is SearchQuery && other.keyword == keyword && other.page == page;

  @override
  int get hashCode => Object.hash(keyword, page);
}

final searchPageProvider =
    FutureProvider.family<CatalogPage, SearchQuery>((ref, query) {
  return ref.watch(catalogRepositoryProvider).search(
        query.keyword,
        page: query.page,
      );
});
