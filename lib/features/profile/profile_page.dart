import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/app_providers.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/page_scaffold.dart';
import '../../app/widgets/section_header.dart';
import '../../core/constants/app_info.dart';

/// 我的：本地档案 + 数据统计 + 设置/关于入口。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favorites = ref.watch(favoritesProvider);
    final history = ref.watch(recentHistoryProvider);

    final favoriteCount = favorites.maybeWhen(
      data: (items) => items.length,
      orElse: () => 0,
    );
    final historyCount = history.maybeWhen(
      data: (items) => items.length,
      orElse: () => 0,
    );

    return PageScaffold(
      title: '我的',
      subtitle: '所有数据都在本机，不上传',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileCard(favoriteCount: favoriteCount, historyCount: historyCount),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: '偏好'),
          _MenuGroup(
            children: [
              _MenuTile(
                icon: Icons.palette_outlined,
                title: '外观',
                subtitle: _themeLabel(context, ref.watch(themeModeProvider)),
                onTap: () => context.push('/settings'),
              ),
              _MenuTile(
                icon: Icons.history_rounded,
                title: '观看历史',
                subtitle: '按番去重，可续播',
                onTap: () => context.push('/history'),
              ),
              _MenuTile(
                icon: Icons.tune_rounded,
                title: '播放与弹幕',
                subtitle: '倍速、弹幕样式、自动连播',
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: '关于'),
          _MenuGroup(
            children: [
              _MenuTile(
                icon: Icons.info_outline_rounded,
                title: AppInfo.displayName,
                subtitle: '版本 ${AppInfo.version}（${AppInfo.stage} 骨架）',
                onTap: () => context.push('/settings'),
              ),
              _MenuTile(
                icon: Icons.storage_outlined,
                title: '数据存储',
                subtitle: 'SQLite · 观看记录 $historyCount 条',
                enabled: false,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '个人自用项目，不对外分发。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _themeLabel(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.favoriteCount, required this.historyCount});

  final int favoriteCount;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary.withValues(alpha: 0.18), scheme.surface],
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: Image.asset(
              'assets/branding/app_icon.png',
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本地档案', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text('无需登录，设置与记录保存在本机 SQLite',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _Stat(value: '$favoriteCount', label: '追番'),
                    const SizedBox(width: AppSpacing.xl),
                    _Stat(value: '$historyCount', label: '观看记录'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
            )),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, color: scheme.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant;
    return ListTile(
      onTap: enabled ? onTap : null,
      leading: Icon(icon, color: color, size: 20),
      title: Text(title, style: theme.textTheme.titleMedium?.copyWith(color: color)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: enabled
          ? Icon(Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant)
          : const SizedBox.shrink(),
    );
  }
}
