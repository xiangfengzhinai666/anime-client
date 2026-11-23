import '../../../core/network/api_client.dart';
import 'bili_wbi.dart';
import 'catalog_models.dart';

/// B 站番剧元数据。
///
/// 三个入口：
/// - `search`：wbi 签名搜索（中文最准）
/// - `index`：番剧索引（支持年份/类型/排序/分页）
/// - `detail`：季详情（分集 + cid，供 S4 弹幕使用）
class BiliCatalog {
  BiliCatalog(this._client, this._wbi);

  static const String searchUrl =
      'https://api.bilibili.com/x/web-interface/wbi/search/type';
  static const String indexUrl =
      'https://api.bilibili.com/pgc/season/index/result';
  static const String detailUrl = 'https://api.bilibili.com/pgc/view/web/season';

  final ApiClient _client;
  final BiliWbi _wbi;

  Future<CatalogPage> search(String keyword, {int page = 1, int pageSize = 20}) async {
    final params = await _wbi.sign({
      'search_type': 'media_bangumi',
      'keyword': keyword,
      'page': page,
      'page_size': pageSize,
    });

    final json = await _client.getJson(
      searchUrl,
      query: params,
      headers: BiliWbi.refererHeaders,
      tag: 'bili-search',
    );
    _ensureOk(json, 'B 站搜索');

    final data = _map(json['data']);
    final list = (data['result'] as List? ?? const []);
    final items = <AnimeSummary>[];
    for (final raw in list) {
      final item = parseSearchItem(_map(raw));
      if (item != null) items.add(item);
    }

    final pages = _int(data['numPages']) ?? 0;
    return CatalogPage(
      items: items,
      page: page,
      hasMore: pages > page || items.length >= pageSize,
    );
  }

  Future<CatalogPage> index({
    int page = 1,
    int pageSize = 24,
    int year = -1,
    int seasonType = 1,
    String order = '3',
    int area = -1,
    int isFinish = -1,
  }) async {
    final json = await _client.getJson(
      indexUrl,
      query: {
        'st': 1,
        'order': order,
        'season_version': -1,
        'spoken_language_type': -1,
        'area': area,
        'is_finish': isFinish,
        'copyright': -1,
        'season_status': -1,
        'season_month': -1,
        'year': year,
        'style_id': -1,
        'sort': 0,
        'page': page,
        'season_type': seasonType,
        'pagesize': pageSize,
        'type': 1,
      },
      headers: BiliWbi.refererHeaders,
      tag: 'bili-index',
    );
    _ensureOk(json, 'B 站索引');

    final data = _map(json['data']);
    final list = (data['list'] as List? ?? const []);
    final items = <AnimeSummary>[];
    for (final raw in list) {
      final item = parseIndexItem(_map(raw));
      if (item != null) items.add(item);
    }

    final hasNext = _bool(data['has_next']) ?? items.length >= pageSize;
    return CatalogPage(items: items, page: page, hasMore: hasNext);
  }

  Future<AnimeDetail> detail(String seasonId) async {
    final json = await _client.getJson(
      detailUrl,
      query: {'season_id': seasonId},
      headers: BiliWbi.refererHeaders,
      tag: 'bili-detail',
    );
    _ensureOk(json, 'B 站详情');

    final result = _map(json['result']);
    return parseDetail(result, seasonId);
  }

  // ---------------------------------------------------------------- 联想

  /// B 站搜索联想（模糊）：输入 "clann" 会给 "clannad"。
  ///
  /// 用公开的 suggest 接口，不需要签名：
  /// `https://s.search.bilibili.com/main/suggest?term=xxx&main_ver=v1`
  Future<List<String>> suggest(String keyword) async {
    final json = await _client.getJson(
      'https://s.search.bilibili.com/main/suggest',
      query: {'term': keyword, 'main_ver': 'v1'},
      headers: const {'Referer': 'https://www.bilibili.com/'},
      tag: 'bili-suggest',
    );

    final result = json['result'];
    if (result is! Map) return const [];
    final tags = result['tag'];
    if (tags is! List) return const [];

    final query = keyword.trim().toLowerCase();
    final out = <String>[];
    for (final raw in tags) {
      if (raw is! Map) continue;
      final value = '${raw['value'] ?? raw['term'] ?? ''}'.trim();
      if (value.isEmpty || out.contains(value)) continue;
      // 只要"以输入开头"的建议，避免"巨人"搜出"巨人网络"这种噪音
      final lower = value.toLowerCase();
      if (lower.startsWith(query) || query.startsWith(lower)) {
        out.add(value);
      }
      if (out.length >= 3) break;
    }
    return out;
  }

  // ---------------------------------------------------------------- 解析

  /// 解析搜索项（公开以便测试直接喂 fixture）。
  static AnimeSummary? parseSearchItem(Map<String, dynamic> item) {
    final seasonId = _int(item['season_id']);
    final title = _stripEm('${item['title'] ?? ''}');
    if (seasonId == null || seasonId == 0 || title.isEmpty) return null;

    final score = _double(_map(item['media_score'])['score']);
    final pubtime = _int(item['pubtime']);
    final styles = '${item['styles'] ?? ''}';
    final epSize = _int(item['ep_size']);

    return AnimeSummary(
      source: CatalogSource.bili,
      sourceId: '$seasonId',
      title: title,
      subtitle: _stripEm('${item['org_title'] ?? ''}'),
      cover: _https('${item['cover'] ?? ''}'),
      year: pubtime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(pubtime * 1000).year,
      totalEpisodes: epSize,
      score: score,
      status: '${item['index_show'] ?? ''}',
      tags: styles.isEmpty ? const [] : styles.split('/'),
      pubDate: pubtime == null ? '' : _formatDate(pubtime),
    );
  }

