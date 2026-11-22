// 开发期截图工具：让应用自己把界面渲染成 PNG。
//
// 背景：本机自动化环境无法可靠地抓取 GPU 合成的窗口画面（PrintWindow 拿到白屏、
// CopyFromScreen 在某些会话下取不到桌面 DC）。因此由 Flutter 自己把 RepaintBoundary
// 渲染成图片，结果与肉眼看到的一致，且不依赖桌面会话。
//
// 用法（仅开发期）：
//   $env:DSH_SHOT = "C:\path\shot.png"
//   .\anime_client.exe
// 应用渲染首帧后写出 PNG 并退出。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const String _shotEnvKey = 'DSH_SHOT';
const String _shotDelayEnvKey = 'DSH_SHOT_DELAY_MS';

/// 若设置了环境变量，则在首帧渲染完成后截图并退出。
void scheduleScreenshot(GlobalKey boundaryKey) {
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
  final path = Platform.environment[_shotEnvKey];
  if (path == null || path.isEmpty) return;

  final delayMs =
      int.tryParse(Platform.environment[_shotDelayEnvKey] ?? '') ?? 900;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    try {
      final boundary =
          boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('[screenshot] boundary not ready');
        exit(2);
      }
      final image = await boundary.toImage(pixelRatio: 1.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(data!.buffer.asUint8List());
      debugPrint('[screenshot] saved to $path (${image.width}x${image.height})');
    } catch (e, st) {
      debugPrint('[screenshot] failed: $e\n$st');
      exit(3);
    }
    exit(0);
  });
}
