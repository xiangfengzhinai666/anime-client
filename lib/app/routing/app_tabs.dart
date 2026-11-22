import 'package:flutter/material.dart';

import '../../features/browse/browse_page.dart';
import '../../features/home/home_page.dart';
import '../../features/library/library_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/search/search_page.dart';

/// 底部/侧栏的五个一级页面。
///
/// 单一来源：路由（path）、导航（label/icon）、页面（builder）都在这里登记，
/// 新增/调整顺序只改这一处。
enum AppTab {
  home(
    path: '/',
    label: '首页',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  browse(
    path: '/browse',
    label: '索引',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
  ),
  search(
    path: '/search',
    label: '搜索',
    icon: Icons.search_outlined,
    selectedIcon: Icons.search_rounded,
  ),
  library(
    path: '/library',
    label: '追番',
    icon: Icons.bookmark_outline_rounded,
    selectedIcon: Icons.bookmark_rounded,
  ),
  profile(
    path: '/profile',
    label: '我的',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  );

  const AppTab({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  Widget buildPage() {
    switch (this) {
      case AppTab.home:
        return const HomePage();
      case AppTab.browse:
        return const BrowsePage();
      case AppTab.search:
        return const SearchPage();
      case AppTab.library:
        return const LibraryPage();
      case AppTab.profile:
        return const ProfilePage();
    }
  }

  static AppTab? fromPath(String path) {
    for (final tab in AppTab.values) {
      if (tab.path == path) return tab;
    }
    return null;
  }
}
