import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_providers.dart';
import '../../core/security/token_vault.dart';
import '../catalog/catalog_providers.dart';
import '../catalog/data/catalog_models.dart';
import 'data/cycani_auth.dart';
import 'data/play_models.dart';
import 'data/play_repository.dart';

/// 登录态仓库（Windows 凭据管理器），测试里可覆盖。
final tokenVaultProvider = Provider<TokenVault>((ref) => const TokenVault());

final cycaniAuthProvider = Provider<CycaniAuth>((ref) {
  return CycaniAuth(
    ref.watch(apiClientProvider),
    ref.watch(tokenVaultProvider),
    ref.watch(appLoggerProvider),
  );
});

/// 当前登录态：null = 未登录。
class CycaniSessionNotifier extends StateNotifier<CycaniSession?> {
  CycaniSessionNotifier(this._auth) : super(null) {
    _restore();
  }

  final CycaniAuth _auth;

  Future<void> _restore() async {
    final restored = await _auth.restore();
    if (mounted) state = restored;
  }

  Future<void> login(String username, String password) async {
    state = await _auth.login(username, password);
  }

  Future<void> logout() async {
    await _auth.logout();
    state = null;
  }
}

final cycaniSessionProvider =
    StateNotifierProvider<CycaniSessionNotifier, CycaniSession?>((ref) {
  return CycaniSessionNotifier(ref.watch(cycaniAuthProvider));
});

final playRepositoryProvider = Provider<PlayRepository>((ref) {
  return PlayRepository(
    ref.watch(apiClientProvider),
    ref.watch(cycaniAuthProvider),
  );
});

/// 某集的全部线路。
final playLinesProvider =
    FutureProvider.family<List<PlayLine>, String>((ref, sectionId) {
  return ref.watch(playRepositoryProvider).linesForSection(sectionId);
});

/// 某番剧的续播位置（只取同集进度）。
final resumePositionProvider =
    FutureProvider.family<int, ({String internalId, int episode})>(
        (ref, args) async {
  final dao = ref.watch(historyDaoProvider);
  final recent = await dao.recent(limit: 50);
  final bangumiId = int.tryParse(args.internalId.split(':').last);
  if (bangumiId == null) return 0;
  for (final item in recent) {
    if (item.bangumiId == bangumiId && item.episode == args.episode) {
      return item.positionSeconds;
    }
  }
  return 0;
});

/// 保存进度。
final saveProgressProvider = Provider<void Function({
  required AnimeSummary? summary,
  required int episode,
  required int positionSeconds,
  required int durationSeconds,
  required String episodeTitle,
})>((ref) {
  final dao = ref.watch(historyDaoProvider);
  final logger = ref.watch(appLoggerProvider);
  return ({
    required AnimeSummary? summary,
    required int episode,
    required int positionSeconds,
    required int durationSeconds,
    required String episodeTitle,
  }) async {
    final resolved = summary;
    if (resolved == null) return;
    final id = int.tryParse(resolved.sourceId);
    if (id == null || positionSeconds <= 0) return;
    try {
      await dao.saveProgress(
        bangumiId: id,
        episode: episode,
        positionSeconds: positionSeconds,
        durationSeconds: durationSeconds,
        title: resolved.title,
        episodeTitle: episodeTitle,
        cover: resolved.cover,
        source: resolved.source.key,
      );
    } catch (e) {
      logger.warn('play', '保存播放进度失败：$e');
    }
  };
});

/// 本地文件播放（拖进来/选文件），与在线源共用播放页。
final localFileProvider = StateProvider<String?>((ref) => null);

/// 登录用户展示名。
String sessionLabel(CycaniSession? session) {
  if (session == null) return '未登录';
  final nick = session.nickname.trim();
  return nick.isEmpty ? session.username : nick;
}

/// 便于测试与调试：当前源。
const CatalogSource playSource = CatalogSource.cycani;

/// 播放偏好：自动连播下一集（默认开）。
///
/// 存在 settings 表（key: play.autoNext），重启后保持。
class AutoNextNotifier extends StateNotifier<bool> {
  AutoNextNotifier(this._ref) : super(true) {
    _load();
  }

  final Ref _ref;
  static const String _key = 'play.autoNext';

  Future<void> _load() async {
    try {
      final raw = await _ref.read(settingsDaoProvider).get(_key);
      if (raw != null && mounted) state = raw == 'true';
    } catch (_) {
      // 读失败就用默认值
    }
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      await _ref.read(settingsDaoProvider).set(_key, value.toString());
    } catch (_) {
      // 写失败不影响本次会话
    }
  }
}

final autoPlayNextProvider =
    StateNotifierProvider<AutoNextNotifier, bool>((ref) {
  return AutoNextNotifier(ref);
});
