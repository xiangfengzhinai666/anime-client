import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/widgets/page_scaffold.dart';
import '../../app/widgets/section_header.dart';
import '../catalog/catalog_providers.dart';
import '../catalog/widgets/paged_grid_view.dart';

/// 索引页：年份 / 排序 / 状态筛选 + 分页网格。
///
/// 数据源为 B 站番剧索引（AniList 没有这类中文运营维度）。
class BrowsePage extends ConsumerStatefulWidget {
  const BrowsePage({super.key});

  @override
  ConsumerState<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends ConsumerState<BrowsePage> {
  static const List<(String, String)> _orders = [
    ('追番人数', '3'),
    ('评分', '2'),
    ('最新', '0'),
  ];

  static const List<(String, int)> _finish = [
    ('全部', -1),
    ('连载中', 0),
    ('已完结', 1),
  ];

  String _order = '3';
  int _isFinish = -1;

  String get _token => '$_order|$_isFinish';

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(catalogRepositoryProvider);

    return PageScaffold(
      title: '索引',
      subtitle: '按排序、连载状态浏览（年份筛选接口不支持，已移除）',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterRow(
            label: '排序',
            options: [for (final (l, v) in _orders) (l, v)],
            selected: _order,
            onSelected: (v) => setState(() => _order = v as String),
          ),
          _FilterRow(
            label: '状态',
            options: [for (final (l, v) in _finish) (l, v)],
            selected: _isFinish,
            onSelected: (v) => setState(() => _isFinish = v as int),
          ),
          const SizedBox(height: AppSpacing.md),
          const SectionHeader(title: '番剧列表', description: '来源：B站'),
          PagedGridView(
            resetToken: _token,
            fetch: (page) => repo.browse(
              page: page,
              order: _order,
              isFinish: _isFinish,
            ),
            onTap: (anime) =>
                context.push('/bangumi/${Uri.encodeComponent(anime.id)}'),
            emptyTitle: '这个筛选条件下没有番剧',
            emptyDescription: '换一组年份或状态试试',
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<(String, Object)> options;
  final Object selected;
  final ValueChanged<Object> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(label, style: theme.textTheme.bodySmall),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (text, value) in options)
                  ChoiceChip(
                    label: Text(text),
                    selected: selected == value,
                    onSelected: (_) => onSelected(value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
