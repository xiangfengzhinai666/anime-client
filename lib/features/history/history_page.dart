import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/app_providers.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/page_scaffold.dart';
import '../../core/storage/app_database.dart';
import '../catalog/widgets/cover_image.dart';
import 'history_utils.dart';

/// 观看历史页。
///
/// - 按番去重，只显示最近看的那一集；
/// - 点一行 = 从那一集继续播（用记录里的 source 拼路由）；
/// - 单条删除 / 一键清空。
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recentHistoryProvider);

    // 这个页面在 shell 之外，需要自己给 Scaffold（否则背景是白的）
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: PageScaffold(
        scrollable: false,
      title: '观看历史',
      subtitle: '只存在本机，按番去重',
      actions: [
        IconButton(
          tooltip: '清空历史',
          onPressed: () => _confirmClear(context, ref),
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
      ],
      child: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: '读取历史失败',
          description: '$error',
        ),
        data: (items) {
          final latest = latestPerShow(items);
          if (latest.isEmpty) {
            return EmptyState(
              icon: Icons.history_rounded,
              title: '还没有观看记录',
              description: '看过的番会出现在这里，并按番只保留最近一集',
              action: FilledButton.tonal(
                onPressed: () => context.go('/browse'),
                child: const Text('去索引看看'),
              ),
            );
          }
          return ListView.separated(
            itemCount: latest.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _HistoryRow(item: latest[index], ref: ref),
          );
          },
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空观看历史？'),
        content: const Text('只会删除本机的观看记录，不影响收藏。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(historyDaoProvider).clearAll();
    }
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item, required this.ref});

  final HistoryEntry item;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = item.durationSeconds == 0
        ? 0.0
        : (item.positionSeconds / item.durationSeconds).clamp(0.0, 1.0);
    final internalId = '${item.source}:${item.bangumiId}';

    return InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: () => context.push(
        '/watch/${Uri.encodeComponent(internalId)}/${item.episode}',
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 54,
              child: ClipRRect(
                borderRadius: AppRadius.smAll,
                child: CoverImage(url: item.cover, fit: BoxFit.cover, radius: 0),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isEmpty ? '番剧 ${item.bangumiId}' : item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '第 ${item.episode} 集'
                    '${item.episodeTitle.isEmpty ? '' : ' · ${item.episodeTitle}'}'
                    ' · ${(progress * 100).round()}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: AppRadius.pillAll,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '更多',
              onSelected: (value) async {
                if (value == 'delete') {
                  await ref
                      .read(historyDaoProvider)
                      .removeEpisode(item.bangumiId, item.episode);
                } else if (value == 'detail') {
                  context.push(
                    '/bangumi/${Uri.encodeComponent(internalId)}',
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'detail', child: Text('查看详情')),
                PopupMenuItem(value: 'delete', child: Text('删除这条记录')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
