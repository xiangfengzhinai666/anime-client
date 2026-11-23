import 'package:flutter/foundation.dart';

/// 元数据来源。
enum CatalogSource {
  bili('bili', 'B站'),
  anilist('anilist', 'AniList');

  const CatalogSource(this.key, this.label);

  final String key;
  final String label;

  static CatalogSource parse(String? value) {
    return CatalogSource.values.firstWhere(
      (e) => e.key == value,
      orElse: () => CatalogSource.bili,
    );
  }
}

/// 列表页用的番剧摘要。
@immutable
class AnimeSummary {
  const AnimeSummary({
    required this.source,
    required this.sourceId,
    required this.title,
    this.subtitle = '',
    this.cover = '',
    this.year,
    this.totalEpisodes,
    this.score,
    this.status = '',
    this.tags = const [],
    this.pubDate = '',
  });

  final CatalogSource source;
  final String sourceId;
  final String title;
  final String subtitle;
  final String cover;
  final int? year;
  final int? totalEpisodes;
  final double? score;
  final String status;
  final List<String> tags;
  final String pubDate;

  /// 跨源唯一 ID：`bili:46089` / `anilist:154587`。
  String get id => '${source.key}:$sourceId';

  Map<String, dynamic> toJson() => {
        'source': source.key,
        'sourceId': sourceId,
        'title': title,
        'subtitle': subtitle,
        'cover': cover,
        'year': year,
        'totalEpisodes': totalEpisodes,
        'score': score,
        'status': status,
        'tags': tags,
        'pubDate': pubDate,
      };

  factory AnimeSummary.fromJson(Map<String, dynamic> json) => AnimeSummary(
        source: CatalogSource.parse(json['source'] as String?),
        sourceId: '${json['sourceId']}',
        title: '${json['title'] ?? ''}',
        subtitle: '${json['subtitle'] ?? ''}',
        cover: '${json['cover'] ?? ''}',
        year: json['year'] as int?,
        totalEpisodes: json['totalEpisodes'] as int?,
        score: (json['score'] as num?)?.toDouble(),
        status: '${json['status'] ?? ''}',
        tags: (json['tags'] as List?)?.map((e) => '$e').toList() ?? const [],
        pubDate: '${json['pubDate'] ?? ''}',
      );
}

/// 一集。
@immutable
class AnimeEpisode {
  const AnimeEpisode({
    required this.index,
    required this.title,
    this.cover = '',
    this.cid = 0,
    this.durationSeconds = 0,
    this.badge = '',
  });

  final int index;
  final String title;
  final String cover;

  /// B 站弹幕锚点（S4 用）。
  final int cid;
  final int durationSeconds;
  final String badge;

  Map<String, dynamic> toJson() => {
        'index': index,
        'title': title,
        'cover': cover,
        'cid': cid,
        'duration': durationSeconds,
        'badge': badge,
      };

  factory AnimeEpisode.fromJson(Map<String, dynamic> json) => AnimeEpisode(
        index: json['index'] as int? ?? 0,
        title: '${json['title'] ?? ''}',
        cover: '${json['cover'] ?? ''}',
        cid: json['cid'] as int? ?? 0,
        durationSeconds: json['duration'] as int? ?? 0,
        badge: '${json['badge'] ?? ''}',
      );
}

/// 角色（目前只有 AniList 提供）。
@immutable
class AnimeCharacter {
  const AnimeCharacter({
    required this.name,
    this.image = '',
    this.role = '',
    this.voice = '',
  });

  final String name;
  final String image;
  final String role;
  final String voice;

  Map<String, dynamic> toJson() =>
      {'name': name, 'image': image, 'role': role, 'voice': voice};

  factory AnimeCharacter.fromJson(Map<String, dynamic> json) => AnimeCharacter(
        name: '${json['name'] ?? ''}',
        image: '${json['image'] ?? ''}',
        role: '${json['role'] ?? ''}',
        voice: '${json['voice'] ?? ''}',
      );
}

/// 详情页用的完整信息。
@immutable
class AnimeDetail {
  const AnimeDetail({
    required this.summary,
    this.synopsis = '',
    this.episodes = const [],
    this.originalTitle = '',
    this.areas = const [],
    this.characters = const [],
    this.viewCount,
    this.followerCount,
    this.danmakuCount,
    this.fetchedAt,
  });

  final AnimeSummary summary;
  final String synopsis;
  final List<AnimeEpisode> episodes;
  final String originalTitle;
  final List<String> areas;
  final List<AnimeCharacter> characters;
  final int? viewCount;
  final int? followerCount;
  final int? danmakuCount;
  final DateTime? fetchedAt;

