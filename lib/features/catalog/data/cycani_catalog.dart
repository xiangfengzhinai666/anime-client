import '../../../core/network/api_client.dart';
import 'catalog_models.dart';

/// 次元城（cycani）元数据。
///
/// 定位：**中文当季新番**。B 站受版权限制、AniList 没有中文，而这里既有
/// 2026 当季的中文标题，也有"更新至第 X 集"的进度，和未来的播放源是同一套。
///
/// 接口（公开 JSON，需要三个 X-App-* 头）：
/// - `/api/index/weekday`            周表（当季连载）
/// - `/api/videos/search?q=`         中文搜索
/// - `/api/videos/{id}`              详情
/// - `/api/videos/{id}/sections`     分集
class CycaniCatalog {
  CycaniCatalog(this._client);

  static const String base = 'https://www.cycani.org';
  static const Map<String, String> appHeaders = {
    'Accept': 'application/json',
    'X-App-Name': 'cyc_web',
    'X-App-Version': 'cycweb',
    'X-Time-Zone': 'Asia/Shanghai',
    'Referer': 'https://www.cycani.org/',
  };

  final ApiClient _client;

  /// 当季周表：7 天全部拉平并去重。
  Future<List<AnimeSummary>> weekly() async {
    final json = await _client.getJson(
      '$base/api/index/weekday',
      headers: appHeaders,
      tag: 'cycani-weekday',
    );
    _ensureOk(json, '次元城周表');

    final list = (_map(json['data'])['list'] as List? ?? const []);
    final seen = <int>{};
    final items = <AnimeSummary>[];

    for (final day in list) {
      final videos = (_map(day)['videos'] as List? ?? const []);
      for (final raw in videos) {
        final item = parseSummary(_map(raw));
        if (item == null) continue;
        final id = int.tryParse(item.sourceId) ?? 0;
        if (!seen.add(id)) continue;
        items.add(item);
      }
    }
    return items;
  }

  Future<CatalogPage> search(String keyword, {int page = 1, int pageSize = 20}) async {
    final json = await _client.getJson(
      '$base/api/videos/search',
      query: {'q': keyword, 'page': page, 'page_size': pageSize},
      headers: appHeaders,
      tag: 'cycani-search',
    );
    _ensureOk(json, '次元城搜索');

    final data = _map(json['data']);
    final list = (data['list'] as List? ?? const []);
    final items = list
        .map((e) => parseSummary(_map(e)))
        .whereType<AnimeSummary>()
        .toList();

    final total = _int(_map(data['pager'])['total']) ?? items.length;
    return CatalogPage(
      items: items,
      page: page,
      hasMore: page * pageSize < total,
      source: CatalogSource.cycani,
    );
  }

  Future<AnimeDetail> detail(String videoId) async {
    final json = await _client.getJson(
      '$base/api/videos/$videoId',
      headers: appHeaders,
      tag: 'cycani-detail',
    );
    _ensureOk(json, '次元城详情');

    final data = _map(json['data']);
    final summary = parseSummary(data) ??
        AnimeSummary(
          source: CatalogSource.cycani,
          sourceId: videoId,
          title: '未知番剧',
        );

    final episodes = await _episodes(videoId, data);

    return AnimeDetail(
      summary: summary,
      synopsis: '${data['description'] ?? ''}',
      episodes: episodes,
      originalTitle: '${data['english_title'] ?? ''}',
      areas: [
        if ('${data['area'] ?? ''}'.isNotEmpty) '${data['area']}',
      ],
      followerCount: _int(data['hits']),
      fetchedAt: DateTime.now(),
    );
  }

