import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/app_providers.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/page_scaffold.dart';
import '../../app/widgets/section_header.dart';
import '../../core/constants/app_info.dart';
import '../catalog/catalog_providers.dart';
import '../catalog/data/catalog_models.dart';
import '../catalog/widgets/anime_card.dart';

/// 首页：本季新番 + 热门推荐 + 继续观看。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recentHistoryProvider);
    final ongoing = ref.watch(homeOngoingProvider);
    final topRated = ref.watch(homeTopRatedProvider);

    return PageScaffold(
      title: '首页',
      subtitle: '数据来自 B 站与 AniList',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: () {
            ref.invalidate(homeOngoingProvider);
            ref.invalidate(homeTopRatedProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeroBanner(),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: '正在连载',
            description: '按追番人数',
            trailing: TextButton(
              onPressed: () => context.go('/browse'),
              child: const Text('查看全部'),
            ),
          ),
          _CatalogBlock(
            page: ongoing,
            onRetry: () => ref.invalidate(homeOngoingProvider),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: '高分推荐',
            description: '按评分',
            trailing: TextButton(
              onPressed: () => context.go('/browse'),
              child: const Text('查看全部'),
            ),
          ),
          _CatalogBlock(
            page: topRated,
            onRetry: () => ref.invalidate(homeTopRatedProvider),
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
              return Column(
                children: [
                  for (final item in items.take(3))
                    _HistoryRow(
                      title: item.title.isEmpty ? '番剧 ${item.bangumiId}' : item.title,
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

/// 一个数据区块：加载骨架 / 错误重试 / 网格。
class _CatalogBlock extends StatelessWidget {
  const _CatalogBlock({required this.page, required this.onRetry});

  final AsyncValue<CatalogPage> page;
  final VoidCallback onRetry;

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
        return AnimeGrid(
          items: data.items.take(12).toList(),
          onTap: (anime) =>
              context.push('/bangumi/${Uri.encodeComponent(anime.id)}'),
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

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
          decoration: BoxDecoration(
            borderRadius: AppRadius.xlAll,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary.withValues(alpha: 0.28), scheme.surface],
            ),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!compact) ...[
                ClipRRect(
                  borderRadius: AppRadius.lgAll,
                  child: Image.asset(
                    'assets/branding/app_icon.png',
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('开始追番', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${AppInfo.displayName} ${AppInfo.version} · '
                      'B 站 + AniList 双源元数据已接通，播放器在 S3 接入。',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.go('/browse'),
                          icon: const Icon(Icons.explore_outlined, size: 18),
                          label: const Text('浏览索引'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/search'),
                          icon: const Icon(Icons.search_rounded, size: 18),
                          label: const Text('搜索番剧'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
