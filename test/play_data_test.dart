import 'package:anime_client/features/play/data/cycani_auth.dart';
import 'package:anime_client/features/play/data/play_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('播放地址解析', () {
    test('单个 {name,url} 对象', () {
      final lines = parsePlayLines({'name': '线路一', 'url': 'https://a/x.m3u8'});
      expect(lines.length, 1);
      expect(lines.first.name, '线路一');
      expect(lines.first.url, 'https://a/x.m3u8');
    });

    test('对象数组', () {
      final lines = parsePlayLines([
        {'name': 'A', 'url': 'https://a/1.m3u8'},
        {'name': 'B', 'url': 'https://a/2.m3u8'},
      ]);
      expect(lines.map((e) => e.name).toList(), ['A', 'B']);
    });

    test('{list: [...]} 包装', () {
      final lines = parsePlayLines({
        'list': [
          {'url': 'https://a/1.m3u8'},
          {'url': 'https://a/2.m3u8'},
        ],
      });
      expect(lines.length, 2);
      // 没名字时自动编号
      expect(lines.first.name, contains('线路'));
    });

    test('缺 url 的条目会被跳过，不会产生空线路', () {
      final lines = parsePlayLines([
        {'name': '坏的'},
        {'name': '好的', 'url': 'https://a/ok.m3u8'},
      ]);
      expect(lines.length, 1);
      expect(lines.single.name, '好的');
    });

    test('空/异常输入返回空列表', () {
      expect(parsePlayLines(null), isEmpty);
      expect(parsePlayLines(const {}), isEmpty);
      expect(parsePlayLines('oops'), isEmpty);
    });
  });

  group('登录态序列化', () {
    test('可以往返', () {
      final session = CycaniSession(
        token: 't0ken',
        username: 'alice',
        nickname: 'A',
        expiresAt: DateTime(2026, 12, 1),
      );
      final restored = CycaniSession.fromJson(session.toJson());
      expect(restored, isNotNull);
      expect(restored!.token, 't0ken');
      expect(restored.username, 'alice');
      expect(restored.nickname, 'A');
      expect(restored.expiresAt, DateTime(2026, 12, 1));
    });

    test('没有 token 视为无效', () {
      expect(CycaniSession.fromJson(const {'username': 'x'}), isNull);
      expect(CycaniSession.fromJson(const {}), isNull);
    });

    test('过期判断', () {
      final expired = CycaniSession(
        token: 't',
        username: 'u',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(expired.isExpired, isTrue);
      final fresh = CycaniSession(
        token: 't',
        username: 'u',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );
      expect(fresh.isExpired, isFalse);
      const noExpiry = CycaniSession(token: 't', username: 'u');
      expect(noExpiry.isExpired, isFalse);
    });
  });
}
