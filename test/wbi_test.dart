import 'package:anime_client/features/catalog/data/bili_wbi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wbi mixinKey', () {
    test('按置换表拼出 32 位 key（用真实 key 校验）', () {
      const imgKey = '7cd084941338484aae1ad9425b84077c';
      const subKey = '4932caff0ff746eab6f01bf08b70ac45';
      expect(
        BiliWbi.buildMixinKey(imgKey, subKey),
        'ea1db124af3c7062474693fa704f4ff8',
      );
    });

    test('key 不足 64 位时不越界', () {
      expect(BiliWbi.buildMixinKey('abc', 'def'), isA<String>());
    });
  });

  group('wbi 参数编码', () {
    test('按 key 排序并 URL 编码', () {
      expect(
        BiliWbi.encodeQuery({'b': 'x y', 'a': '1'}),
        'a=1&b=x%20y',
      );
    });

    test('去掉 B 站签名要求剔除的字符', () {
      expect(
        BiliWbi.encodeQuery({'q': "a!b'c(d)e*f"}),
        'q=abcdef',
      );
    });

    test('中文按 UTF-8 百分号编码', () {
      expect(
        BiliWbi.encodeQuery({'keyword': '芙莉莲'}),
        'keyword=%E8%8A%99%E8%8E%89%E8%8E%B2',
      );
    });
  });
}
