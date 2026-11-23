import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/utils/dev_env.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/page_scaffold.dart';
import '../../app/widgets/section_header.dart';
import '../catalog/catalog_providers.dart';
import '../catalog/widgets/paged_grid_view.dart';

/// 搜索页：中文走 B 站，拉丁字母同时查 AniList。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const List<String> _hotKeywords = [
    '葬送的芙莉莲',
    '无职转生',
    '孤独摇滚',
    '我推的孩子',
    '药屋少女的呢喃',
    '进击的巨人',
  ];

  final TextEditingController _controller = TextEditingController();
  final List<String> _recent = <String>[];
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    // 开发期：自动化截图时预先灌入查询词
    final preset = DevEnv.initialQuery;
    if (preset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submit(preset);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? keyword]) {
    final text = (keyword ?? _controller.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _controller.text = text;
      _recent.remove(text);
      _recent.insert(0, text);
      if (_recent.length > 8) _recent.removeLast();
      _keyword = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(catalogRepositoryProvider);
    final theme = Theme.of(context);

    return PageScaffold(
      title: '搜索',
      subtitle: '中文名搜 B 站，罗马音/英文同时搜 AniList',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.search,
            autofocus: false,
            decoration: InputDecoration(
              hintText: '输入番剧名，回车搜索',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _controller.clear();
                        _keyword = '';
                      }),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_keyword.isEmpty) ...[
            if (_recent.isNotEmpty) ...[
              SectionHeader(
                title: '最近搜索',
                trailing: TextButton(
                  onPressed: () => setState(() => _recent.clear()),
                  child: const Text('清空'),
                ),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final keyword in _recent)
                    ActionChip(
                      label: Text(keyword),
                      onPressed: () => _submit(keyword),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            const SectionHeader(title: '热门搜索'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final keyword in _hotKeywords)
                  ActionChip(
                    label: Text(keyword),
                    onPressed: () => _submit(keyword),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            EmptyState(
              icon: Icons.search_off_rounded,
              title: '输入关键词开始搜索',
              description: '支持中文名、日文原名与英文名；结果会标注来源',
              compact: true,
              action: Text(
                '当前阶段：S2 元数据层',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ] else ...[
            SectionHeader(
              title: '「$_keyword」的结果',
              description: '中文名 → B站，罗马音 → AniList',
            ),
            PagedGridView(
              resetToken: _keyword,
              showSource: true,
              fetch: (page) => repo.search(_keyword, page: page),
              onTap: (anime) =>
                  context.push('/bangumi/${Uri.encodeComponent(anime.id)}'),
              emptyTitle: '没有找到「$_keyword」',
              emptyDescription: '换个关键词，或试试日文原名 / 罗马音',
            ),
          ],
        ],
      ),
    );
  }
}
