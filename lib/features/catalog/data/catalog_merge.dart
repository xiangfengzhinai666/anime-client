import 'catalog_models.dart';

/// 跨源结果合并。
///
/// 规则（宁多勿错）：
/// 1. 主源（B 站）条目全部保留，顺序不变；
/// 2. 副源（AniList）条目逐条与已合并列表比对，判定为"同一部"就丢弃；
/// 3. 判定依据：标题归一化后同番（`TitleMatcher.sameShow`），
///    或两者的副标题（日文原名）归一化后完全相同且年份相近。
///
/// 这样能同时做到：
/// - B 站有 S1、AniList 也有 S1 → 只留 B 站那条；
/// - B 站没有 S2、AniList 有 S2 → S2 保留（季节不同，标题/年份/集数都不同）。
class CatalogMerger {
  CatalogMerger._();

  static List<AnimeSummary> merge(
    List<AnimeSummary> primary,
    Iterable<AnimeSummary> secondary, {
    void Function(String message)? trace,
  }) {
    final merged = <AnimeSummary>[...primary];
    for (final candidate in secondary) {
      AnimeSummary? hit;
      for (final existing in merged) {
        if (isDuplicate(existing, candidate)) {
          hit = existing;
          break;
        }
      }
      trace?.call(
        '${hit == null ? 'KEEP' : 'DROP'} "${candidate.title}"'
        '| norm=${TitleMatcher.normalize(candidate.title)}'
        '| units=${candidate.title.runes.map((r) => r.toRadixString(16)).join(",")}'
        '| ${candidate.year}/${candidate.totalEpisodes}',
      );
      if (hit == null) merged.add(candidate);
    }
    return merged;
  }

  static bool isDuplicate(AnimeSummary a, AnimeSummary b) {
    if (TitleMatcher.sameShow(
      titleA: a.title,
      titleB: b.title,
      yearA: a.year,
      yearB: b.year,
      episodesA: a.totalEpisodes,
      episodesB: b.totalEpisodes,
    )) {
      return true;
    }

    // 简繁/一字之差：标题近似 + 年份相近 + 集数一致 才认作同一部
    if (TitleMatcher.similar(a.title, b.title) ||
        TitleMatcher.similar(a.title, b.subtitle)) {
      final yearOk = a.year == null || b.year == null || (a.year! - b.year!).abs() <= 1;
      final epsOk = a.totalEpisodes == null ||
          b.totalEpisodes == null ||
          a.totalEpisodes == b.totalEpisodes;
      if (yearOk && epsOk) return true;
    }

    // 中文标题不同名时，用日文原名兜底（B 站的 org_title vs AniList 的 native）
    final subA = TitleMatcher.normalize(a.subtitle);
    final subB = TitleMatcher.normalize(b.subtitle);
    if (subA.isEmpty || subB.isEmpty || subA != subB) return false;

    if (a.year != null && b.year != null && (a.year! - b.year!).abs() > 1) {
      return false;
    }
    if (a.totalEpisodes != null &&
        b.totalEpisodes != null &&
        a.totalEpisodes != b.totalEpisodes) {
      return false;
    }
    return true;
  }
}
