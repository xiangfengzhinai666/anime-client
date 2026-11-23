import 'package:anime_client/features/catalog/data/catalog_models.dart';
import 'package:anime_client/features/catalog/data/source_match.dart';
import 'package:flutter_test/flutter_test.dart';

AnimeSummary _anime({
  required String title,
  int? year,
  int? episodes,
  String sourceId = '1',
}) {
  return AnimeSummary(
    source: CatalogSource.cycani,
    sourceId: sourceId,
    title: title,
    year: year,
    totalEpisodes: episodes,
  );
}

void main() {
  group('查询词变体', () {
    test('去掉结尾的「。」', () {
      final variants = titleQueryVariants('我的青春恋爱物语果然有问题。');
      expect(variants, contains('我的青春恋爱物语果然有问题'));
    });

    test('去掉第 N 季后缀', () {
      final variants = titleQueryVariants('无职转生 第二季 ～到了异世界～');
      expect(variants, contains('无职转生  ～到了异世界～'));
    });

    test('短标题也能生成 3 字前缀（否则「学生会有洞」搜不到）', () {
      final variants = titleQueryVariants('学生会有洞！');
      expect(variants, contains('学生会'));
    });

    test('空标题返回空', () {
      expect(titleQueryVariants('   '), isEmpty);
    });
  });

  group('候选打分', () {
    final wanted = _anime(title: '路人女主的养成方法', year: 2015, episodes: 13);

    test('TV 原版分数高于剧场版', () {
      final tv = _anime(title: '路人女主的养成方法', year: 2015, episodes: 13);
      final movie = _anime(title: '路人女主的养成方法 Fine', year: 2019, episodes: 1);
      expect(matchScore(wanted, tv), greaterThan(matchScore(wanted, movie)));
    });

    test('同年份同集数能挑中', () {
      final candidates = [
        _anime(title: '路人女主的养成方法 Fine', year: 2019, episodes: 1),
        _anime(title: '路人女主的养成方法 ♭', year: 2017, episodes: 12),
        _anime(title: '路人女主的养成方法', year: 2015, episodes: 13),
      ];
      final best = pickBestCandidate(wanted, candidates);
      expect(best, isNotNull);
      expect(best!.year, 2015);
      expect(best.totalEpisodes, 13);
    });

    test('空候选返回 null', () {
      expect(pickBestCandidate(wanted, const []), isNull);
    });
  });
}
