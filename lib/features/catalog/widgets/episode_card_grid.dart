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
    this.playable = true,
  });

  final List<AnimeEpisode> episodes;
  final ValueChanged<int> onPlay;

  /// 按集号补全的元信息（封面/时长/日期）。
  final Map<int, AnimeEpisode> meta;

  /// 兜底封面（番剧封面）。
  final String fallbackCover;

  /// 该源是否可直接播放（false 时卡片仍可点，但会走自动找源）。
  final bool playable;

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
              playable: playable || ep.sectionId.isNotEmpty,
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
    required this.playable,
    required this.onTap,
  });

  final AnimeEpisode episode;
  final String cover;
  final int durationSeconds;
  final String pubDate;
  final bool playable;
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
                  Positioned(
                    right: 6,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: playable
                            ? const Color(0xCC1B5E20)
                            : const Color(0xCC424242),
                        borderRadius: AppRadius.pillAll,
                      ),
                      child: Text(
                        playable ? '有资源' : '无资源',
                        style: const TextStyle(
                          color: Colors.white,
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
