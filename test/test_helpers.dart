import 'dart:io';

import 'dart:ffi' show DynamicLibrary;

import 'package:anime_client/app/providers/app_providers.dart';
import 'package:anime_client/core/images/cover_cache.dart';
import 'package:anime_client/core/storage/app_database.dart';
import 'package:anime_client/features/catalog/catalog_providers.dart';
import 'package:anime_client/features/catalog/data/catalog_models.dart';
import 'package:anime_client/features/catalog/data/catalog_repository.dart';
import 'package:anime_client/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

/// sqlite3 2.x 不自带二进制，测试进程里用 Windows 自带的 winsqlite3.dll。
bool _sqliteConfigured = false;

void configureTestSqlite() {
  if (_sqliteConfigured) return;
  _sqliteConfigured = true;
  if (Platform.isWindows) {
    open.overrideFor(
      OperatingSystem.windows,
      () => DynamicLibrary.open('winsqlite3.dll'),
    );
  }
}

AppDatabase newMemoryDatabase() {
  configureTestSqlite();
  return AppDatabase.memory();
}

/// 测试用番剧数据。
final List<AnimeSummary> demoAnime = [
  const AnimeSummary(
    source: CatalogSource.bili,
    sourceId: '46089',
    title: '葬送的芙莉莲',
    subtitle: '葬送のフリーレン',
    cover: '',
    year: 2023,
    totalEpisodes: 28,
    score: 9.9,
  ),
  const AnimeSummary(
    source: CatalogSource.anilist,
    sourceId: '154587',
    title: '孤独摇滚',
    subtitle: 'Bocchi the Rock!',
    cover: '',
    year: 2022,
    totalEpisodes: 12,
    score: 8.9,
  ),
];

final AnimeDetail demoDetail = AnimeDetail(
  summary: demoAnime.first,
  synopsis: '寿命逾千年的魔法使芙莉莲，以勇者辛美尔之死为契机，踏上了了解人类的旅途。',
  originalTitle: '葬送のフリーレン',
  areas: const ['日本'],
  episodes: const [
    AnimeEpisode(index: 1, title: '冒险的结束'),
    AnimeEpisode(index: 2, title: '也不一定要是魔法…'),
  ],
  fetchedAt: DateTime(2026, 1, 1),
);

/// 不联网的元数据仓库。
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({
    List<AnimeSummary>? items,
    AnimeDetail? detail,
    this.error,
  })  : items = items ?? demoAnime,
        detailResult = detail ?? demoDetail;

  final List<AnimeSummary> items;
  final AnimeDetail detailResult;

  /// 非空时所有方法都抛这个错误，用来测错误态。
  final Object? error;

  @override
  Future<CatalogPage> search(String keyword, {int page = 1}) async {
    if (error != null) throw error!;
    return CatalogPage(items: items, page: page, hasMore: false);
  }

  @override
  Future<CatalogPage> browse({
    int page = 1,
    int pageSize = 24,
    int year = -1,
    int area = -1,
    int isFinish = -1,
    String order = '3',
  }) async {
    if (error != null) throw error!;
    return CatalogPage(items: items, page: page, hasMore: false);
  }

  @override
  Future<AnimeDetail> detail(String internalId, {bool force = false}) async {
    if (error != null) throw error!;
    // 次元城条目要带 sectionId，才能测"可播放"分支
    if (internalId.startsWith('cycani:')) {
      return AnimeDetail(
        summary: AnimeSummary(
          source: CatalogSource.cycani,
          sourceId: internalId.split(':').last,
          title: detailResult.summary.title,
          cover: detailResult.summary.cover,
          year: detailResult.summary.year,
          score: detailResult.summary.score,
        ),
        synopsis: detailResult.synopsis,
        episodes: [
          for (var i = 1; i <= 2; i++)
            AnimeEpisode(
              index: i,
              title: '第 $i 集',
              sectionId: '900$i',
            ),
        ],
        fetchedAt: detailResult.fetchedAt,
      );
    }
    return detailResult;
  }

  @override
  Future<AnimeDetail?> enrich(AnimeDetail detail) async => null;

  @override
  Future<int?> progressOf(String internalId) async => 8;

  @override
  Future<CatalogPage> seasonNow({int limit = 12}) async {
    if (error != null) throw error!;
    return CatalogPage(
      items: items.take(limit).toList(),
      page: 1,
      hasMore: false,
      source: CatalogSource.cycani,
    );
  }
}

/// 永不联网的图片缓存。
class NoopImageCache implements CoverCache {
  @override
  Future<File?> get(String url) async => null;

  @override
  Future<int> sizeBytes() async => 0;

  @override
  Future<void> clear() async {}
}

/// 把应用挂到内存数据库 + 假数据源上。
Widget buildTestApp(
  AppDatabase db, {
  CatalogRepository? repository,
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      catalogRepositoryProvider
          .overrideWithValue(repository ?? FakeCatalogRepository()),
      diskImageCacheProvider.overrideWithValue(NoopImageCache()),
      ...extraOverrides,
    ],
    child: const AnimeClientApp(),
  );
}

/// 启动应用并等待首帧稳定（不用 pumpAndSettle，避免无限动画卡住）。
Future<void> bootApp(
  WidgetTester tester,
  AppDatabase db, {
  CatalogRepository? repository,
}) async {
  await tester.pumpWidget(buildTestApp(db, repository: repository));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// 卸载组件树，让 drift 的流查询释放定时器（否则测试结束会报 timersPending）。
Future<void> shutdownApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

/// 桌面尺寸（走侧栏布局）。
void useDesktopSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 窄屏尺寸（走底部导航）。
void useMobileSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 860);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
