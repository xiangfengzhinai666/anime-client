import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import 'data/danmaku_models.dart';

/// 弹幕设置（持久化在 settings 表）。
class DanmakuSettings {
  const DanmakuSettings({
    this.enabled = true,
    this.followSpeed = true,
    this.sources = const {
      DanmakuSource.server,
      DanmakuSource.bilibili,
    },
    this.opacity = 0.85,
    this.fontSize = 22,
    this.speedFactor = 1.0,
    this.maxOnScreen = 80,
    this.blockedWords = const [],
    this.dandanplayAppId = '',
    this.dandanplayAppSecret = '',
  });

  final bool enabled;

  /// 弹幕滚动速度跟随播放倍速。
  final bool followSpeed;
  final Set<DanmakuSource> sources;
  final double opacity;
  final double fontSize;
  final double speedFactor;
  final int maxOnScreen;
  final List<String> blockedWords;
  final String dandanplayAppId;
  final String dandanplayAppSecret;

  DanmakuSettings copyWith({
    bool? enabled,
    bool? followSpeed,
    Set<DanmakuSource>? sources,
    double? opacity,
    double? fontSize,
    double? speedFactor,
    int? maxOnScreen,
    List<String>? blockedWords,
    String? dandanplayAppId,
    String? dandanplayAppSecret,
  }) {
    return DanmakuSettings(
      enabled: enabled ?? this.enabled,
      followSpeed: followSpeed ?? this.followSpeed,
      sources: sources ?? this.sources,
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      speedFactor: speedFactor ?? this.speedFactor,
      maxOnScreen: maxOnScreen ?? this.maxOnScreen,
      blockedWords: blockedWords ?? this.blockedWords,
      dandanplayAppId: dandanplayAppId ?? this.dandanplayAppId,
      dandanplayAppSecret: dandanplayAppSecret ?? this.dandanplayAppSecret,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'followSpeed': followSpeed,
        'sources': sources.map((e) => e.id).toList(),
        'opacity': opacity,
        'fontSize': fontSize,
        'speedFactor': speedFactor,
        'maxOnScreen': maxOnScreen,
        'blockedWords': blockedWords,
        'dandanplayAppId': dandanplayAppId,
        'dandanplayAppSecret': dandanplayAppSecret,
      };

  static DanmakuSettings fromJson(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final sources = <DanmakuSource>{};
      final rawSources = json['sources'];
      if (rawSources is List) {
        for (final id in rawSources) {
          final source = DanmakuSource.parse('$id');
          if (source != null) sources.add(source);
        }
      }
      return DanmakuSettings(
        enabled: json['enabled'] as bool? ?? true,
        followSpeed: json['followSpeed'] as bool? ?? true,
        sources: sources.isEmpty
            ? const {DanmakuSource.server, DanmakuSource.bilibili}
            : sources,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 0.85,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 22,
        speedFactor: (json['speedFactor'] as num?)?.toDouble() ?? 1.0,
        maxOnScreen: (json['maxOnScreen'] as num?)?.toInt() ?? 80,
        blockedWords: (json['blockedWords'] as List?)
                ?.map((e) => '$e')
                .where((e) => e.trim().isNotEmpty)
                .toList() ??
            const [],
        dandanplayAppId: '${json['dandanplayAppId'] ?? ''}',
        dandanplayAppSecret: '${json['dandanplayAppSecret'] ?? ''}',
      );
    } catch (_) {
      return const DanmakuSettings();
    }
  }

  /// 屏蔽词 → 正则。
  RegExp? get blockedPattern {
    final words = blockedWords.where((e) => e.trim().isNotEmpty).toList();
    if (words.isEmpty) return null;
    return RegExp(words.map(RegExp.escape).join('|'));
  }
}

const String _settingsKey = 'danmaku.settings';

class DanmakuSettingsNotifier extends StateNotifier<DanmakuSettings> {
  DanmakuSettingsNotifier(this._ref) : super(const DanmakuSettings()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    try {
      final raw = await _ref.read(settingsDaoProvider).get(_settingsKey);
      if (raw != null && raw.isNotEmpty && mounted) {
        state = DanmakuSettings.fromJson(raw);
      }
    } catch (e) {
      _ref.read(appLoggerProvider).warn('danmaku', '读取弹幕设置失败：$e');
    }
  }

  Future<void> _persist(DanmakuSettings next) async {
    state = next;
    try {
      await _ref.read(settingsDaoProvider).set(_settingsKey, jsonEncode(next.toJson()));
    } catch (e) {
      _ref.read(appLoggerProvider).warn('danmaku', '保存弹幕设置失败：$e');
    }
  }

  Future<void> toggleEnabled() =>
      _persist(state.copyWith(enabled: !state.enabled));

  Future<void> setEnabled(bool value) =>
      _persist(state.copyWith(enabled: value));

  Future<void> setFollowSpeed(bool value) =>
      _persist(state.copyWith(followSpeed: value));

  Future<void> setSource(DanmakuSource source, bool enabled) {
    final next = Set<DanmakuSource>.from(state.sources);
    if (enabled) {
      next.add(source);
    } else {
      next.remove(source);
    }
    if (next.isEmpty) next.add(DanmakuSource.server);
    return _persist(state.copyWith(sources: next));
  }

  Future<void> setOpacity(double value) =>
      _persist(state.copyWith(opacity: value.clamp(0.2, 1.0)));

  Future<void> setFontSize(double value) =>
      _persist(state.copyWith(fontSize: value.clamp(14, 40)));

  Future<void> setSpeedFactor(double value) =>
      _persist(state.copyWith(speedFactor: value.clamp(0.5, 2.0)));

  Future<void> setMaxOnScreen(int value) =>
      _persist(state.copyWith(maxOnScreen: value.clamp(20, 200)));

  Future<void> setBlockedWords(String raw) {
    final words = raw
        .split(RegExp(r'[\n,，;；]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return _persist(state.copyWith(blockedWords: words));
  }

  Future<void> setDandanplay(String appId, String appSecret) => _persist(
        state.copyWith(
          dandanplayAppId: appId.trim(),
          dandanplayAppSecret: appSecret.trim(),
        ),
      );
}

final danmakuSettingsProvider =
    StateNotifierProvider<DanmakuSettingsNotifier, DanmakuSettings>((ref) {
  return DanmakuSettingsNotifier(ref);
});
