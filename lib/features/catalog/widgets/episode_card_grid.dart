import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../data/catalog_models.dart';
import 'cover_image.dart';

/// 剧集卡片网格（仿 AniCh）。
///
/// 数据降级链：
/// 1. 分集自带封面/时长/日期（B 站条目）；
/// 2. 次元城条目：用 B 站匹配补（[meta]）；
/// 3. 都没有：缩略图退回番剧封面，时长/日期留空。
class EpisodeCardGrid extends StatelessWidget {
  const EpisodeCardGrid({
    super.key,
    required this.episodes,
    required this.onPlay,
    this.meta = const {},
    this.fallbackCover = '',
    this.badgeFor,
  });

  final List<AnimeEpisode> episodes;
  final ValueChanged<int> onPlay;

  /// 按集号补全的元信息（封面/时长/日期）。
  final Map<int, AnimeEpisode> meta;

  /// 兜底封面（番剧封面）。
  final String fallbackCover;

  /// 每集的状态标记。
  ///
  /// 只用来标注"确实不能播"的情况：
  /// - 能播 / 可自动找源 → 返回 null（不标注，避免误导）
  /// - 当前源缺播放地址且没有替代 → 返回如「缺地址」
  final String? Function(AnimeEpisode episode)? badgeFor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 220).floor().clamp(2, 8);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: episodes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 16 / 13,
          ),
          itemBuilder: (context, i) {
            final ep = episodes[i];
            final extra = meta[ep.index];
            return _EpisodeCard(
              episode: ep,
              cover: _pickCover(ep, extra),
              durationSeconds:
                  extra?.durationSeconds ?? ep.durationSeconds,
              pubDate: extra?.pubDate ?? ep.pubDate,
              badge: badgeFor?.call(ep),
              onTap: () => onPlay(ep.index),
            );
          },
        );
      },
    );
  }

  String _pickCover(AnimeEpisode ep, AnimeEpisode? extra) {
    if (ep.cover.isNotEmpty) return ep.cover;
    if (extra != null && extra.cover.isNotEmpty) return extra.cover;
    return fallbackCover;
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.cover,
    required this.durationSeconds,
    required this.pubDate,
    required this.badge,
    required this.onTap,
  });

  final AnimeEpisode episode;
  final String cover;
  final int durationSeconds;
  final String pubDate;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(url: cover, fit: BoxFit.cover, radius: 0),
                  // 底部渐变，保证时长可读
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xB3000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 4,
                    child: Text(
                      _fmtDuration(durationSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      right: 6,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xB3000000),
                          borderRadius: AppRadius.pillAll,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _label(episode),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (pubDate.isNotEmpty)
            Text(
              pubDate,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  /// 标题已经带"第 N 集"时不要重复加前缀。
  static String _label(AnimeEpisode ep) {
    final title = ep.title.trim();
    if (title.isEmpty) return '第 ${ep.index} 集';
    if (title.startsWith('第') && title.contains('集')) return title;
    return '第 ${ep.index} 集 · $title';
  }

  static String _fmtDuration(int seconds) {
    if (seconds <= 0) return '--:--';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}
