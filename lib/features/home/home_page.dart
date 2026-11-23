import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/app_providers.dart';
import '../../core/storage/app_database.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/page_scaffold.dart';
import '../../app/widgets/section_header.dart';
import '../catalog/catalog_providers.dart';
import '../catalog/data/catalog_merge.dart';
import '../catalog/data/catalog_models.dart';
import '../catalog/widgets/anime_card.dart';
import '../catalog/widgets/hero_carousel.dart';


/// 首页：轮播（高分老番）+ 当季新番（中文标题）+ 高分推荐 + 继续观看。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recentHistoryProvider);
    final season = ref.watch(homeSeasonProvider);
    final classic = ref.watch(homeClassicProvider);

    void open(AnimeSummary anime) =>
        context.push('/bangumi/${Uri.encodeComponent(anime.id)}');

    return PageScaffold(
      title: '首页',
      subtitle: '当季新番来自次元城（中文标题），老番轮播与推荐来自 B 站',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: () {
            ref.invalidate(homeSeasonProvider);
            ref.invalidate(homePopularProvider);
            ref.invalidate(homeClassicProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CarouselBlock(
            page: classic,
            onOpen: open,
            onRetry: () => ref.invalidate(homeClassicProvider),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: '当季新番',
            description: '中文标题 · 更新进度',
            trailing: TextButton(
              onPressed: () => context.go('/browse'),
              child: const Text('查看全部'),
            ),
          ),
          _CatalogBlock(
            page: season,
            onRetry: () => ref.invalidate(homeSeasonProvider),
            onOpen: open,
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: '日漫老番推荐',
            description: '已完结 · 按追番人数',
            trailing: TextButton(
              onPressed: () => context.go('/browse'),
              child: const Text('查看全部'),
            ),
          ),
          _CatalogBlock(
            page: classic,
            onRetry: () => ref.invalidate(homeClassicProvider),
            onOpen: open,
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: '继续观看', description: '本地记录'),
          history.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => EmptyState(
              icon: Icons.error_outline_rounded,
              title: '读取观看记录失败',
              description: '$e',
              compact: true,
            ),
            data: (items) {
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.play_circle_outline_rounded,
                  title: '还没有观看记录',
                  description: '看过的番剧会出现在这里，方便直接续播',
                  compact: true,
                  action: FilledButton.tonal(
                    onPressed: () => context.go('/browse'),
                    child: const Text('去索引看看'),
                  ),
                );
              }
              // 同一部番只保留"最近看的那一集"
              final latest = latestPerShow(items);
              return Column(
                children: [
                  for (final item in latest.take(3))
                    _HistoryRow(
                      title: item.title.isEmpty
                          ? '番剧 ${item.bangumiId}'
                          : item.title,
                      episode: item.episode,
                      progress: item.durationSeconds == 0
                          ? 0
                          : item.positionSeconds / item.durationSeconds,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 轮播区：加载中给骨架，失败给可重试的提示。
class _CarouselBlock extends StatelessWidget {
  const _CarouselBlock({
    required this.page,
    required this.onOpen,
    required this.onRetry,
  });

  final AsyncValue<CatalogPage> page;
  final void Function(AnimeSummary) onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return page.when(
      loading: () => Container(
        height: 300,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.xlAll,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      error: (error, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: '推荐加载失败',
        description: '$error',
        compact: true,
        action: FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
      ),
      data: (data) {
        if (data.items.isEmpty) return const SizedBox.shrink();
        // 轮播只要"好看的老番"：排除超长篇（柯南/海贼）与低分作
        final pool = data.items.where((a) {
          final eps = a.totalEpisodes;
          final tooLong = eps != null && eps > 150;
          final lowScore = (a.score ?? 0) < 8.0;
          return !tooLong && !lowScore;
        }).toList();
        return HeroCarousel(
          items: pool.length >= 3 ? pool : data.items,
          onOpen: onOpen,
        );
      },
    );
  }
}

/// 一个数据区块：加载骨架 / 错误重试 / 网格。
class _CatalogBlock extends StatelessWidget {
  const _CatalogBlock({
    required this.page,
    required this.onRetry,
    required this.onOpen,
  });

  final AsyncValue<CatalogPage> page;
  final VoidCallback onRetry;
  final void Function(AnimeSummary) onOpen;

  @override
  Widget build(BuildContext context) {
    return page.when(
      loading: () => const _SkeletonGrid(),
      error: (error, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: '数据加载失败',
        description: '$error',
        compact: true,
        action: FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
      ),
      data: (data) {
        if (data.items.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            title: '这里还没有内容',
            compact: true,
          );
        }
        // 同系列只留第一部（鬼灭 5 条连排太丑），再取两行
        final distinct = CatalogMerger.distinctSeries(data.items);
        return AnimeGrid(
          items: distinct.take(14).toList(),
          onTap: onOpen,
        );
      },
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 150).floor().clamp(2, 7);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: columns,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.lg,
            childAspectRatio: 0.56,
          ),
          itemBuilder: (_, _) => DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: scheme.outlineVariant),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.title,
    required this.episode,
    required this.progress,
  });

  final String title;
  final int episode;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: AppSpacing.itemGap,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(Icons.play_arrow_rounded,
                color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '第 $episode 集 · ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

}

/// 同一部番只保留最近的一条观看记录（输入需按时间倒序）。
List<HistoryEntry> latestPerShow(List<HistoryEntry> items) {
  final seen = <int>{};
  final out = <HistoryEntry>[];
  for (final item in items) {
    if (seen.add(item.bangumiId)) out.add(item);
  }
  return out;
}
