import 'package:anime_client/features/catalog/data/anilist_catalog.dart';
import 'package:anime_client/features/catalog/data/bili_catalog.dart';
import 'package:anime_client/features/catalog/data/catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用真实接口返回的字段结构做 fixture（已裁剪），校验解析层的容错。
void main() {
  group('B 站详情解析', () {
    final Map<String, dynamic> fixture = {
      'season_id': 46089,
      'title': '葬送的芙莉莲',
      'season_title': '葬送的芙莉莲',
      'cover': 'http://i0.hdslb.com/bfs/bangumi/image/x.png',
      'total': 28,
      'evaluate': '寿命逾千年的魔法使…',
      'jp_title': '葬送のフリーレン',
      'rating': {'score': 9.9},
      'publish': {'pub_time': '2023-10-24 20:00:00'},
      'stat': {'views': 445646619, 'favorites': 5623892, 'danmakus': 1381239},
      'areas': [
        {'name': '日本'}
      ],
      'styles': [
        {'name': '奇幻'},
        {'name': '冒险'}
      ],
      // 真实接口里会重复下发（内地版/中配版各一份）
      'episodes': [
        {'ep_id': 101, 'cid': 9001, 'title': '2', 'long_title': '第二集', 'duration': 1440000},
        {'ep_id': 100, 'cid': 9000, 'title': '1', 'long_title': '第一集', 'duration': 1440000},
        {'ep_id': 100, 'cid': 9000, 'title': '1', 'long_title': '第一集', 'duration': 1440000},
        {'ep_id': 103, 'cid': 0, 'title': '3', 'long_title': '无 cid 的条目'},
        // 同一集号但 ep_id 不同（中配版线路）→ 也要去重
        {'ep_id': 201, 'cid': 9100, 'title': '1', 'long_title': '第一集'},
      ],
    };

    test('分集去重 + 按集排序 + 过滤无 cid 的条目', () {
      final detail = BiliCatalog.parseDetail(fixture, '46089');
      expect(detail.episodes.map((e) => e.index), [1, 2]);
      expect(detail.episodes.first.cid, 9000);
      expect(detail.episodes.first.title, '第一集');
      expect(detail.episodes.first.durationSeconds, 1440);
    });

    test('主字段解析正确', () {
      final detail = BiliCatalog.parseDetail(fixture, '46089');
      expect(detail.summary.title, '葬送的芙莉莲');
      expect(detail.summary.score, 9.9);
      expect(detail.summary.year, 2023);
      expect(detail.summary.totalEpisodes, 28);
      expect(detail.summary.tags, ['奇幻', '冒险']);
      expect(detail.originalTitle, '葬送のフリーレン');
      expect(detail.areas, ['日本']);
      expect(detail.danmakuCount, 1381239);
      // http 封面统一升级为 https
      expect(detail.summary.cover.startsWith('https://'), isTrue);
    });
  });

  group('B 站搜索项解析', () {
    test('去掉高亮标签、解析评分与集数', () {
      final item = BiliCatalog.parseSearchItem({
        'season_id': 102261,
        'title': '葬送的<em class="keyword">芙莉莲</em> 中配版',
        'org_title': '葬送のフリーレン',
        'cover': '//i0.hdslb.com/a.png',
        'ep_size': 28,
        'media_score': {'score': 9},
        'styles': '漫画改/奇幻',
        'pubtime': 1751644800,
        'index_show': '全28话',
      });

      expect(item, isNotNull);
      expect(item!.title, '葬送的芙莉莲 中配版');
      expect(item.source, CatalogSource.bili);
      expect(item.score, 9);
      expect(item.totalEpisodes, 28);
      expect(item.tags, ['漫画改', '奇幻']);
      expect(item.cover.startsWith('https://'), isTrue);
      expect(item.year, 2025);
    });

    test('缺少 season_id 返回 null', () {
      expect(BiliCatalog.parseSearchItem({'title': 'x'}), isNull);
    });
  });

  group('B 站索引项解析', () {
    test('字符串评分转 double、协议相对封面转 https', () {
      final item = BiliCatalog.parseIndexItem({
        'season_id': 47836,
        'title': '鬼灭之刃 柱训练篇',
        'subTitle': '羁绊连接，传承信念',
        'cover': '//i0.hdslb.com/b.png',
        'score': '9.7',
        'index_show': '全8话',
      });
      expect(item!.score, 9.7);
      expect(item.cover.startsWith('https://'), isTrue);
      expect(item.status, '全8话');
    });
  });

  group('AniList 解析', () {
    test('中文别名优先作为标题，评分除以 10', () {
      final item = AniListCatalog.parseSummary({
        'id': 154587,
        'title': {
          'romaji': 'Sousou no Frieren',
          'native': '葬送のフリーレン',
        },
        'synonyms': ['Frieren at the Funeral', '葬送的芙莉莲'],
        'episodes': 28,
        'startDate': {'year': 2023},
        'coverImage': {'large': 'https://s4.anilist.co/x.jpg'},
        'averageScore': 90,
        'genres': ['Fantasy'],
        'status': 'FINISHED',
      });

      expect(item, isNotNull);
      expect(item!.title, '葬送的芙莉莲');
      expect(item.subtitle, 'Sousou no Frieren');
      expect(item.score, 9.0);
      expect(item.status, '已完结');
      expect(item.source, CatalogSource.anilist);
    });

    test('没有中文别名时用罗马音', () {
      final item = AniListCatalog.parseSummary({
        'id': 1,
        'title': {'romaji': 'Cowboy Bebop'},
        'synonyms': ['Cowboy Bebop'],
        'averageScore': 86,
      });
      expect(item!.title, 'Cowboy Bebop');
    });

    test('缺 id 返回 null', () {
      expect(AniListCatalog.parseSummary({'title': {}}), isNull);
    });
  });

  group('详情序列化往返', () {
    test('AnimeDetail → json → AnimeDetail 保持一致', () {
      final detail = BiliCatalog.parseDetail({
        'season_id': 1,
        'title': '测试番',
        'episodes': [
          {'ep_id': 1, 'cid': 2, 'title': '1', 'long_title': '第一集'},
        ],
      }, '1');

      final roundTrip = AnimeDetail.fromJson(detail.toJson());
      expect(roundTrip.summary.title, '测试番');
      expect(roundTrip.episodes.single.cid, 2);
      expect(roundTrip.fetchedAt, isNotNull);
    });
  });
}
