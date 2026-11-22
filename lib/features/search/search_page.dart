import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/page_scaffold.dart';
import '../../app/widgets/section_header.dart';

/// 搜索页：搜索框 + 热门关键词 + 结果区。
///
/// S1：输入与提交可用（会记录最近关键词到内存），真实检索在 S2 接入。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const List<String> _hotKeywords = [
    '葬送的芙莉莲',
    '无职转生',
    '孤独摇滚',
    '我推的孩子',
    '药屋少女的呢喃',
  ];

  final TextEditingController _controller = TextEditingController();
  final List<String> _recent = <String>[];
  bool _submitted = false;

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
      _submitted = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$text」的检索接口将在 S2 接入')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PageScaffold(
      title: '搜索',
      subtitle: '番剧名 / 原名 / 别名',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索番剧，回车确认',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _controller.clear();
                        _submitted = false;
                      }),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
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
            const SizedBox(height: AppSpacing.xl),
          ],
          const SectionHeader(title: '热门搜索', description: '本地占位'),
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
            icon: _submitted
                ? Icons.hourglass_empty_rounded
                : Icons.search_off_rounded,
            title: _submitted ? '检索接口尚未接入' : '输入关键词开始搜索',
            description: _submitted
                ? '关键词已记录，S2 接入后会直接返回结果'
                : '支持番剧名、原名与别名；S2 接入搜索接口后这里显示结果网格',
            compact: true,
            action: _submitted
                ? Text(
                    '当前阶段：S1 骨架',
                    style: theme.textTheme.bodySmall,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
