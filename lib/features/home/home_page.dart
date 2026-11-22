import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/app_providers.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/page_scaffold.dart';
import '../../app/widgets/placeholder_grid.dart';
import '../../app/widgets/section_header.dart';
import '../../core/constants/app_info.dart';

/// 首页：推荐位 + 继续观看 + 本周更新。
///
/// S1 阶段只有结构，数据来自 S2（番剧接口）与 S5（历史）。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recentHistoryProvider);

    return PageScaffold(
      title: '首页',
      subtitle: '数据接入后展示本季推荐与更新',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('数据源将在 S2 接入')),
          ),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeroBanner(),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: '继续观看',
            description: '本地记录',
            trailing: history.maybeWhen(
              data: (items) => items.isEmpty
                  ? const SizedBox.shrink()
                  : Text('${items.length} 集',
                      style: Theme.of(context).textTheme.bodySmall),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
          history.when(
            loading: () => const _LoadingBlock(height: 96),
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
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: '本周更新', description: '占位，等待数据接入'),
          const PlaceholderGrid(count: 6),
          const SizedBox(height: AppSpacing.xl),
          _StageNote(),
        ],
      ),
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
                      '${AppInfo.displayName} ${AppInfo.version} · ${AppInfo.stage} 骨架已就位，'
                      '番剧数据将在下一阶段接入。',
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
                Text('第 $episode 集 · ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}

class _StageNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.construction_rounded,
            size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '当前阶段：${AppInfo.stage} 骨架。番剧列表、详情、播放器依次在 S2–S4 接入。',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
