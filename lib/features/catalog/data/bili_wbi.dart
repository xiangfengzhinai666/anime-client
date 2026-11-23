import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/network/api_client.dart';

/// B 站 wbi 签名。
///
/// 背景：B 站 web 接口从 2023 年起对搜索等接口加了 `w_rid` / `wts` 签名，
/// 算法是「取 nav 接口下发的两张 key → 按固定置换表拼出 mixinKey →
/// 参数排序 + URL 编码 → md5(query + mixinKey)」。
///
/// 注意：key 会轮换，必须每次从 nav 接口取（这里做了 10 分钟缓存）。
class BiliWbi {
  BiliWbi(this._client, {this.cacheTtl = const Duration(minutes: 10)});

  static const String navUrl =
      'https://api.bilibili.com/x/web-interface/nav';

  static const Map<String, String> refererHeaders = {
    'Referer': 'https://www.bilibili.com/',
    'Origin': 'https://www.bilibili.com',
  };

  /// B 站官方的置换表（固定不变）。
  static const List<int> mixinKeyEncTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
    27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
    37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
    22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
  ];

  final ApiClient _client;
  final Duration cacheTtl;

  String? _mixinKey;
  DateTime? _fetchedAt;

  /// 给参数加上 `wts` 与 `w_rid`，返回可直接发请求的 map。
  Future<Map<String, dynamic>> sign(Map<String, dynamic> params) async {
    final key = await _ensureMixinKey();
    final wts = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final signed = <String, dynamic>{...params, 'wts': wts};
    final query = encodeQuery(signed);
    final wRid = md5.convert(utf8.encode(query + key)).toString();

    return {...signed, 'w_rid': wRid};
  }

  /// 参数 → query string：按 key 排序，值去掉 `!'()*` 后 URL 编码。
  static String encodeQuery(Map<String, dynamic> params) {
    final keys = params.keys.toList()..sort();
    return keys
        .map((k) {
          final raw = '${params[k]}'.replaceAll(RegExp(r"[!'()*]"), '');
          return '$k=${Uri.encodeComponent(raw)}';
        })
        .join('&');
  }

  /// 由 imgKey / subKey 拼出 mixinKey（前 32 位）。
  static String buildMixinKey(String imgKey, String subKey) {
    final origin = imgKey + subKey;
    final buffer = StringBuffer();
    for (final index in mixinKeyEncTab) {
      if (index < origin.length) buffer.write(origin[index]);
    }
    final mixed = buffer.toString();
    return mixed.length <= 32 ? mixed : mixed.substring(0, 32);
  }

  Future<String> _ensureMixinKey() async {
    final cached = _mixinKey;
    final at = _fetchedAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < cacheTtl) {
      return cached;
    }

    final json = await _client.getJson(
      navUrl,
      headers: refererHeaders,
      tag: 'bili-nav',
    );

    // 未登录时 code 为 -101，但 wbi_img 仍然下发
    final data = json['data'];
    final wbi = data is Map ? data['wbi_img'] : null;
    if (wbi is! Map) {
      throw ApiException('无法获取 B 站签名 key（nav 接口未返回 wbi_img）');
    }
    final imgUrl = '${wbi['img_url']}';
    final subUrl = '${wbi['sub_url']}';
    final imgKey = _fileName(imgUrl);
    final subKey = _fileName(subUrl);
    if (imgKey.isEmpty || subKey.isEmpty) {
      throw ApiException('B 站签名 key 解析失败');
    }

    _mixinKey = buildMixinKey(imgKey, subKey);
    _fetchedAt = DateTime.now();
    return _mixinKey!;
  }

  static String _fileName(String url) {
    final name = url.split('/').last;
    return name.replaceAll(RegExp(r'\.(png|jpg|jpeg|webp)$'), '');
  }
}
