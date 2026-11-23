import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/section_header.dart';
import 'catalog_providers.dart';
import 'data/catalog_models.dart';
import 'data/source_match.dart';
import 'widgets/cover_image.dart';
import 'widgets/episode_card_grid.dart';

/// 番剧详情页（全屏二级页，路由 `/bangumi/:id`）。
///
/// 数据策略：主数据来自 B 站/AniList（带 6 小时缓存），
/// 角色表由 AniList 异步补充（失败不影响主内容）。
/// 播放任意源：次元城条目直接播；其它源自动找同名可播放条目再播。
///
/// 这就是"多源"的最小形态：用户只管点「从第 1 集开始」，由应用去找谁能播。
Future<void> _playResolved(
  BuildContext context,
  WidgetRef ref,
  AnimeDetail detail,
  int episode,
) async {
  final summary = detail.summary;
  if (summary.source == CatalogSource.cycani) {
    context.push('/watch/${Uri.encodeComponent(summary.id)}/$episode');
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(
      content: Text('正在寻找可播放的源…'),
      duration: Duration(seconds: 2),
    ),
  );

  String? targetId;
  // 中文名 + 日文原名，各自展开成多个查询变体（去标点/去季标/截短…）
  final queries = <String>{
    ...titleQueryVariants(summary.title),
    ...titleQueryVariants(summary.subtitle),
  };

  final found = <AnimeSummary>[];
  for (final query in queries) {
    try {
      final page =
          await ref.read(cycaniCatalogProvider).search(query, pageSize: 8);
      found.addAll(page.items);
    } catch (_) {
      // 换下一个查询词继续
    }
    // 已经收集到一些结果就先打分；分数足够高就不必再放宽
    if (found.length >= 3) {
      final best = pickBestCandidate(summary, found);
      if (best != null && matchScore(summary, best) >= 8) {
        targetId = best.id;
        break;
      }
    }
  }

  if (targetId == null) {
    final best = pickBestCandidate(summary, found);
    if (best != null) targetId = best.id;
  }

  if (!context.mounted) return;
  if (targetId == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('没有找到可播放的源（次元城可能没有这部）')),
    );
    return;
  }
  context.push('/watch/${Uri.encodeComponent(targetId)}/$episode');
}

class AnimeDetailPage extends ConsumerWidget {
  const AnimeDetailPage({super.key, required this.internalId});

