import 'dart:convert';
import 'dart:io';

import 'package:anime_client/features/danmaku/data/danmaku_models.dart';
import 'package:anime_client/features/danmaku/danmaku_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('B 站弹幕 XML 解析', () {
    test('解析时间/模式/颜色/文本', () {
      const xml = '<?xml version="1.0" encoding="UTF-8"?><i>'
          '<d p="2.42100,5,25,16646914,1699283004,0,c99d,1,10">早上好</d>'
          '<d p="3.5,1,25,16777215,1699283004,0,abc,2,10">滚动弹幕</d>'
          '</i>';
      final items = parseBilibiliDanmakuXml(xml);
      expect(items.length, 2);
      expect(items.first.timeMs, 2421);
      expect(items.first.mode, DanmakuMode.top);
      expect(items.first.color, 16646914);
      expect(items.first.text, '早上好');
      expect(items.last.mode, DanmakuMode.scroll);
      // 按时间排序
      expect(items.first.timeMs, lessThan(items.last.timeMs));
    });

    test('HTML 实体会被还原', () {
      const xml = '<d p="1,1,25,16777215,0,0,a,1,10">&lt;哈哈&gt; &amp; 好</d>';
      final items = parseBilibiliDanmakuXml(xml);
      expect(items.single.text, '<哈哈> & 好');
    });

    test('坏数据被跳过', () {
      const xml = '<d p="not-a-number,1,25,16777215">坏</d>'
          '<d p="1,1,25,16777215">好的</d>';
      final items = parseBilibiliDanmakuXml(xml);
      expect(items.length, 1);
      expect(items.single.text, '好的');
    });
  });

  group('压缩流解码', () {
    test('raw deflate 能解出来', () {
      final payload = utf8.encode('<i><d p="1,1,25,16777215">压缩</d></i>');
      final compressed = ZLibCodec(raw: true).encode(payload);
      final text = decodeDanmakuBytes(compressed);
      expect(text, contains('<d p='));
      expect(text, contains('压缩'));
    });

    test('纯文本不会被破坏', () {
      const plain = '<i><d p="1,1,25,16777215">x</d></i>';
      expect(decodeDanmakuBytes(utf8.encode(plain)), plain);
    });
  });

  group('次元城弹幕解析', () {
    test('解析 time_point/mode/color/content', () {
      final items = parseCycaniDanmaku([
        {'time_point': 0.208, 'mode': 'normal', 'color': 16065069, 'content': '啊'},
        {'time_point': 2.014, 'mode': 'top', 'color': 16777215, 'content': '顶部'},
        {'time_point': 1.0, 'content': ''},
      ]);
      expect(items.length, 2);
      expect(items.first.timeMs, 208);
      expect(items.last.mode, DanmakuMode.top);
    });
  });

  group('弹幕设置', () {
    test('默认值：开启、跟随倍速、两个源', () {
      const settings = DanmakuSettings();
      expect(settings.enabled, isTrue);
      expect(settings.followSpeed, isTrue);
      expect(settings.sources, contains(DanmakuSource.server));
      expect(settings.sources, contains(DanmakuSource.bilibili));
    });

    test('JSON 往返', () {
      const settings = DanmakuSettings(
        opacity: 0.6,
        fontSize: 30,
        blockedWords: ['广告', '节奏'],
        dandanplayAppId: 'id',
        dandanplayAppSecret: 'secret',
      );
      final restored = DanmakuSettings.fromJson(jsonEncode(settings.toJson()));
      expect(restored.opacity, 0.6);
      expect(restored.fontSize, 30);
      expect(restored.blockedWords, ['广告', '节奏']);
      expect(restored.dandanplayAppId, 'id');
    });

    test('屏蔽词正则可以匹配', () {
      const settings = DanmakuSettings(blockedWords: ['广告', '剧透']);
      expect(settings.blockedPattern!.hasMatch('这是广告'), isTrue);
      expect(settings.blockedPattern!.hasMatch('正常弹幕'), isFalse);
    });

    test('坏 JSON 回落默认值', () {
      final restored = DanmakuSettings.fromJson('{oops');
      expect(restored.enabled, isTrue);
    });
  });
}
