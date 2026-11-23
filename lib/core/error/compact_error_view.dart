import 'package:flutter/material.dart';

/// 紧凑版错误占位。
///
/// 用在 `ErrorWidget.builder`：出错的可能只是列表里的一张卡片或一行文字，
/// 用整页大小的兜底视图会把布局撑破，反而制造二次错误。
class CompactErrorView extends StatelessWidget {
  const CompactErrorView({super.key, this.message = ''});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1618),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x66FF8A80)),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined,
                  color: Color(0xFFFF8A80), size: 18),
              SizedBox(height: 2),
              Text(
                '这块没能加载',
                style: TextStyle(color: Color(0xFFFFB4AB), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
