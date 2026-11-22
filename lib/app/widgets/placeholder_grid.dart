import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 骨架占位卡片：用于「数据未接入」的网格位置。
///
/// 视觉上用低对比虚线块，明确表达"这里以后会有内容"，而不是空白。
class PlaceholderTile extends StatelessWidget {
  const PlaceholderTile({super.key, this.label = '待接入'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined,
                size: 22, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自适应网格：按可用宽度决定列数（2~6 列）。
class PlaceholderGrid extends StatelessWidget {
  const PlaceholderGrid({
    super.key,
    this.count = 6,
    this.minTileWidth = 132,
  });

  final int count;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minTileWidth)
            .floor()
            .clamp(2, 6);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 3 / 4,
          ),
          itemBuilder: (context, index) => const PlaceholderTile(),
        );
      },
    );
  }
}
