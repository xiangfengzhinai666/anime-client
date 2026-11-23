import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../data/catalog_models.dart';
import 'cover_image.dart';

/// 番剧卡片：封面 + 标题 + 一行元信息。列表/网格通用。
class AnimeCard extends StatelessWidget {
  const AnimeCard({
    super.key,
    required this.anime,
    required this.onTap,
    this.showSource = false,
  });

  final AnimeSummary anime;
  final VoidCallback onTap;
  final bool showSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: CoverImage(
                    url: anime.cover,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    radius: AppRadius.md,
                  ),
                ),
                if (anime.score != null)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: _ScoreBadge(score: anime.score!),
                  ),
                if (showSource)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Text(
                        anime.source.label,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              _meta(anime),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _meta(AnimeSummary anime) {
    final parts = <String>[
      if (anime.year != null) '${anime.year}',
      if ((anime.totalEpisodes ?? 0) > 0) '${anime.totalEpisodes} 话',
      if (anime.status.isNotEmpty) anime.status,
    ];
    return parts.isEmpty ? '暂无信息' : parts.join(' · ');
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 8.5
        ? const Color(0xFFFFB454)
        : (score >= 7.0 ? const Color(0xFF7AD4A0) : const Color(0xFF9A9AA8));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 自适应网格：按可用宽度决定列数。
class AnimeGrid extends StatelessWidget {
  const AnimeGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.shrinkWrap = true,
    this.minTileWidth = 150,
    this.controller,
    this.showSource = false,
  });

  final List<AnimeSummary> items;
  final void Function(AnimeSummary anime) onTap;
  final bool shrinkWrap;
  final double minTileWidth;
  final ScrollController? controller;
  final bool showSource;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            (constraints.maxWidth / minTileWidth).floor().clamp(2, 7);
        return GridView.builder(
          controller: controller,
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.lg,
            childAspectRatio: 0.56,
          ),
          itemBuilder: (context, index) {
            final anime = items[index];
            return AnimeCard(
              anime: anime,
              showSource: showSource,
              onTap: () => onTap(anime),
            );
          },
        );
      },
    );
  }
}
