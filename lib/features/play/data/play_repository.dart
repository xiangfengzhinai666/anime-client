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
    await _auth.ensureLoaded();
    final session = _auth.session;
    if (session == null) {
      throw AuthRequiredException('需要登录次元城才能播放');
    }

    try {
      final url = '${CycaniCatalog.base}/api/v2/sections/$sectionId/play-url';
      final headers = {
        ...CycaniCatalog.appHeaders,
        'Authorization': 'Bearer ${CycaniSession.normalizeToken(session.token)}',
      };

      Map<String, dynamic> json;
      try {
        json = await _client.getJson(url, headers: headers, tag: 'cycani-play-url');
      } on ApiException catch (e) {
        // 少数站点的 play-url 只接受 POST，GET 会 404/405
        if (e.statusCode == 404 || e.statusCode == 405) {
          json = await _client.postJson(
            url,
            body: const <String, dynamic>{},
            headers: headers,
            tag: 'cycani-play-url-post',
          );
        } else {
          rethrow;
        }
      }

      final code = json['code'];
      if (code is int && code != 0) {
        throw ApiException('取播放地址失败：${json['msg'] ?? code}');
      }
      final lines = parsePlayLines(json['data']);
      if (lines.isEmpty) {
        throw ApiException(
          '这个线路暂时没有可播放的地址（返回：${_brief(json)}）',
        );
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

/// 日志里只留一小段，避免把整包响应写进去。
String _brief(Object? json) {
  final text = '$json'.replaceAll(RegExp(r'\s+'), ' ');
  return text.length <= 160 ? text : '${text.substring(0, 160)}…';
}

/// 需要登录（或登录已失效）。
class AuthRequiredException implements Exception {
  AuthRequiredException(this.message);

  final String message;

  @override
  String toString() => message;
}
