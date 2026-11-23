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
    // 让"清空"按钮随输入即时出现/消失
    _controller.addListener(_onTextChanged);
    // 开发期：自动化截图时预先灌入查询词
    final preset = DevEnv.initialQuery;
    if (preset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submit(preset);
      });
    }
  }

  /// 输入框是否显示"清空"按钮（只在需要切换时重建，避免逐字符重建整页）。
  bool _showClear = false;

  void _onTextChanged() {
    if (!mounted) return;
    final show = _controller.text.isNotEmpty;
    if (show != _showClear) setState(() => _showClear = show);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
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
      _showClear = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(catalogRepositoryProvider);
    final theme = Theme.of(context);

    return PageScaffold(
      title: '搜索',
      subtitle: '同时搜索 B 站与 AniList（中文/西文都可以），并用日文原名补齐季',
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
              suffixIcon: !_showClear
                  ? null
                  : IconButton(
                      tooltip: '清空',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _controller.clear();
                        _keyword = '';
                        _showClear = false;
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
              description: '支持中文名、日文原名与英文名；结果会标注来源。若没搜到，试试日文原名或罗马音。',
              compact: true,
              action: Text(
                '当前阶段：S2 元数据层',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ] else ...[
            SectionHeader(
              title: '「$_keyword」的结果',
              description: 'B 站 + AniList 合并，标注来源',
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
