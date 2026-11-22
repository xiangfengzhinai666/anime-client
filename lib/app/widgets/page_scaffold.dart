import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 页面骨架：统一标题区 + 内容区边距 + 滚动行为。
///
/// 所有一级页面都用它，保证标题字号、间距、滚动一致。
class PageScaffold extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = child ?? const SizedBox.shrink();

    return Padding(
      padding: padding,
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
                    Text(title, style: theme.textTheme.headlineMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
                Row(mainAxisSize: MainAxisSize.min, children: actions),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: scrollable
                ? SingleChildScrollView(
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
