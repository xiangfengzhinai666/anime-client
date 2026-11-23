import 'catalog_models.dart';

/// 换源匹配：给「从别的站点的条目」找「能播放的条目」。
///
/// 站点搜索对标题很敏感（多一个「。」就 0 结果），所以这里做两件事：
/// 1. 生成多个候选查询词，从精确到宽松依次尝试；
/// 2. 对搜到的候选打分，避免挑到剧场版/别的季。

/// 生成查询词变体（按从精确到宽松的顺序）。
Iterable<String> titleQueryVariants(String raw) sync* {
  final base = raw.trim();
  if (base.isEmpty) return;

  final seen = <String>{};
  final variants = <String>[base];

  // 去掉结尾标点
  final noPunct =
      base.replaceAll(RegExp(r'[。！？!?、，,\.·…\s]+$'), '').trim();
  if (noPunct.isNotEmpty) variants.add(noPunct);

  // 去掉「第N季 / Season N」这类后缀
  final noSeason = noPunct
      .replaceAll(RegExp(r'第[一二三四五六七八九十0-9]+季'), '')
      .replaceAll(RegExp(r'\bSeason\s*\d+\b', caseSensitive: false), '')
      .trim();
  if (noSeason.isNotEmpty) variants.add(noSeason);

  // 去掉括号内容（（中配版）之类）
  final noBracket =
      noSeason.replaceAll(RegExp(r'[（(【\[].*?[）)】\]]'), '').trim();
  if (noBracket.isNotEmpty) variants.add(noBracket);

  // 逐步截短：站点搜索是子串匹配，短一点往往能命中
  for (final length in const [8, 6, 4, 3]) {
    if (noBracket.length > length) {
      variants.add(noBracket.substring(0, length));
    }
  }

  for (final v in variants) {
    if (v.isNotEmpty && seen.add(v)) yield v;
  }
}

/// 给候选条目打分：同年份、集数接近、非剧场版、标题相似 → 越像分越高。
int matchScore(AnimeSummary wanted, AnimeSummary candidate) {
  var score = 0;

  // 剧场版 / 总集篇优先级最低
  if (RegExp(r'剧场版|劇場版|总集篇|總集篇|Movie|The Movie|Fine|完结篇|完\b')
      .hasMatch(candidate.title)) {
    score -= 6;
  }

  if (wanted.year != null && candidate.year != null) {
    final gap = (wanted.year! - candidate.year!).abs();
    if (gap == 0) {
      score += 5;
    } else if (gap <= 1) {
      score += 2;
    } else {
      score -= 4;
    }
  }

  final wantedEpisodes = wanted.totalEpisodes ?? 0;
  final candidateEpisodes = candidate.totalEpisodes ?? 0;
  if (wantedEpisodes > 0 && candidateEpisodes > 0) {
    final gap = (wantedEpisodes - candidateEpisodes).abs();
    if (gap == 0) {
      score += 4;
    } else if (gap <= 2) {
      score += 1;
    } else {
      score -= 2;
    }
  }

  if (TitleMatcher.similar(wanted.title, candidate.title)) score += 2;
  if (wanted.title.trim() == candidate.title.trim()) score += 2;

  return score;
}

/// 从候选里挑最像的一部；候选为空返回 null。
AnimeSummary? pickBestCandidate(
  AnimeSummary wanted,
  List<AnimeSummary> candidates,
) {
  if (candidates.isEmpty) return null;
  AnimeSummary? best;
  var bestScore = -1 << 30;
  for (final candidate in candidates) {
    final score = matchScore(wanted, candidate);
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  return best;
}
