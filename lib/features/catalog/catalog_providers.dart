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

final catalogCacheDaoProvider = Provider<CatalogCacheDao>((ref) {
  return CatalogCacheDao(ref.watch(appDatabaseProvider));
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepositoryImpl(
    bili: ref.watch(biliCatalogProvider),
    anilist: ref.watch(anilistCatalogProvider),
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

/// 首页：正在连载（按追番人数）。
///
/// 注意：B 站索引接口会忽略 `year` 参数（已实测），所以这里不用"本季"，
/// 改用"连载中"这个确实生效的维度，避免界面撒谎。
final homeOngoingProvider = FutureProvider<CatalogPage>((ref) {
  return ref.watch(catalogRepositoryProvider).browse(
        page: 1,
        pageSize: 12,
        isFinish: 0,
        order: '3',
      );
});

/// 首页：高分推荐。
final homeTopRatedProvider = FutureProvider<CatalogPage>((ref) {
  return ref.watch(catalogRepositoryProvider).browse(
        page: 1,
        pageSize: 12,
        order: '2',
      );
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
