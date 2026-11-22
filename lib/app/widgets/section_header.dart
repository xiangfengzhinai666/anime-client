import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 区块标题：左侧标题 + 可选说明 + 右侧动作。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.description,
  });

  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          if (description != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(description!, style: theme.textTheme.bodySmall),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
