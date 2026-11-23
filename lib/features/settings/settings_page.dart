import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/app_providers.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/section_header.dart';
import '../../core/constants/app_info.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/app_paths.dart';
import '../danmaku/danmaku_settings.dart';
import '../danmaku/data/danmaku_models.dart';
import '../play/play_providers.dart';
import '../play/widgets/cycani_login_dialog.dart';

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
              const SectionHeader(title: '弹幕', description: '默认开启，快捷键 D 切换'),
              _Card(child: const _DanmakuSettings()),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(
                title: '账号',
                description: '登录态只保存在本机',
              ),
              _Card(child: const _AccountTile()),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(
                title: '播放',
                description: '不需要账号也能播放本地文件',
              ),
              _Card(
                child: Column(
                  children: [
                    const _AutoNextTile(),
                    const Divider(height: 1),
                    const _LocalFileTile(),
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

/// 次元城账号：显示登录态，可登录/退出。
class _AccountTile extends ConsumerWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(cycaniSessionProvider);
    final theme = Theme.of(context);
    final loggedIn = session != null;
    return ListTile(
      leading: Icon(
        loggedIn ? Icons.verified_user_outlined : Icons.person_outline,
        color: loggedIn ? theme.colorScheme.primary : null,
      ),
      title: Text(loggedIn ? session.username : '未登录'),
      subtitle: Text(
        loggedIn
            ? '次元城 · 已登录${session.nickname.isEmpty ? '' : '（${session.nickname}）'}'
            : '播放次元城线路需要登录',
      ),
      trailing: loggedIn
          ? TextButton(
              onPressed: () async {
                await ref.read(cycaniSessionProvider.notifier).logout();
                ref.invalidate(playLinesProvider);
              },
              child: const Text('退出登录'),
            )
          : FilledButton.tonal(
              onPressed: () => CycaniLoginDialog.show(context),
              child: const Text('登录'),
            ),
    );
  }
}

/// 打开本地视频（不需要任何账号）。
class _LocalFileTile extends StatelessWidget {
  const _LocalFileTile();

  static const _group = XTypeGroup(
    label: '视频',
    extensions: ['mp4', 'mkv', 'webm', 'avi', 'mov', 'flv', 'ts', 'm4v'],
  );

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.folder_open_rounded),
      title: const Text('打开本地视频'),
      subtitle: const Text('支持 mp4 / mkv / webm 等常见格式'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        final file = await openFile(acceptedTypeGroups: const [_group]);
        if (file == null) return;
        if (!context.mounted) return;
        context.push('/watch/local?path=${Uri.encodeQueryComponent(file.path)}');
      },
    );
  }
}

/// 弹幕设置：开关 + 多源 + 显示参数 + 屏蔽词。
class _DanmakuSettings extends ConsumerWidget {
  const _DanmakuSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(danmakuSettingsProvider);
    final notifier = ref.read(danmakuSettingsProvider.notifier);
    final theme = Theme.of(context);

    final unavailable = {
      DanmakuSource.bilibiliHkTw: '需港澳台季 id，暂未接入',
      DanmakuSource.tencent: '需要 vid，暂缓',
      DanmakuSource.dandanplay: settings.dandanplayAppId.isEmpty
          ? '需 AppId/AppSecret'
          : null,
    };

    return Column(
      children: [
        SwitchListTile(
          value: settings.enabled,
          onChanged: notifier.setEnabled,
          title: const Text('显示弹幕'),
          subtitle: const Text('关闭后画面保持干净，快捷键 D 随时切换'),
        ),
        const Divider(height: 1),
        SwitchListTile(
          value: settings.followSpeed,
          onChanged: notifier.setFollowSpeed,
          title: const Text('跟随倍速'),
          subtitle: const Text('弹幕速度跟随视频倍速'),
        ),
        const Divider(height: 1),
        for (final source in DanmakuSource.values) ...[
          SwitchListTile(
            value: settings.sources.contains(source),
            onChanged: unavailable[source] != null
                ? null
                : (value) => notifier.setSource(source, value),
            title: Text(source.label),
            subtitle: unavailable[source] == null
                ? null
                : Text(unavailable[source]!),
          ),
          if (source != DanmakuSource.values.last) const Divider(height: 1),
        ],
        const Divider(height: 1),
        _SliderRow(
          label: '透明度',
          value: settings.opacity,
          min: 0.2,
          max: 1.0,
          display: '${(settings.opacity * 100).round()}%',
          onChanged: notifier.setOpacity,
        ),
        _SliderRow(
          label: '字号',
          value: settings.fontSize,
          min: 14,
          max: 40,
          display: settings.fontSize.round().toString(),
          onChanged: notifier.setFontSize,
        ),
        _SliderRow(
          label: '滚动速度',
          value: settings.speedFactor,
          min: 0.5,
          max: 2.0,
          display: '${settings.speedFactor.toStringAsFixed(1)}x',
          onChanged: notifier.setSpeedFactor,
        ),
        _SliderRow(
          label: '同屏上限',
          value: settings.maxOnScreen.toDouble(),
          min: 20,
          max: 200,
          display: '${settings.maxOnScreen} 条',
          onChanged: (v) => notifier.setMaxOnScreen(v.round()),
        ),
        ListTile(
          leading: const Icon(Icons.block_rounded),
          title: const Text('屏蔽词'),
          subtitle: Text(
            settings.blockedWords.isEmpty
                ? '未设置（用换行或逗号分隔）'
                : settings.blockedWords.join('、'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            final controller =
                TextEditingController(text: settings.blockedWords.join('\n'));
            final result = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('屏蔽词'),
                content: SizedBox(
                  width: 380,
                  child: TextField(
                    controller: controller,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: '每行一个，或逗号分隔',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    child: const Text('保存'),
                  ),
                ],
              ),
            );
            if (result != null) await notifier.setBlockedWords(result);
          },
        ),
        if (unavailable[DanmakuSource.dandanplay] != null)
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('弹弹play AppId / AppSecret'),
            subtitle: Text(
              settings.dandanplayAppId.isEmpty ? '未配置' : '已配置',
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _editDandanplay(context, ref, settings),
          ),
      ],
    );
  }

  Future<void> _editDandanplay(
    BuildContext context,
    WidgetRef ref,
    DanmakuSettings settings,
  ) async {
    final idController = TextEditingController(text: settings.dandanplayAppId);
    final secretController =
        TextEditingController(text: settings.dandanplayAppSecret);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('弹弹play 开发者凭据'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: 'AppId',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secretController,
                decoration: const InputDecoration(
                  labelText: 'AppSecret',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '在 dandanplay.com 开发者控制台创建应用后获得；只保存在本机。',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await ref
          .read(danmakuSettingsProvider.notifier)
          .setDandanplay(idController.text, secretController.text);
    }
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(display, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

/// 自动连播开关。
class _AutoNextTile extends ConsumerWidget {
  const _AutoNextTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoNext = ref.watch(autoPlayNextProvider);
    return SwitchListTile(
      value: autoNext,
      onChanged: (value) => ref.read(autoPlayNextProvider.notifier).set(value),
      title: const Text('自动连播下一集'),
      subtitle: const Text('一集播完自动播放下一集；关闭后显示「重播 / 下一集」面板'),
    );
  }
}
