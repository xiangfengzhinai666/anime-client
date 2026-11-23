import 'package:anime_client/features/catalog/data/catalog_merge.dart';
import 'package:anime_client/features/catalog/data/catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';

AnimeSummary _bili({
  required String title,
  String subtitle = '',
  int? year,
  int? eps,
}) =>
    AnimeSummary(
      source: CatalogSource.bili,
      sourceId: title,
      title: title,
      subtitle: subtitle,
      year: year,
      totalEpisodes: eps,
    );

AnimeSummary _ani({
  required String title,
  String subtitle = '',
  int? year,
  int? eps,
}) =>
    AnimeSummary(
      source: CatalogSource.anilist,
      sourceId: title,
      title: title,
      subtitle: subtitle,
      year: year,
      totalEpisodes: eps,
    );

void main() {
  test('编辑距离：简繁一字之差为 1', () {
    expect(TitleMatcher.levenshtein('葬送的芙莉莲', '葬送的芙莉蓮'), 1);
    expect(TitleMatcher.similar('葬送的芙莉莲', '葬送的芙莉蓮'), isTrue);
    expect(TitleMatcher.similar('葬送的芙莉莲', '葬送的芙莉莲 第2期'), isFalse);
  });

  test('同名同年 → 判为重复，保留主源', () {
    final merged = CatalogMerger.merge(
      [_bili(title: '葬送的芙莉莲', year: 2023, eps: 28)],
      [_ani(title: '葬送的芙莉莲', year: 2023, eps: 28)],
    );
    expect(merged.length, 1);
    expect(merged.single.source, CatalogSource.bili);
  });

  test('不同季（年份/集数不同）→ 保留，补齐第二季', () {
    final merged = CatalogMerger.merge(
      [_bili(title: '葬送的芙莉莲', year: 2023, eps: 28)],
      [_ani(title: '葬送のフリーレン 第2期', year: 2026, eps: 10)],
    );
    expect(merged.length, 2);
    expect(merged.last.source, CatalogSource.anilist);
  });

  test('中文名不同、但日文副标题相同且年份接近 → 视为重复', () {
    final merged = CatalogMerger.merge(
      [_bili(title: '芙莉莲 第一季', subtitle: '葬送のフリーレン', year: 2023, eps: 28)],
      [_ani(title: 'Sousou no Frieren', subtitle: '葬送のフリーレン', year: 2023, eps: 28)],
    );
    expect(merged.length, 1);
  });

  test('副标题相同但集数差很多（TV vs 剧场版）→ 不合并', () {
    final merged = CatalogMerger.merge(
      [_bili(title: '某番', subtitle: 'あるアニメ', year: 2024, eps: 12)],
      [_ani(title: '某番 剧场版', subtitle: 'あるアニメ', year: 2024, eps: 1)],
    );
    expect(merged.length, 2);
  });

  test('主源顺序不变，副源追加在后', () {
    final merged = CatalogMerger.merge(
      [
        _bili(title: 'A', year: 2020, eps: 12),
        _bili(title: 'B', year: 2021, eps: 12),
      ],
      [
        _ani(title: 'C', year: 2019, eps: 24),
        _ani(title: 'A', year: 2020, eps: 12),
      ],
    );
    expect(merged.map((e) => e.title).toList(), ['A', 'B', 'C']);
  });

  test('副源内部也会去重', () {
    final merged = CatalogMerger.merge(
      const [],
      [
        _ani(title: '孤独摇滚', year: 2022, eps: 12),
        _ani(title: '孤独摇滚', year: 2022, eps: 12),
      ],
    );
    expect(merged.length, 1);
  });

  test('标题为空时不会误判', () {
    expect(
      CatalogMerger.isDuplicate(
        _bili(title: ''),
        _ani(title: '非空'),
      ),
      isFalse,
    );
  });

  test('简繁一字之差（葬送的芙莉莲 / 葬送的芙莉蓮）→ 判为同一部', () {
    final merged = CatalogMerger.merge(
      [_bili(title: '葬送的芙莉莲', year: 2023, eps: 28)],
      [_ani(title: '葬送的芙莉蓮', year: 2023, eps: 28)],
    );
    expect(merged.length, 1);
    expect(merged.single.source, CatalogSource.bili);
  });

  test('近似标题但集数不同（第二季 10 集）→ 不合并', () {
    final merged = CatalogMerger.merge(
      [_bili(title: '葬送的芙莉莲', year: 2023, eps: 28)],
      [_ani(title: '葬送的芙莉蓮 第2期', year: 2026, eps: 10)],
    );
    expect(merged.length, 2);
  });

  test('同名但相邻年份 + 集数不同（无职 II vs II Part2）→ 不合并', () {
    final merged = CatalogMerger.merge(
      const [],
      [
        _ani(title: '无职转生 第2季', year: 2023, eps: 13),
        _ani(title: '无职转生 第2季', year: 2024, eps: 12),
      ],
    );
    expect(merged.length, 2);
  });

  test('同名同年但集数不同（B站与 AniList 口径差异）→ 仍合并', () {
    final merged = CatalogMerger.merge(
      [_bili(title: '某番', year: 2023, eps: 28)],
      [_ani(title: '某番', year: 2023, eps: 25)],
    );
    expect(merged.length, 1);
  });
}
