import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/app_providers.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/page_scaffold.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/daos.dart';
import '../catalog/widgets/cover_image.dart';

/// 追番页：想看 / 在看 / 看过 三态。
///
/// 数据来自本地 favorites 表，点卡片进详情，菜单里可改分类或取消追番。
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return DefaultTabController(
      length: FavoriteCategory.values.length,
      child: PageScaffold(
        title: '追番',
        subtitle: '想看、在看、看过 —— 全部保存在本机',
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: '读取追番列表失败',
        description: '$error',
      ),
      data: (items) {
        final filtered =
            items.where((e) => e.category == category.key).toList();
        if (filtered.isEmpty) {
          return SingleChildScrollView(
            child: EmptyState(
              icon: Icons.bookmark_add_outlined,
              title: '「${category.label}」还没有番剧',
              description: '在详情页点「追番」就能加到这里',
              compact: true,
              action: FilledButton.tonal(
                onPressed: () => context.go('/browse'),
                child: const Text('去索引找番'),
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 160).floor().clamp(2, 7);
            return GridView.builder(
              itemCount: filtered.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.lg,
                childAspectRatio: 0.56,
              ),
              itemBuilder: (context, index) =>
                  _FavoriteCard(item: filtered[index], category: category),
            );
          },
        );
      },
    );
  }
}

class _FavoriteCard extends ConsumerWidget {
  const _FavoriteCard({required this.item, required this.category});

  final FavoriteEntry item;
  final FavoriteCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final internalId = '${item.source}:${item.bangumiId}';

    Future<void> move(String value) async {
      final dao = ref.read(favoritesDaoProvider);
      if (value == '__remove__') {
        await dao.remove(item.bangumiId, source: item.source);
      } else {
        await dao.upsert(
          bangumiId: item.bangumiId,
          title: item.title,
          cover: item.cover,
          category: FavoriteCategory.fromKey(value),
          totalEpisodes: item.totalEpisodes,
          source: item.source,
        );
      }
    }

    return Stack(
      children: [
        InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: () => context.push(
            '/bangumi/${Uri.encodeComponent(internalId)}',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadius.mdAll,
                  child: CoverImage(
                    url: item.cover,
                    fit: BoxFit.cover,
                    radius: 0,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                item.totalEpisodes > 0
                    ? '共 ${item.totalEpisodes} 话'
                    : category.label,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.more_vert_rounded, size: 18),
            onSelected: move,
            itemBuilder: (context) => [
              for (final target in FavoriteCategory.values)
                PopupMenuItem(
                  value: target.key,
                  child: Text(
                    target == category ? '${target.label}（当前）' : target.label,
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: '__remove__', child: Text('取消追番')),
            ],
          ),
        ),
      ],
    );
  }
}
