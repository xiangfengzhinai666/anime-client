import 'dart:convert';

import '../../../core/network/api_client.dart';
import 'catalog_models.dart';

/// AniList（GraphQL）元数据。
///
/// 定位：全球番剧库，补 B 站没有的番；中文标题通常只在 `synonyms` 里，
/// 所以这里会把含中日韩字符的别名提出来当作展示标题。
class AniListCatalog {
  AniListCatalog(this._client);

  static const String endpoint = 'https://graphql.anilist.co';

  final ApiClient _client;

  Future<CatalogPage> search(String keyword, {int page = 1, int perPage = 20}) async {
    const query = r'''
query ($search: String, $page: Int, $perPage: Int) {
  Page(page: $page, perPage: $perPage) {
    pageInfo { hasNextPage }
    media(search: $search, type: ANIME, sort: SEARCH_MATCH) {
      id
      title { romaji native english }
      synonyms
      episodes
      startDate { year }
      coverImage { large }
      averageScore
      genres
      status
      description
    }
  }
}''';

    final json = await _client.postJson(
      endpoint,
      body: jsonEncode({
        'query': query,
        'variables': {'search': keyword, 'page': page, 'perPage': perPage},
      }),
      headers: {'Content-Type': 'application/json'},
      tag: 'anilist-search',
    );

    final data = _map(json['data']);
    final pageData = _map(data['Page']);
    final media = (pageData['media'] as List? ?? const []);
    final items = media
        .map((e) => parseSummary(_map(e)))
        .whereType<AnimeSummary>()
        .toList();

    final info = _map(pageData['pageInfo']);
    return CatalogPage(
      items: items,
      page: page,
      hasMore: info['hasNextPage'] == true,
      source: CatalogSource.anilist,
    );
  }

  Future<AnimeDetail> detail(String id) async {
    const query = r'''
query ($id: Int) {
  Media(id: $id, type: ANIME) {
    id
    title { romaji native english }
    synonyms
    description
    episodes
    duration
    startDate { year month day }
    coverImage { large }
    averageScore
    genres
    status
    popularity
    characters(sort: [ROLE, RELEVANCE, ID], perPage: 12) {
      edges {
        role
        node { name { full } image { large } }
      }
    }
  }
}''';

    final json = await _client.postJson(
      endpoint,
      body: jsonEncode({
        'query': query,
        'variables': {'id': int.tryParse(id) ?? 0},
      }),
      headers: {'Content-Type': 'application/json'},
      tag: 'anilist-detail',
    );

    final media = _map(_map(json['data'])['Media']);
    if (media.isEmpty) {
      throw ApiException('AniList 未找到该条目（id=$id）');
    }
    return parseDetail(media);
  }

  // ---------------------------------------------------------------- 解析

  /// 解析列表项（公开以便测试）。
  static AnimeSummary? parseSummary(Map<String, dynamic> m) {
    final id = m['id'];
    if (id is! int) return null;

    final titles = _map(m['title']);
    final zh = _zhTitle(m['synonyms']);
    final romaji = '${titles['romaji'] ?? ''}';
    final native = '${titles['native'] ?? ''}';

    final title = zh.isNotEmpty ? zh : (romaji.isNotEmpty ? romaji : native);
    if (title.isEmpty) return null;

    final start = _map(m['startDate']);
    return AnimeSummary(
      source: CatalogSource.anilist,
      sourceId: '$id',
      title: title,
      subtitle: zh.isNotEmpty ? romaji : native,
      cover: '${_map(m['coverImage'])['large'] ?? ''}',
      year: start['year'] as int?,
      totalEpisodes: m['episodes'] as int?,
      score: _score(m['averageScore']),
      status: _status(m['status']),
      tags: (m['genres'] as List?)?.map((e) => '$e').toList() ?? const [],
    );
  }

  static AnimeDetail parseDetail(Map<String, dynamic> m) {
    final summary = parseSummary(m)!;
    final characters = <AnimeCharacter>[];
    for (final edge in (_map(m['characters'])['edges'] as List? ?? const [])) {
      final e = _map(edge);
      final node = _map(e['node']);
      final name = '${_map(node['name'])['full'] ?? ''}';
      if (name.isEmpty) continue;
      characters.add(AnimeCharacter(
        name: name,
        image: '${_map(node['image'])['large'] ?? ''}',
        role: '${e['role'] ?? ''}',
      ));
    }

    return AnimeDetail(
      summary: summary,
      synopsis: _plainText('${m['description'] ?? ''}'),
      originalTitle: '${_map(m['title'])['native'] ?? ''}',
      characters: characters,
      episodes: [
        // AniList 不提供分集列表，只有总集数；这里只给出占位集数，不伪造标题
        for (var i = 1; i <= (summary.totalEpisodes ?? 0); i++)
          AnimeEpisode(index: i, title: '第 $i 集'),
      ],
      followerCount: m['popularity'] as int?,
      fetchedAt: DateTime.now(),
    );
  }

  static Map<String, dynamic> _map(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return const {};
  }

  /// 从别名里挑一个含中日韩字符的标题（通常是官方中文名）。
  static String _zhTitle(Object? synonyms) {
    if (synonyms is! List) return '';
    final cjk = RegExp(r'[\u4e00-\u9fff\u3040-\u30ff]');
    for (final value in synonyms) {
      final text = '$value'.trim();
      if (text.isNotEmpty && cjk.hasMatch(text)) return text;
    }
    return '';
  }

  static double? _score(Object? v) {
    if (v is! num) return null;
    return (v.toDouble() / 10).clamp(0, 10);
  }

  static String _status(Object? v) {
    switch ('$v') {
      case 'FINISHED':
        return '已完结';
      case 'RELEASING':
        return '连载中';
      case 'NOT_YET_RELEASED':
        return '未播出';
      case 'CANCELLED':
        return '已取消';
      case 'HIATUS':
        return '停更';
      default:
        return '';
    }
  }

  /// AniList 的简介是 HTML 片段。
  static String _plainText(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .trim();
  }
}
