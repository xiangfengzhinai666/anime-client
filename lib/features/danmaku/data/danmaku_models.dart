import 'dart:convert';
import 'dart:io';

/// 弹幕来源。
enum DanmakuSource {
  server('server', '服务端弹幕'),
  bilibili('bilibili', '哔哩哔哩弹幕'),
  bilibiliHkTw('bilibili_hk_tw', '哔哩哔哩（港澳台）'),
  tencent('tencent', '腾讯视频弹幕'),
  dandanplay('dandanplay', '弹弹play弹幕');

  const DanmakuSource(this.id, this.label);

  final String id;
  final String label;

  static DanmakuSource? parse(String id) {
    for (final source in DanmakuSource.values) {
      if (source.id == id) return source;
    }
    return null;
  }
}

/// 弹幕显示模式。
enum DanmakuMode {
  scroll('scroll'),
  top('top'),
  bottom('bottom');

  const DanmakuMode(this.id);

  final String id;

  static DanmakuMode parse(String raw) {
    switch (raw) {
      case 'top':
      case '5':
        return DanmakuMode.top;
      case 'bottom':
      case '4':
        return DanmakuMode.bottom;
      default:
        return DanmakuMode.scroll;
    }
  }
}

/// 一条弹幕。
class DanmakuItem {
  const DanmakuItem({
    required this.timeMs,
    required this.text,
    this.mode = DanmakuMode.scroll,
    this.color = 0xFFFFFF,
    this.source = DanmakuSource.server,
  });

  /// 相对视频开头的毫秒数。
  final int timeMs;
  final String text;
  final DanmakuMode mode;

  /// RGB 整数（0xRRGGBB）。
  final int color;
  final DanmakuSource source;

  Map<String, dynamic> toJson() => {
        't': timeMs,
        'c': text,
        'm': mode.id,
        'r': color,
        's': source.id,
      };

  static DanmakuItem? fromJson(Map<String, dynamic> json) {
    final text = '${json['c'] ?? ''}'.trim();
    if (text.isEmpty) return null;
    return DanmakuItem(
      timeMs: (json['t'] as num?)?.toInt() ?? 0,
      text: text,
      mode: DanmakuMode.parse('${json['m'] ?? ''}'),
      color: (json['r'] as num?)?.toInt() ?? 0xFFFFFF,
      source: DanmakuSource.parse('${json['s'] ?? ''}') ?? DanmakuSource.server,
    );
  }

  static List<DanmakuItem> decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => DanmakuItem.fromJson(e.cast<String, dynamic>()))
          .whereType<DanmakuItem>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(List<DanmakuItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());
}

/// 多个源合并后的结果。
class DanmakuBundle {
  const DanmakuBundle({required this.items, required this.failedSources});

  final List<DanmakuItem> items;

  /// 拉取失败或没有数据的源（用于界面提示，不阻塞播放）。
  final Set<DanmakuSource> failedSources;

  bool get isEmpty => items.isEmpty;

  static const DanmakuBundle empty =
      DanmakuBundle(items: [], failedSources: {});
}

/// B 站弹幕接口返回的是压缩流（gzip 或 zlib/deflate），先解压再解析。
String decodeDanmakuBytes(List<int> bytes) {
  if (bytes.isEmpty) return '';
  try {
    if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      return utf8.decode(gzip.decode(bytes), allowMalformed: true);
    }
  } catch (_) {
    // 落到下面的 zlib 尝试
  }
  try {
    return utf8.decode(ZLibCodec().decode(bytes), allowMalformed: true);
  } catch (_) {
    // 继续尝试 raw deflate
  }
  try {
    // B 站实际返回的是 raw deflate（没有 zlib 头）
    return utf8.decode(
      ZLibCodec(raw: true).decode(bytes),
      allowMalformed: true,
    );
  } catch (_) {
    // 不是压缩流时按纯文本处理
  }
  return utf8.decode(bytes, allowMalformed: true);
}

/// 解析 B 站弹幕 XML（`<d p="time,mode,size,color,...">text</d>`）。
List<DanmakuItem> parseBilibiliDanmakuXml(
  String xml, {
  DanmakuSource source = DanmakuSource.bilibili,
}) {
  final items = <DanmakuItem>[];
  final pattern = RegExp(r'<d p="([^"]*)"[^>]*>([^<]*)</d>');
  for (final match in pattern.allMatches(xml)) {
    final p = match.group(1) ?? '';
    final text = _unescape(match.group(2) ?? '').trim();
    if (text.isEmpty) continue;

    final parts = p.split(',');
    if (parts.length < 4) continue;

    final seconds = double.tryParse(parts[0]);
    if (seconds == null) continue;
    final mode = DanmakuMode.parse(parts[1]);
    final color = int.tryParse(parts[3]) ?? 0xFFFFFF;

    items.add(DanmakuItem(
      timeMs: (seconds * 1000).round(),
      text: text,
      mode: mode,
      color: color,
      source: source,
    ));
  }
  items.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  return items;
}

/// 解析次元城弹幕 JSON（`items[].time_point/mode/color/content`）。
List<DanmakuItem> parseCycaniDanmaku(
  List<dynamic> raw, {
  DanmakuSource source = DanmakuSource.server,
}) {
  final items = <DanmakuItem>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final map = entry.cast<String, dynamic>();
    final text = '${map['content'] ?? ''}'.trim();
    if (text.isEmpty) continue;
    final seconds = (map['time_point'] as num?)?.toDouble() ?? 0;
    items.add(DanmakuItem(
      timeMs: (seconds * 1000).round(),
      text: text,
      mode: DanmakuMode.parse('${map['mode'] ?? ''}'),
      color: (map['color'] as num?)?.toInt() ?? 0xFFFFFF,
      source: source,
    ));
  }
  items.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  return items;
}

String _unescape(String value) {
  return value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
}
