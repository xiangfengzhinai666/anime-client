import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/dev_env.dart';
import '../../features/settings/settings_page.dart';
import '../shell/app_shell.dart';
import 'app_tabs.dart';

/// 路由表。
///
/// 结构：
/// - 一级页面走 `StatefulShellRoute.indexedStack`，每个 tab 有独立导航栈，
///   切换 tab 不丢页面状态（后续详情页压栈也遵循这个规则）；
/// - `/settings` 在 shell 之外，属于全屏二级页。
GoRouter buildRouter({int initialTab = 0}) {
  final index = initialTab.clamp(0, AppTab.values.length - 1);

  return GoRouter(
    initialLocation: AppTab.values[index].path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          for (final tab in AppTab.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.path,
                  name: tab.name,
                  builder: (context, state) => tab.buildPage(),
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
    errorBuilder: (context, state) =>
        _RouterErrorPage(message: state.error?.toString() ?? '未知错误'),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return buildRouter(initialTab: DevEnv.initialTabIndex);
});

class _RouterErrorPage extends StatelessWidget {
  const _RouterErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off_rounded, size: 40),
                const SizedBox(height: 12),
                Text('页面不存在',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('回到首页'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
