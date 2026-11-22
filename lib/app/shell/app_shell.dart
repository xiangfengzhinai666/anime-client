import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../dev/screenshot.dart';
import '../routing/app_tabs.dart';
import '../theme/app_tokens.dart';

/// 应用外壳：宽屏用左侧导航栏，窄屏用底部导航栏。
///
/// 内容区被 `RepaintBoundary` 包住，既是性能边界，也是自动化截图的抓取目标。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// 断点：低于此宽度切到底部导航。
  static const double wideBreakpoint = 900;

  void _select(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      // 再次点击当前 tab 时回到该 tab 的初始页（常见交互习惯）
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: appShotKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= wideBreakpoint;

          final content = Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
              child: navigationShell,
            ),
          );

          if (!isWide) {
            return Scaffold(
              body: content,
              bottomNavigationBar: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) => _select(context, index),
                destinations: [
                  for (final tab in AppTab.values)
                    NavigationDestination(
                      icon: Icon(tab.icon),
                      selectedIcon: Icon(tab.selectedIcon),
                      label: tab.label,
                      tooltip: tab.label,
                    ),
                ],
              ),
            );
          }

          return Scaffold(
            body: Row(
              children: [
                _SideRail(
                  currentIndex: navigationShell.currentIndex,
                  onSelect: (index) => _select(context, index),
                  onSettings: () => context.push('/settings'),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.currentIndex,
    required this.onSelect,
    required this.onSettings,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: AppSizes.railWidth,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: Image.asset(
              'assets/branding/app_icon.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onSelect,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.9,
              destinations: [
                for (final tab in AppTab.values)
                  NavigationRailDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: Text(tab.label),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: IconButton(
              onPressed: onSettings,
              tooltip: '设置',
              icon: Icon(
                Icons.settings_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
