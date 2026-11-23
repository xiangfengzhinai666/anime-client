import '../../../core/network/api_client.dart';
import '../../catalog/data/cycani_catalog.dart';
import 'cycani_auth.dart';
import 'play_models.dart';

/// 播放地址解析。
///
/// 次元城的播放地址要登录后才给，且 token 会过期：
/// 遇到 401 自动续期一次，续期失败抛 [AuthRequiredException] 由界面引导重新登录。
class PlayRepository {
  PlayRepository(this._client, this._auth);

  final ApiClient _client;
  final CycaniAuth _auth;

  Future<List<PlayLine>> linesForSection(String sectionId) async {
    final first = await _request(sectionId, allowRetry: true);
    return first;
  }

  Future<List<PlayLine>> _request(
    String sectionId, {
    required bool allowRetry,
  }) async {
    final session = _auth.session;
    if (session == null) {
      throw AuthRequiredException('需要登录次元城才能播放');
    }

    try {
      final json = await _client.getJson(
        '${CycaniCatalog.base}/api/v2/sections/$sectionId/play-url',
        headers: {
          ...CycaniCatalog.appHeaders,
          'Authorization': 'Bearer ${session.token}',
        },
        tag: 'cycani-play-url',
      );

      final code = json['code'];
      if (code is int && code != 0) {
        throw ApiException('取播放地址失败：${json['msg'] ?? code}');
      }
      final lines = parsePlayLines(json['data']);
      if (lines.isEmpty) {
        throw ApiException('这个线路暂时没有可播放的地址');
      }
      return lines;
    } on ApiException catch (e) {
      if (e.statusCode == 401 && allowRetry) {
        final refreshed = await _auth.refresh();
        if (refreshed != null) {
          return _request(sectionId, allowRetry: false);
        }
        throw AuthRequiredException('登录已过期，请重新登录次元城');
      }
      rethrow;
    }
  }
}

/// 需要登录（或登录已失效）。
class AuthRequiredException implements Exception {
  AuthRequiredException(this.message);

  final String message;

  @override
  String toString() => message;
}
