import 'dart:convert';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/security/token_vault.dart';
import '../../catalog/data/cycani_catalog.dart';

/// 次元城登录态。
class CycaniSession {
  const CycaniSession({
    required this.token,
    required this.username,
    this.nickname = '',
    this.expiresAt,
  });

  final String token;
  final String username;
  final String nickname;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() => {
        'token': token,
        'username': username,
        'nickname': nickname,
        'expires_at': expiresAt?.toIso8601String(),
      };

  static CycaniSession? fromJson(Map<String, dynamic> json) {
    final token = '${json['token'] ?? ''}';
    if (token.isEmpty) return null;
    final raw = json['expires_at'];
    return CycaniSession(
      token: token,
      username: '${json['username'] ?? ''}',
      nickname: '${json['nickname'] ?? ''}',
      expiresAt: raw is String ? DateTime.tryParse(raw) : null,
    );
  }
}

/// 次元城账号服务：登录、续期、退出。
///
/// 登录态只存本机（Windows 凭据管理器），不上传、不共享。
class CycaniAuth {
  CycaniAuth(this._client, this._vault, this._logger);

  static const String _vaultKey = 'cycani-session';

  final ApiClient _client;
  final TokenVault _vault;
  final AppLogger _logger;

  CycaniSession? _session;
  CycaniSession? get session => _session;
  bool get isLoggedIn => _session != null;

  /// 启动时恢复上次登录。
  Future<CycaniSession?> restore() async {
    final raw = await _vault.read(_vaultKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final session = CycaniSession.fromJson(json);
      if (session == null) return null;
      if (session.isExpired) {
        final refreshed = await _refresh(session);
        if (refreshed == null) {
          await _vault.delete(_vaultKey);
          return null;
        }
        _session = refreshed;
      } else {
        _session = session;
      }
      return _session;
    } catch (e) {
      _logger.warn('auth', '恢复登录态失败：$e');
      return null;
    }
  }

  /// 用户名 + 密码登录。
  Future<CycaniSession> login(String username, String password) async {
    final json = await _client.postJson(
      '${CycaniCatalog.base}/api/auth/login',
      body: {'username': username, 'password': password},
      headers: CycaniCatalog.appHeaders,
      tag: 'cycani-login',
    );

    final data = _asMap(json['data'] ?? json);
    final token = '${data['token'] ?? ''}';
    if (token.isEmpty) {
      throw ApiException('登录失败：${json['msg'] ?? '没有返回 token'}');
    }
    final user = _asMap(data['user']);
    final session = CycaniSession(
      token: token,
      username: '${user['username'] ?? username}',
      nickname: '${user['nickname'] ?? ''}',
      expiresAt: _parseDate(data['expires_at']),
    );

    _session = session;
    await _vault.write(_vaultKey, jsonEncode(session.toJson()));
    _logger.info('auth', '次元城登录成功：${session.username}');
    return session;
  }

  /// 用现有 token 续期（401 时调用）。
  Future<CycaniSession?> refresh() async {
    final current = _session;
    if (current == null) return null;
    final refreshed = await _refresh(current);
    if (refreshed != null) {
      _session = refreshed;
      await _vault.write(
        _vaultKey,
        jsonEncode(refreshed.toJson()),
      );
    } else {
      await logout();
    }
    return refreshed;
  }

  Future<CycaniSession?> _refresh(CycaniSession current) async {
    try {
      final json = await _client.postJson(
        '${CycaniCatalog.base}/api/auth/refresh',
        headers: {
          ...CycaniCatalog.appHeaders,
          'Authorization': 'Bearer ${current.token}',
        },
        tag: 'cycani-refresh',
      );
      final data = _asMap(json['data'] ?? json);
      final token = '${data['token'] ?? ''}';
      if (token.isEmpty) return null;
      return CycaniSession(
        token: token,
        username: current.username,
        nickname: current.nickname,
        expiresAt: _parseDate(data['expires_at']) ??
            DateTime.now().add(const Duration(days: 7)),
      );
    } catch (e) {
      _logger.warn('auth', '续期失败：$e');
      return null;
    }
  }

  Future<void> logout() async {
    _session = null;
    await _vault.delete(_vaultKey);
  }

  static Map<String, dynamic> _asMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return const {};
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) {
      // 秒级时间戳
      return DateTime.fromMillisecondsSinceEpoch(
        raw > 1000000000000 ? raw : raw * 1000,
      );
    }
    return null;
  }
}
