import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_providers.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/section_header.dart';
import '../../core/constants/app_info.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/app_paths.dart';

/// 设置页（全屏二级页）。
///
/// S1 只做真正可用的部分：主题切换（落库）、数据目录展示、诊断日志预览、关于信息。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: AppSpacing.page,
            children: [
              const SectionHeader(title: '外观', description: '立即生效，重启后保持'),
              _Card(
                child: Column(
                  children: [
                    _ThemeOption(
                      label: '跟随系统',
                      value: ThemeMode.system,
                      current: mode,
                      onSelected: (m) => ref
                          .read(themeModeProvider.notifier)
                          .setMode(m),
                    ),
                    const Divider(height: 1),
                    _ThemeOption(
                      label: '浅色',
                      value: ThemeMode.light,
                      current: mode,
                      onSelected: (m) => ref
                          .read(themeModeProvider.notifier)
                          .setMode(m),
                    ),
                    const Divider(height: 1),
                    _ThemeOption(
                      label: '深色',
                      value: ThemeMode.dark,
                      current: mode,
                      onSelected: (m) => ref
                          .read(themeModeProvider.notifier)
                          .setMode(m),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(title: '数据', description: '全部保存在本机'),
              _Card(
                child: FutureBuilder(
                  future: AppPaths.supportDir(),
                  builder: (context, snapshot) {
                    final path = snapshot.data?.path ?? '读取中…';
                    return _InfoRow(
                      icon: Icons.folder_outlined,
                      label: '数据目录',
                      value: path,
                      onCopy: () => _copy(context, path),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(title: '诊断', description: '最近日志'),
              _Card(child: const _RecentLogs()),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(title: '关于'),
              _Card(
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.info_outline_rounded,
                      label: '版本',
                      value: '${AppInfo.version} · ${AppInfo.stage} 骨架',
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      icon: Icons.code_rounded,
                      label: '仓库',
                      value: AppInfo.repository,
                      onCopy: () => _copy(context, AppInfo.repository),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '个人自用项目，不对外分发；界面与数据均在本机处理。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  final String label;
  final ThemeMode value;
  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = value == current;
    return ListTile(
      onTap: () => onSelected(value),
      title: Text(label),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? scheme.primary : scheme.outlineVariant,
        size: 20,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 72,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: SelectableText(
              value,
              maxLines: 2,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (onCopy != null)
            IconButton(
              tooltip: '复制',
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 16),
            ),
        ],
      ),
    );
  }
}

/// 最近日志：证明日志链路可用，同时方便排查。
class _RecentLogs extends StatelessWidget {
  const _RecentLogs();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<LogRecord>(
      stream: appLogger.stream,
      initialData: appLogger.buffer.isEmpty ? null : appLogger.buffer.last,
      builder: (context, snapshot) {
        final records = appLogger.buffer.reversed.take(5).toList();
        if (records.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('还没有日志', style: theme.textTheme.bodySmall),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final record in records)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    record.format(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: record.level == LogLevel.error
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '日志文件位于数据目录 / logs 下，按天切分，保留 5 天',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
