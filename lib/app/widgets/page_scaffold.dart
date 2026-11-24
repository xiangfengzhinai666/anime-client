import 'package:flutter/material.dart';

import '../../core/utils/dev_env.dart';
import '../theme/app_tokens.dart';

/// 页面骨架：统一标题区 + 内容区边距 + 滚动行为。
///
/// 所有一级页面都用它，保证标题字号、间距、滚动一致。
class PageScaffold extends StatefulWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.child,
    this.scrollable = true,
    this.padding = AppSpacing.page,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? child;
  final bool scrollable;
  final EdgeInsets padding;

  @override
  State<PageScaffold> createState() => _PageScaffoldState();
}

class _PageScaffoldState extends State<PageScaffold> {
  late final ScrollController _controller =
      ScrollController(initialScrollOffset: DevEnv.initialScrollOffset);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = widget.child ?? const SizedBox.shrink();

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: theme.textTheme.headlineMedium),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(widget.subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (widget.actions.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
                Row(mainAxisSize: MainAxisSize.min, children: widget.actions),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: widget.scrollable
                ? SingleChildScrollView(
                    controller: _controller,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      child: body,
                    ),
                  )
                : body,
          ),
        ],
      ),
    );
  }
}
