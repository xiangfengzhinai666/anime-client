import 'package:anime_client/features/catalog/data/catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('标题归一化', () {
    test('去标点与空格', () {
      expect(TitleMatcher.normalize('葬送的芙莉莲！'), '葬送的芙莉莲');
      expect(TitleMatcher.normalize('葬送のフリーレン'), '葬送のフリーレン');
      expect(TitleMatcher.normalize('Frieren: Beyond Journey\'s End'),
          'frierenbeyondjourneysend');
    });

    test('全角转半角并小写', () {
      expect(TitleMatcher.normalize('ＡＢＣ　１２３'), 'abc123');
    });

    test('空串安全', () {
      expect(TitleMatcher.normalize(''), '');
      expect(TitleMatcher.normalize('  ·  '), '');
    });
  });

  group('同番判定', () {
    test('完全同名视为同一部', () {
      expect(
        TitleMatcher.sameShow(
          titleA: '葬送的芙莉莲',
          titleB: '葬送的芙莉莲',
          yearA: 2023,
          yearB: 2023,
        ),
        isTrue,
      );
    });

    test('同名但年份差 3 年 → 不是同一部', () {
      expect(
        TitleMatcher.sameShow(
          titleA: '无职转生',
          titleB: '无职转生',
          yearA: 2021,
          yearB: 2024,
        ),
        isFalse,
      );
    });

    test('包含关系且集数一致 → 视为同一部', () {
      expect(
        TitleMatcher.sameShow(
          titleA: '葬送的芙莉莲 第二季',
          titleB: '葬送的芙莉莲',
          episodesA: 28,
          episodesB: 28,
        ),
        isTrue,
      );
    });

    test('包含关系但集数不同 → 保守判为不同', () {
      expect(
        TitleMatcher.sameShow(
          titleA: '葬送的芙莉莲 第二季',
          titleB: '葬送的芙莉莲',
          episodesA: 28,
          episodesB: 12,
        ),
        isFalse,
      );
    });

    test('不同作品不会误判', () {
      expect(
        TitleMatcher.sameShow(titleA: '孤独摇滚', titleB: '葬送的芙莉莲'),
        isFalse,
      );
    });

    test('空标题直接判否', () {
      expect(TitleMatcher.sameShow(titleA: '', titleB: 'x'), isFalse);
    });
  });
}
