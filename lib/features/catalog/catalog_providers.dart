import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_providers.dart';
import '../../core/images/disk_image_cache.dart';
import '../../core/images/cover_cache.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/daos.dart';
import 'data/anilist_catalog.dart';
import 'data/bili_catalog.dart';
import 'data/bili_wbi.dart';
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

/// 首页轮播：已完结的老番（按追番人数）。
///
/// 为什么不用"评分榜"：B 站评分榜前列混着柯南/小猪佩奇这类超长篇，
/// 当 banner 很难看；用"完结 + 追番人数"更接近"经典老番"。
final homeClassicProvider = FutureProvider<CatalogPage>((ref) {
  return ref.watch(catalogRepositoryProvider).browse(
        page: 1,
        pageSize: 30,
        isFinish: 1,
        order: '3',
      );
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
