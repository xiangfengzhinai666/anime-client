import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/app_providers.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/page_scaffold.dart';
import '../../core/storage/daos.dart';

/// 追番页：想看 / 在看 / 看过 三态。
///
/// 数据来自本地 favorites 表（S5 接入追番操作入口，S1 先把读链路打通）。
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return DefaultTabController(
      length: FavoriteCategory.values.length,
      child: PageScaffold(
        title: '追番',
        subtitle: '想看、在看、看过，全部保存在本机',
        scrollable: false,
        actions: [
          favorites.maybeWhen(
            data: (items) => Text(
              '${items.length} 部',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              tabs: [
                for (final category in FavoriteCategory.values)
                  Tab(text: category.label),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: TabBarView(
                children: [
                  for (final category in FavoriteCategory.values)
                    _CategoryView(category: category),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryView extends ConsumerWidget {
  const _CategoryView({required this.category});

  final FavoriteCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return favorites.when(
      loading: () => Column(
        children: List.generate(
          3,
          (index) => Container(
            height: 72,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      ),
      error: (error, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: '读取追番列表失败',
        description: '$error',
      ),
      data: (items) {
        final filtered = items.where((e) => e.category == category.key).toList();
        if (filtered.isEmpty) {
          return SingleChildScrollView(
            child: EmptyState(
              icon: Icons.bookmark_add_outlined,
              title: '「${category.label}」还没有番剧',
              description: 'S5 接入追番操作后，在详情页点收藏即可出现在这里',
              compact: true,
              action: FilledButton.tonal(
                onPressed: () => context.go('/browse'),
                child: const Text('去索引找番'),
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final item = filtered[index];
            return ListTile(
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.mdAll,
              ),
              tileColor: Theme.of(context).colorScheme.surface,
              leading: Container(
                width: 40,
                height: 54,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.smAll,
                ),
                child: const Icon(Icons.movie_outlined, size: 18),
              ),
              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${item.totalEpisodes} 话 · ${category.label}'),
            );
          },
        );
      },
    );
  }
}
