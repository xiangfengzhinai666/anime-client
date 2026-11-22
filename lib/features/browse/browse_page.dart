import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/widgets/page_scaffold.dart';
import '../../app/widgets/placeholder_grid.dart';
import '../../app/widgets/section_header.dart';

/// 索引页：分类 / 年份 / 地区 / 排序的筛选区 + 结果网格。
///
/// S1 只做筛选区结构与网格占位；筛选参数与分页在 S2 接入。
class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  static const List<String> _filters = ['全部', '2026', '日本', 'TV', '连载中'];
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PageScaffold(
      title: '索引',
      subtitle: '按分类、年份、地区浏览番剧',
      actions: [
        IconButton(
          tooltip: '筛选（S2 接入）',
          onPressed: () => _notReady(context),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < _filters.length; i++)
                ChoiceChip(
                  label: Text(_filters[i]),
                  selected: _selected == i,
                  onSelected: (_) => setState(() => _selected = i),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: '番剧列表',
            description: '第 $_selected 组筛选（仅前端状态）',
            trailing: Text('0 部', style: theme.textTheme.bodySmall),
          ),
          const PlaceholderGrid(count: 12, minTileWidth: 128),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '番剧库将在 S2 接入：按分类、年份、地区筛选并分页加载',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _notReady(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('筛选面板将在 S2 接入')),
    );
  }
}