  static AnimeSummary? parseIndexItem(Map<String, dynamic> item) {
    final seasonId = _int(item['season_id']);
    final title = _stripEm('${item['title'] ?? ''}');
    if (seasonId == null || seasonId == 0 || title.isEmpty) return null;

    final scoreText = '${item['score'] ?? ''}';
    return AnimeSummary(
      source: CatalogSource.bili,
      sourceId: '$seasonId',
      title: title,
      subtitle: _stripEm('${item['subTitle'] ?? ''}'),
      cover: _https('${item['cover'] ?? ''}'),
      score: double.tryParse(scoreText),
      status: '${item['index_show'] ?? ''}',
      tags: const [],
    );
  }

  static AnimeDetail parseDetail(Map<String, dynamic> r, String requestedId) {
    final seasonId = '${_int(r['season_id']) ?? requestedId}';
    final rating = _map(r['rating']);
    final publish = _map(r['publish']);
    final stat = _map(r['stat']);
    final areas = (r['areas'] as List? ?? const [])
        .map((e) => '${_map(e)['name'] ?? ''}')
        .where((e) => e.isNotEmpty)
        .toList();
    final styles = (r['styles'] as List? ?? const [])
        .map((e) => '${_map(e)['name'] ?? ''}')
        .where((e) => e.isNotEmpty)
        .toList();

    final episodes = parseEpisodes(r);

    return AnimeDetail(
      summary: AnimeSummary(
        source: CatalogSource.bili,
        sourceId: seasonId,
        title: _stripEm('${r['title'] ?? ''}'),
        subtitle: _stripEm('${r['season_title'] ?? ''}'),
        cover: _https('${r['cover'] ?? ''}'),
        year: _yearOf('${publish['pub_time'] ?? ''}'),
        totalEpisodes: _int(r['total']),
        score: _double(rating['score']),
        status: _bool(r['is_finish']) == true ? '已完结' : '连载中',
        tags: styles,
        pubDate: '${publish['pub_time'] ?? ''}',
      ),
      synopsis: _stripEm('${r['evaluate'] ?? ''}'),
      episodes: episodes,
      originalTitle: '${r['jp_title'] ?? r['alias'] ?? ''}',
      areas: areas,
      viewCount: _int(stat['views']),
      followerCount: _int(stat['favorites']),
      danmakuCount: _int(stat['danmakus']),
      fetchedAt: DateTime.now(),
    );
  }

  /// 分集：去重 + 按集数排序。
  ///
  /// 实测同一季的 `episodes` 会重复下发（内地版 / 中配版各一份），
  /// 而且两边的 `ep_id` 并不相同，只有"集号 + 集标题"是一致的。
  /// 所以按「集号」去重、保留先出现的那条（通常是正片线路）。
  static List<AnimeEpisode> parseEpisodes(Map<String, dynamic> r) {
    final seen = <String>{};
    final episodes = <AnimeEpisode>[];

    for (final raw in (r['episodes'] as List? ?? const [])) {
      final ep = _map(raw);
      final cid = _int(ep['cid']) ?? 0;
      if (cid == 0) continue;

      final title = '${ep['title'] ?? ''}';
      final longTitle = '${ep['long_title'] ?? ''}';
      final index = int.tryParse(title) ?? episodes.length + 1;

      // 集号优先；非数字标题（SP/PV）用标题当 key
      final key = int.tryParse(title) != null ? 'ep:$index' : 'title:$title|$longTitle';
      if (!seen.add(key)) continue;

      final durationMs = _int(ep['duration']) ?? 0;
      episodes.add(AnimeEpisode(
        index: index,
        title: longTitle.isEmpty ? '第 $index 集' : longTitle,
        cover: _https('${ep['cover'] ?? ''}'),
        cid: cid,
        durationSeconds: durationMs ~/ 1000,
        badge: '${ep['badge'] ?? ''}',
        pubDate: _formatDate(_int(ep['pub_time']) ?? 0),
      ));
    }

    episodes.sort((a, b) => a.index.compareTo(b.index));
    return episodes;
  }

  // ---------------------------------------------------------------- 工具

  void _ensureOk(Map<String, dynamic> json, String action) {
    final code = _int(json['code']) ?? -1;
    if (code != 0) {
      throw ApiException(
        '$action失败：${json['message'] ?? '未知错误'}（code=$code）',
      );
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
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

  static bool? _bool(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return null;
  }

  /// B 站会混用 http/https 与协议相对地址，统一成 https。
  static String _https(String url) {
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http://')) return url.replaceFirst('http://', 'https://');
    return url;
  }

  /// 去掉搜索高亮的 `<em class="keyword">` 标签。
  static String _stripEm(String input) {
    if (!input.contains('<')) return input;
    return input
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .trim();
  }

  static int? _yearOf(String date) {
    if (date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  static String _formatDate(int seconds) {
    if (seconds <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
