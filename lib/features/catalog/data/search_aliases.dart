/// 搜索别名表：把用户常输的缩写/俗称展开成各站点实际使用的正式名。
///
/// 为什么需要：搜索接口只做**字面匹配**。
/// - AniList 的标题是 `Shin Seiki Evangelion` / `Evangelion Shin Movie: Jo`，
///   没有任何一条叫 "EVA"，所以搜 "EVA" 只有 2 条；
/// - B 站同样搜不到 "EVA" 之外的剧场版。
///
/// 表里只放"确定性高"的映射：缩写/俗称 → 正式名（英文 / 日文 / 中文各一条）。
/// 宁可少加，也不要加错（错误别名会污染搜索结果）。
const Map<String, List<String>> _aliases = {
  'eva': ['Evangelion', '新世紀エヴァンゲリオン', '新世纪福音战士'],
  'jojo': ['JoJo no Kimyou na Bouken', 'ジョジョの奇妙な冒険', 'JOJO的奇妙冒险'],
  '巨人': ['Shingeki no Kyojin', '進撃の巨人', '进击的巨人'],
  '进巨': ['Shingeki no Kyojin', '進撃の巨人', '进击的巨人'],
  '无职': ['Mushoku Tensei', '無職転生', '无职转生'],
  '咒术': ['Jujutsu Kaisen', '呪術廻戦', '咒术回战'],
  '鬼灭': ['Kimetsu no Yaiba', '鬼滅の刃', '鬼灭之刃'],
  '间谍': ['Spy x Family', 'SPY×FAMILY', '间谍过家家'],
  '芙莉莲': ['Sousou no Frieren', '葬送のフリーレン', '葬送的芙莉莲'],
  '孤独摇滚': ['Bocchi the Rock', 'ぼっち・ざ・ろっく', '孤独摇滚'],
  '药屋': ['Kusuriya no Hitorigoto', '薬屋のひとりごと', '药屋少女的呢喃'],
  '辉夜': ['Kaguya-sama wa Kokurasetai', 'かぐや様は告らせたい', '辉夜大小姐想让我告白'],
  '春物': ['Yahari Ore no Seishun Love Comedy wa Machigatteiru', 'やはり俺の青春ラブコメはまちがっている', '我的青春恋爱物语果然有问题'],
  '刀剑': ['Sword Art Online', 'ソードアート・オンライン', '刀剑神域'],
  're0': ['Re:Zero kara Hajimeru Isekai Seikatsu', 'Re:ゼロから始める異世界生活', 'Re：从零开始的异世界生活'],
  '魔圆': ['Mahou Shoujo Madoka Magica', '魔法少女まどか☆マギカ', '魔法少女小圆'],
  '小圆': ['Mahou Shoujo Madoka Magica', '魔法少女まどか☆マギカ', '魔法少女小圆'],
  '石头门': ['Steins;Gate', 'シュタインズ・ゲート', '命运石之门'],
  '命运石之门': ['Steins;Gate', 'シュタインズ・ゲート'],
  '钢炼': ['Hagane no Renkinjutsushi', '鋼の錬金術師', '钢之炼金术师'],
  '排球': ['Haikyuu!!', 'ハイキュー!!', '排球少年'],
  '篮球': ['Slam Dunk', 'スラムダンク', '灌篮高手'],
  '灌篮': ['Slam Dunk', 'スラムダンク', '灌篮高手'],
  '大老师': ['Yahari Ore no Seishun Love Comedy wa Machigatteiru', 'やはり俺の青春ラブコメはまちがっている'],
  'fate': ['Fate/stay night', 'フェイト/ステイナイト', '命运之夜'],
  'sao': ['Sword Art Online', 'ソードアート・オンライン', '刀剑神域'],
};

/// 把查询词展开成多个（尽量互不重复）的搜索词，原词永远排第一。
List<String> expandSearchQuery(String raw) {
  final query = raw.trim();
  if (query.isEmpty) return const [];

  final results = <String>[query];
  final lower = query.toLowerCase();

  for (final entry in _aliases.entries) {
    if (lower == entry.key || lower.replaceAll(' ', '') == entry.key) {
      results.addAll(entry.value);
      break;
    }
  }

  // 中文/日文里带了别名（如"EVA 剧场版"）也展开一次
  if (results.length == 1) {
    for (final entry in _aliases.entries) {
      if (entry.key.length >= 2 && lower.contains(entry.key)) {
        results.addAll(entry.value.take(1));
        break;
      }
    }
  }

  final seen = <String>{};
  return [
    for (final item in results)
      if (item.trim().isNotEmpty && seen.add(item.trim().toLowerCase()))
        item.trim(),
  ].take(4).toList();
}
