import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logging/app_logger.dart';
import 'fatal_error_view.dart';

/// 安装全局错误兜底。必须在 `runApp` 之前调用。
///
/// 覆盖三条通道：
/// 1. 构建/布局/绘制期异常 → `FlutterError.onError`
/// 2. 引擎层未捕获异常 → `PlatformDispatcher.onError`
/// 3. 单块 Widget 构建失败 → `ErrorWidget.builder`（替换成友好视图）
/// 异步 Zone 里的异常由 `runZonedGuarded` 处理（见 main）。
void installGlobalErrorHandlers(AppLogger logger) {
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.error(
      'flutter',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    // 返回 true 表示「已处理」，避免进程直接崩掉
    logger.error('platform', '未捕获的异步异常', error, stack);
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return FatalErrorView(message: details.exceptionAsString());
  };
}
