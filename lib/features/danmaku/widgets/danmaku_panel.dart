import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../danmaku_settings.dart';

/// 播放页里的弹幕设置面板（右侧抽屉）。
class DanmakuPanel extends ConsumerWidget {
  const DanmakuPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(danmakuSettingsProvider);
    final notifier = ref.read(danmakuSettingsProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      width: 340,
      color: const Color(0xF2121216),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text('弹幕设置', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  SwitchListTile(
                    dense: true,
                    value: settings.enabled,
                    onChanged: notifier.setEnabled,
                    title: const Text('默认开关'),
                  ),
                  SwitchListTile(
                    dense: true,
                    value: settings.showScroll,
                    onChanged: notifier.setShowScroll,
                    title: const Text('滚动弹幕'),
                  ),
                  SwitchListTile(
                    dense: true,
                    value: settings.showTop,
                    onChanged: notifier.setShowTop,
                    title: const Text('顶部弹幕'),
                  ),
                  SwitchListTile(
                    dense: true,
                    value: settings.showBottom,
                    onChanged: notifier.setShowBottom,
                    title: const Text('底部弹幕'),
                  ),
                  SwitchListTile(
                    dense: true,
                    value: settings.followSpeed,
                    onChanged: notifier.setFollowSpeed,
                    title: const Text('跟随倍速'),
                  ),
                  const Divider(height: 16),
                  _PanelSlider(
                    label: '显示区域',
                    value: settings.areaRatio,
                    min: 0.2,
                    max: 1.0,
                    display: '${(settings.areaRatio * 100).round()}%',
                    onChanged: notifier.setAreaRatio,
                  ),
                  _PanelSlider(
                    label: '弹幕密度',
                    value: settings.density,
                    min: 0.2,
                    max: 1.0,
                    display: '${(settings.density * 100).round()}%',
                    onChanged: notifier.setDensity,
                  ),
                  _PanelSlider(
                    label: '顶部边距',
                    value: settings.topMargin,
                    min: 0,
                    max: 120,
                    display: settings.topMargin.round().toString(),
                    onChanged: notifier.setTopMargin,
                  ),
                  _PanelSlider(
                    label: '底部边距',
                    value: settings.bottomMargin,
                    min: 0,
                    max: 120,
                    display: settings.bottomMargin.round().toString(),
                    onChanged: notifier.setBottomMargin,
                  ),
                  _PanelSlider(
                    label: '不透明度',
                    value: settings.opacity,
                    min: 0.2,
                    max: 1.0,
                    display: '${(settings.opacity * 100).round()}%',
                    onChanged: notifier.setOpacity,
                  ),
                  _PanelSlider(
                    label: '字体大小',
                    value: settings.fontSize,
                    min: 14,
                    max: 40,
                    display: settings.fontSize.round().toString(),
                    onChanged: notifier.setFontSize,
                  ),
                  _PanelSlider(
                    label: '字体描边',
                    value: settings.outlineWidth,
                    min: 0,
                    max: 4,
                    display: settings.outlineWidth.toStringAsFixed(1),
                    onChanged: notifier.setOutlineWidth,
                  ),
                  _PanelSlider(
                    label: '滚动速度',
                    value: settings.speedFactor,
                    min: 0.5,
                    max: 2.0,
                    display: '${settings.speedFactor.toStringAsFixed(1)}x',
                    onChanged: notifier.setSpeedFactor,
                  ),
                  const Divider(height: 16),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.block_rounded, size: 18),
                    title: const Text('屏蔽管理'),
                    subtitle: Text(
                      settings.blockedWords.isEmpty
                          ? '未设置'
                          : '${settings.blockedWords.length} 个词',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _editBlocked(context, ref, settings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBlocked(
    BuildContext context,
    WidgetRef ref,
    DanmakuSettings settings,
  ) async {
    final controller = TextEditingController(text: settings.blockedWords.join('\n'));
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
    if (result != null) {
      await ref.read(danmakuSettingsProvider.notifier).setBlockedWords(result);
    }
  }
}

class _PanelSlider extends StatelessWidget {
  const _PanelSlider({
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Text(display, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          SizedBox(
            height: 28,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 播放页底部栏的弹幕入口按钮。
class DanmakuEntryButton extends StatelessWidget {
  const DanmakuEntryButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.subtitles_rounded, color: Colors.white),
      tooltip: '弹幕设置',
      splashRadius: AppRadius.md,
    );
  }
}