  Map<String, dynamic> toJson() => {
        'summary': summary.toJson(),
        'synopsis': synopsis,
        'episodes': episodes.map((e) => e.toJson()).toList(),
        'originalTitle': originalTitle,
        'areas': areas,
        'characters': characters.map((e) => e.toJson()).toList(),
        'viewCount': viewCount,
        'followerCount': followerCount,
        'danmakuCount': danmakuCount,
        'fetchedAt': fetchedAt?.toIso8601String(),
      };

  factory AnimeDetail.fromJson(Map<String, dynamic> json) => AnimeDetail(
        summary: AnimeSummary.fromJson(
            (json['summary'] as Map).cast<String, dynamic>()),
        synopsis: '${json['synopsis'] ?? ''}',
        episodes: (json['episodes'] as List? ?? const [])
            .map((e) => AnimeEpisode.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        originalTitle: '${json['originalTitle'] ?? ''}',
        areas: (json['areas'] as List?)?.map((e) => '$e').toList() ?? const [],
        characters: (json['characters'] as List? ?? const [])
            .map((e) =>
                AnimeCharacter.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        viewCount: json['viewCount'] as int?,
        followerCount: json['followerCount'] as int?,
        danmakuCount: json['danmakuCount'] as int?,
        fetchedAt: json['fetchedAt'] == null
            ? null
            : DateTime.tryParse('${json['fetchedAt']}'),
      );
}

/// 搜索/索引的一页结果。
@immutable
class CatalogPage {
  const CatalogPage({
    required this.items,
    required this.page,
    required this.hasMore,
    this.source = CatalogSource.bili,
  });

  final List<AnimeSummary> items;
  final int page;
  final bool hasMore;
  final CatalogSource source;
}

/// 文本工具：跨源匹配、去重。
class TitleMatcher {
  TitleMatcher._();

  static final RegExp _noise =
      RegExp(r'''[\s\-_:：·・,，.。!！?？~～「」『』()（）\[\]【】'"\u2018\u2019\u201C\u201D]''');

  /// 归一化：去掉标点/空格，全角转半角，小写。
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      var code = rune;
      // 全角 ASCII（！到 ～）转半角
      if (code >= 0xFF01 && code <= 0xFF5E) code -= 0xFEE0;
      if (code == 0x3000) code = 0x20; // 全角空格
      buffer.writeCharCode(code);
    }
    return buffer.toString().replaceAll(_noise, '').toLowerCase();
  }

  /// 粗略判断两条记录是否是同一部番。
  ///
  /// 规则保守：标题归一化后相等，或一方包含另一方且集数一致；
  /// 年份都已知时要求相差不超过 1 年。宁可多显示一条，也不错误合并。
  static bool sameShow({
    required String titleA,
    String? titleB,
    int? yearA,
    int? yearB,
    int? episodesA,
    int? episodesB,
  }) {
    final a = normalize(titleA);
    final b = normalize(titleB ?? '');
    if (a.isEmpty || b.isEmpty) return false;

    final equal = a == b;
    final contains = a.contains(b) || b.contains(a);
    if (!equal && !contains) return false;

    final yearGap =
        (yearA != null && yearB != null) ? (yearA - yearB).abs() : 0;
    if (yearGap > 1) return false;

    final bothEpisodes = episodesA != null && episodesB != null;
    if (bothEpisodes && episodesA != episodesB) {
      // 相邻年份 + 集数不同 → 大概率是不同 Part（例：无职转生 II 与 II Part 2）
      if (yearGap == 1) return false;
      // 只有「标题完全一致」才容忍集数口径差异（B 站常把 SP 算进总数）；
      // 标题只是包含关系（如「某番 剧场版」）时，集数不同就是不同作品。
      return equal;
    }
    return true;
  }

  /// 编辑距离（Levenshtein）。只用于标题近似比较，字符串很短（<40）。
  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final del = prev[j] + 1;
        final ins = curr[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        curr[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }

  /// 标题近似相等。
  ///
  /// 用来兜住「同一部番，一处简体一处繁体」的情况：
  /// B 站给「葬送的芙莉莲」，AniList 的别名是「葬送的芙莉蓮」——
  /// 归一化后仍差一个字，靠编辑距离判定为同一部。
  static bool similar(String a, String b, {int maxDistance = 1}) {
    final na = normalize(a);
    final nb = normalize(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    if ((na.length - nb.length).abs() > maxDistance) return false;
    return levenshtein(na, nb) <= maxDistance;
  }
}
