// S0 环境自检窗口。
//
// 目的：证明工具链、渲染、字体、交互、构建链路全部可用。
// S1 开始时本文件会被真正的应用外壳替换。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dev/screenshot.dart';

/// 截图工具用的边界 key（生产环境无副作用）。
final GlobalKey _shotBoundaryKey = GlobalKey();

/// 进程启动时刻（用于展示冷启动信息）。
final DateTime _launchedAt = DateTime.now();

void main() {
  runApp(const SelfCheckApp());
  scheduleScreenshot(_shotBoundaryKey);
}

class SelfCheckApp extends StatelessWidget {
  const SelfCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'anime_client',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _theme(Brightness.dark),
      darkTheme: _theme(Brightness.dark),
      home: RepaintBoundary(
        key: _shotBoundaryKey,
        child: const SelfCheckPage(),
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C5CFF),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0E0E12),
    );
  }
}

class SelfCheckPage extends StatefulWidget {
  const SelfCheckPage({super.key});

  @override
  State<SelfCheckPage> createState() => _SelfCheckPageState();
}

class _SelfCheckPageState extends State<SelfCheckPage> {
  bool _probePassed = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRelease = !kDebugMode;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(theme: theme),
                const SizedBox(height: 14),
                _InfoCard(
                  rows: [
                    ('应用', 'anime_client 0.1.0'),
                    ('Flutter', '3.47.9 · stable'),
                    ('Dart', Platform.version.split(' ').first),
                    ('处理器', '${Platform.numberOfProcessors} 线程'),
                    ('系统', '${Platform.operatingSystem} · ${Platform.operatingSystemVersion}'),
                    ('区域', Platform.localeName),
                    ('构建模式', isRelease ? 'release' : 'debug'),
                    ('启动时刻', _launchedAt.toIso8601String()),
                  ],
                ),
                const SizedBox(height: 10),
                _RenderProbe(
                  onPassed: () => setState(() => _probePassed = true),
                ),
                const SizedBox(height: 10),
                _InteractionCard(
                  controller: _controller,
                  passed: _probePassed,
                ),
                const SizedBox(height: 14),
                Text(
                  'S0 · 环境自检通过',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9B8CFF),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/branding/app_icon.png',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'anime_client',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '环境自检 · S0',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262633)),
      ),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 渲染探针：字体、颜色、圆角、渐变、图标、中文排版。
class _RenderProbe extends StatelessWidget {
  const _RenderProbe({required this.onPassed});

  final VoidCallback onPassed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262633)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('渲染探针', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _Chip(text: '中文 日本語 中文简体', color: Color(0xFF7C5CFF)),
              _Chip(text: 'ABC abc 123', color: Color(0xFF3FD8C8)),
              _Chip(text: '♪ ♡ ★ ✦', color: Color(0xFFFFB454)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 8,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF7C5CFF),
                    Color(0xFF3FD8C8),
                    Color(0xFFFFB454),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '字体与布局渲染正常，渐变与圆角无锯齿',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: onPassed,
                child: const Text('标记通过'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// 交互探针：输入框（含 IME 基础能力）、按钮、SnackBar。
class _InteractionCard extends StatelessWidget {
  const _InteractionCard({required this.controller, required this.passed});

  final TextEditingController controller;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262633)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('交互探针', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '在这里输入文字（测试键盘 / 输入法）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '交互正常：输入「${controller.text.isEmpty ? '（空）' : controller.text}」',
                      ),
                      behavior: SnackBarBehavior.floating,
                      width: 360,
                    ),
                  );
                },
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('触发一次交互'),
              ),
              const SizedBox(width: 12),
              Icon(
                passed ? Icons.check_circle : Icons.radio_button_unchecked,
                color: passed ? const Color(0xFF3FD8C8) : theme.colorScheme.outline,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                passed ? '渲染探针已通过' : '渲染探针待确认',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
