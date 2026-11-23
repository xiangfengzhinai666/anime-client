/// 一条播放线路（次元城返回的 name/url）。
class PlayLine {
  const PlayLine({required this.name, required this.url});

  final String name;
  final String url;

  @override
  String toString() => 'PlayLine($name)';
}

/// 解析 `/sections/{id}/play-url` 的返回。
///
/// 站点可能返回三种形状，这里都兼容：
/// - `{data: {name, url}}`
/// - `{data: [{name, url}, ...]}`
/// - `{data: {list: [{name, url}, ...]}}`
List<PlayLine> parsePlayLines(Object? data) {
  final lines = <PlayLine>[];

  void addOne(Object? raw) {
    if (raw is! Map) return;
    final map = raw.cast<String, dynamic>();
    final url = '${map['url'] ?? ''}'.trim();
    if (url.isEmpty) return;
    final name = '${map['name'] ?? map['title'] ?? '线路 ${lines.length + 1}'}';
    lines.add(PlayLine(name: name, url: url));
  }

  void walk(Object? node) {
    if (node is List) {
      for (final item in node) {
        addOne(item);
      }
      return;
    }
    if (node is Map) {
      final map = node.cast<String, dynamic>();
      if (map.containsKey('url')) {
        addOne(map);
        return;
      }
      for (final key in const ['list', 'lines', 'data', 'items']) {
        if (map.containsKey(key)) walk(map[key]);
      }
    }
  }

  walk(data);
  return lines;
}