  /// 分集：优先用详情里的 `play_from[0].code` 拉完整列表。
  Future<List<AnimeEpisode>> _episodes(
    String videoId,
    Map<String, dynamic> data,
  ) async {
    final playFrom = (data['play_from'] as List? ?? const []);
    String? playerCode;
    for (final raw in playFrom) {
      final code = '${_map(raw)['code'] ?? ''}';
      if (code.isNotEmpty) {
        playerCode = code;
        break;
      }
    }

    final episodes = <AnimeEpisode>[];
    if (playerCode != null) {
      try {
        final json = await _client.getJson(
          '$base/api/videos/$videoId/sections',
          query: {'player_code': playerCode, 'page': 1, 'page_size': 100},
          headers: appHeaders,
          tag: 'cycani-sections',
        );
        _ensureOk(json, '次元城分集');
        final raw = _map(json['data']);
        final sections = raw['list'] is List ? raw['list'] : raw['items'];
        for (final s in (sections as List? ?? const [])) {
          final ep = _map(s);
          final title = '${ep['title'] ?? ''}';
          final index = _indexFromTitle(title, episodes.length + 1);
          episodes.add(AnimeEpisode(
            index: index,
            title: title.isEmpty ? '第 $index 集' : title,
            sectionId: '${ep['id'] ?? ''}',
          ));
        }
      } catch (_) {
        // 分集失败不影响详情主体
      }
    }

    // 详情里自带 sections 时作为兜底
    if (episodes.isEmpty) {
      final inline = (data['sections'] as List? ?? const []);
      for (final s in inline) {
        final ep = _map(s);
        final title = '${ep['title'] ?? ''}';
        final index = _indexFromTitle(title, episodes.length + 1);
        episodes.add(AnimeEpisode(
          index: index,
          title: title,
          sectionId: '${ep['id'] ?? ''}',
        ));
      }
    }

    episodes.sort((a, b) => a.index.compareTo(b.index));
    return episodes;
  }

  // ---------------------------------------------------------------- 解析

  /// 解析列表项（公开以便测试）。
  static AnimeSummary? parseSummary(Map<String, dynamic> raw) {
    final id = _int(raw['video_id']) ?? _int(raw['id']);
    final title = '${raw['title'] ?? ''}'.trim();
    if (id == null || id == 0 || title.isEmpty) return null;

    final tags = <String>[
      ...?(raw['tags'] as List?)?.map((e) => '$e'),
      ...?(raw['categories'] as List?)?.map((e) => '$e'),
    ];

    return AnimeSummary(
      source: CatalogSource.cycani,
      sourceId: '$id',
      title: title,
      subtitle: '${raw['english_title'] ?? ''}',
      cover: _https('${raw['cover_url'] ?? ''}'),
      year: _int(raw['year']),
      totalEpisodes: _int(raw['total']),
      score: _double(raw['score']),
      status: _prettyRemarks('${raw['remarks'] ?? ''}'),
      tags: tags.take(8).toList(),
    );
  }

  // ---------------------------------------------------------------- 工具

  void _ensureOk(Map<String, dynamic> json, String action) {
    final code = _int(json['code']) ?? -1;
    if (code != 0) {
      throw ApiException('$action失败：${json['msg'] ?? json['message'] ?? '未知错误'}');
    }
  }

  /// "第12集" / "12" → 12；解析不出就用兜底序号。
  static int _indexFromTitle(String title, int fallback) {
    final match = RegExp(r'(\d+)').firstMatch(title);
    if (match == null) return fallback;
    return int.tryParse(match.group(1)!) ?? fallback;
  }

  static Map<String, dynamic> _map(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return const {};
  }

  static int? _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _double(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static String _https(String url) {
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http://')) return url.replaceFirst('http://', 'https://');
    return url;
  }

  /// 把周表里的 `08|周六23:05后` 洗成 `周六 23:05 更新`，
  /// 其它形式（更新至第 8 集 / 全 12 话）原样返回。
  static String _prettyRemarks(String remarks) {
    final text = remarks.trim();
    if (text.isEmpty) return '';
    final m = RegExp(r'^\d+\|周(.)(\d{1,2}):(\d{2})').firstMatch(text);
    if (m != null) {
      final weekday = m.group(1)!;
      final hour = m.group(2)!.padLeft(2, '0');
      final minute = m.group(3)!;
      return '周$weekday $hour:$minute 更新';
    }
    return text;
  }

  /// 已更新集数。
  ///
  /// 周表项只有"总集数"，没有"更新到第几集"。这里用 sections 接口的
  /// `pager.total`（页大小设 1）拿数量，一次轻请求即可。
  Future<int?> episodeProgress(String videoId, {String playerCode = 'cychub'}) async {
    try {
      final json = await _client.getJson(
        '$base/api/videos/$videoId/sections',
        query: {'player_code': playerCode, 'page': 1, 'page_size': 1},
        headers: appHeaders,
        tag: 'cycani-progress',
      );
      final data = _map(json['data']);
      final pager = _map(data['pager']);
      final total = _int(pager['total']);
      if (total != null && total > 0) return total;
      final list = data['list'];
      if (list is List && list.isNotEmpty) return list.length;
    } catch (_) {
      // 拿不到就算了，卡片退化为显示"总集数"
    }
    return null;
  }
}
