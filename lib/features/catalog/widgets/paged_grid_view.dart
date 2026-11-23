import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/widgets/empty_state.dart';
import '../data/catalog_models.dart';
import 'anime_card.dart';

/// 带「加载更多」的分页网格。
///
/// 搜素/索引共用：调用方只提供 `fetch(page)`，其余状态（首页/加载中/
/// 空结果/错误/是否还有下一页）在这里统一处理。
class PagedGridView extends StatefulWidget {
  const PagedGridView({
    super.key,
    required this.fetch,
    required this.onTap,
    this.showSource = false,
    this.emptyTitle = '没有结果',
    this.emptyDescription = '换个关键词或筛选条件试试',
    this.footerPadding = const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    this.resetToken,
  });

  final Future<CatalogPage> Function(int page) fetch;
  final void Function(AnimeSummary anime) onTap;
  final bool showSource;
  final String emptyTitle;
  final String emptyDescription;
  final EdgeInsets footerPadding;

  /// 变化时重置列表（换关键词 / 换筛选）。不要用函数对象比较，
  /// 因为闭包每次 build 都是新实例，会导致无限重置。
  final Object? resetToken;

  @override
  State<PagedGridView> createState() => PagedGridViewState();
}

class PagedGridViewState extends State<PagedGridView> {
  final List<AnimeSummary> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  @override
  void didUpdateWidget(PagedGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken) {
      reset();
    }
  }

  void reset() {
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    _loadNext();
  }

  Future<void> _loadNext() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _page += 1;
        _items.addAll(result.items);
        _hasMore = result.hasMore && result.items.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      if (_loading) return const _GridSkeleton();
      if (_error != null) {
        return EmptyState(
          icon: Icons.cloud_off_rounded,
          title: '加载失败',
          description: '$_error',
          action: FilledButton.tonal(
            onPressed: _loadNext,
            child: const Text('重试'),
          ),
        );
      }
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: widget.emptyTitle,
        description: widget.emptyDescription,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimeGrid(
          items: _items,
          onTap: widget.onTap,
          shrinkWrap: true,
          showSource: widget.showSource,
        ),
        Padding(
          padding: widget.footerPadding,
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _error != null
                    ? TextButton.icon(
                        onPressed: _loadNext,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('加载失败，点击重试'),
                      )
                    : _hasMore
                        ? OutlinedButton(
                            onPressed: _loadNext,
                            child: const Text('加载更多'),
                          )
                        : Text(
                            '已经到底了 · 共 ${_items.length} 部',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
          ),
        ),
      ],
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 150).floor().clamp(2, 7);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: columns * 2,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.lg,
            childAspectRatio: 0.56,
          ),
          itemBuilder: (context, index) => DecoratedBox(
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
