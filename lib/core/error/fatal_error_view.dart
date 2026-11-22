import 'package:flutter/material.dart';

import '../constants/app_info.dart';

/// 兜底错误视图。
///
/// 约束：这里**不能**依赖 MaterialApp / Theme / Provider，因为出错的可能是
/// 构建树的任何位置，甚至是根组件。所以只用最基础的 Widget，并保证本身不抛异常。
class FatalErrorView extends StatelessWidget {
  const FatalErrorView({
    super.key,
    this.title = '界面渲染出错',
    this.message = '',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    // 出错时也尽量给出可读信息，而不是红屏或白屏
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF0E0E12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFFF8A80), size: 40),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF2F2F7),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '这一块没能画出来。可以返回上一页重试，日志已记录。',
                    style: TextStyle(color: Color(0xFF9A9AA8), fontSize: 13),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF262633)),
                      ),
                      child: Text(
                        message,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFB9B9C6),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '${AppInfo.displayName} ${AppInfo.version}',
                    style: const TextStyle(
                        color: Color(0xFF5C5C6B), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
