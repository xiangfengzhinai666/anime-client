import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/utils/dev_env.dart';

/// 截图边界：`AppShell` 用它包住整棵树。
final GlobalKey appShotKey = GlobalKey(debugLabel: 'app-shot');

/// 开发期自渲染截图。
///
/// 背景：自动化环境抓不到 GPU 合成窗口（PrintWindow 白屏、屏幕拷贝在
/// 无交互桌面时失败），因此让 Flutter 自己把 RepaintBoundary 渲染成 PNG。
///
/// 触发方式：设置环境变量 `DSH_SHOT`（+ 可选 `DSH_SHOT_DELAY_MS`），
/// 应用渲染首帧后写出图片并退出。
void scheduleScreenshot() {
  final path = DevEnv.shotPath;
  if (path == null || path.isEmpty) return;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future<void>.delayed(DevEnv.shotDelay);
    try {
      final boundary = appShotKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('[screenshot] boundary not ready');
        exit(2);
      }
      final image = await boundary.toImage(pixelRatio: 1.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(data!.buffer.asUint8List());
      debugPrint(
        '[screenshot] saved $path (${image.width}x${image.height})',
      );
    } catch (e, st) {
      debugPrint('[screenshot] failed: $e\n$st');
      exit(3);
    }
    exit(0);
  });
}
