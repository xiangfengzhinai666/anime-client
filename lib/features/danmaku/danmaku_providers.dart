import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_providers.dart';
import '../catalog/catalog_providers.dart';
import '../catalog/data/catalog_models.dart';
import 'danmaku_settings.dart';
import 'data/danmaku_models.dart';
import 'data/danmaku_repository.dart';

final danmakuRepositoryProvider = Provider<DanmakuRepository>((ref) {
  return DanmakuRepository(
    client: ref.watch(apiClientProvider),
    bili: ref.watch(biliCatalogProvider),
    cache: ref.watch(catalogCacheDaoProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

/// 一集的弹幕（多源合并）。
typedef DanmakuRequest = ({
  String internalId,
  String sectionId,
  int episode,
  AnimeSummary summary,
});

final danmakuBundleProvider =
    FutureProvider.family<DanmakuBundle, DanmakuRequest>((ref, request) async {
  final settings = ref.watch(danmakuSettingsProvider);
  if (!settings.enabled || request.sectionId.isEmpty) {
    return DanmakuBundle.empty;
  }
  final repo = ref.watch(danmakuRepositoryProvider);
  return repo.load(
    internalId: request.internalId,
    sectionId: request.sectionId,
    episodeIndex: request.episode,
    summary: request.summary,
    sources: settings.sources,
    dandanplayAppId: settings.dandanplayAppId,
    dandanplayAppSecret: settings.dandanplayAppSecret,
  );
});