  final String internalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(animeDetailProvider(internalId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          detail.maybeWhen(
            data: (d) => d.summary.title,
            orElse: () => '番剧详情',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(animeDetailProvider(internalId));
              ref.invalidate(animeEnrichmentProvider(internalId));
            },
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: '加载失败',
                description: '$error',
                action: FilledButton.tonal(
                  onPressed: () =>
                      ref.invalidate(animeDetailProvider(internalId)),
                  child: const Text('重试'),
                ),
              ),
            ),
          ),
        ),
        data: (data) => _DetailBody(detail: data, internalId: internalId),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, required this.internalId});

  final AnimeDetail detail;
  final String internalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = detail.summary;

    return SingleChildScrollView(
      padding: AppSpacing.page,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                detail: detail,
                playable: detail.summary.source == CatalogSource.cycani,
                onPlay: (index) =>
                    _playResolved(context, ref, detail, index),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (detail.synopsis.isNotEmpty) ...[
                const SectionHeader(title: '简介'),
                Text(detail.synopsis, style: theme.textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (summary.tags.isNotEmpty) ...[
                const SectionHeader(title: '标签'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final tag in summary.tags) Chip(label: Text(tag)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              SectionHeader(
                title: '剧集',
                description: detail.episodes.isEmpty
                    ? '该源没有提供分集'
                    : '共 ${detail.episodes.length} 集',
              ),
              if (detail.episodes.isEmpty)
                EmptyState(
                  icon: Icons.playlist_remove_rounded,
                  title: '暂无分集信息',
                  description: summary.source == CatalogSource.anilist
                      ? 'AniList 只提供总集数，分集信息需要 B 站源'
                      : '换个源或稍后重试',
                  compact: true,
                )
              else
                EpisodeCardGrid(
                  episodes: detail.episodes,
                  meta: ref
                          .watch(episodeMetaProvider(internalId))
                          .valueOrNull ??
                      const {},
                  fallbackCover: detail.summary.cover,
                  playable: detail.summary.source == CatalogSource.cycani,
                  onPlay: (index) =>
                      _playResolved(context, ref, detail, index),
                ),
                if (detail.summary.source != CatalogSource.cycani)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      '这条来自 ${detail.summary.source.label}：点播放会自动寻找可播放的源。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              const SizedBox(height: AppSpacing.xl),
              _EnrichmentSection(internalId: internalId),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.detail,
    required this.onPlay,
    required this.playable,
  });

  final AnimeDetail detail;
  final void Function(int episode)? onPlay;
  final bool playable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = detail.summary;
    final meta = <String>[
      if (summary.year != null) '${summary.year}',
      if (detail.areas.isNotEmpty) detail.areas.join('/'),
      if ((summary.totalEpisodes ?? 0) > 0) '${summary.totalEpisodes} 话',
      if (summary.status.isNotEmpty) summary.status,
      '来源 ${summary.source.label}',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoverImage(
          url: summary.cover,
          width: 184,
          height: 246,
          radius: AppRadius.lg,
        ),
        const SizedBox(width: AppSpacing.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary.title, style: theme.textTheme.displaySmall),
              if (detail.originalTitle.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(detail.originalTitle, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (summary.score != null)
                    _Pill(
                      icon: Icons.star_rounded,
                      text: summary.score!.toStringAsFixed(1),
                      color: const Color(0xFFFFB454),
                    ),
                  Text(meta.join(' · '), style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.xs,
                children: [
                  if ((detail.viewCount ?? 0) > 0)
                    _Stat(icon: Icons.visibility_outlined, value: detail.viewCount!),
                  if ((detail.followerCount ?? 0) > 0)
                    _Stat(icon: Icons.favorite_border_rounded, value: detail.followerCount!),
                  if ((detail.danmakuCount ?? 0) > 0)
                    _Stat(icon: Icons.subtitles_outlined, value: detail.danmakuCount!),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: detail.episodes.isEmpty
                        ? null
                        : () => onPlay?.call(detail.episodes.first.index),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      detail.episodes.isEmpty ? '暂无剧集' : '从第 1 集开始',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('追番功能在 S5 接入')),
                    ),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('追番'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(_format(value), style: theme.textTheme.bodySmall),
      ],
    );
  }

  static String _format(int value) {
    if (value >= 100000000) return '${(value / 100000000).toStringAsFixed(1)} 亿';
    if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)} 万';
    return '$value';
  }
}

class _EnrichmentSection extends ConsumerWidget {
  const _EnrichmentSection({required this.internalId});

  final String internalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrichment = ref.watch(animeEnrichmentProvider(internalId));
    final theme = Theme.of(context);

    return enrichment.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (extra) {
        if (extra == null) return const SizedBox.shrink();
        if (extra.characters.isEmpty && extra.synopsis.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'AniList 补充',
              description: extra.summary.score == null
                  ? ''
                  : '评分 ${extra.summary.score!.toStringAsFixed(1)}',
            ),
            if (extra.characters.isNotEmpty)
              SizedBox(
                height: 148,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: extra.characters.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final c = extra.characters[index];
                    return SizedBox(
                      width: 92,
                      child: Column(
                        children: [
                          CoverImage(
                            url: c.image,
                            width: 72,
                            height: 72,
                            radius: 36,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            c.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (extra.characters.isEmpty && extra.synopsis.isNotEmpty) ...[
              Text(extra.synopsis, style: theme.textTheme.bodyLarge),
            ],
          ],
        );
      },
    );
  }
}
