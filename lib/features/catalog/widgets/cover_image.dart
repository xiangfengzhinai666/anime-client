import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../catalog_providers.dart';

/// 封面图：磁盘缓存 + 占位 + 失败兜底。
///
/// 只读本地文件（由 DiskImageCache 负责下载），所以滚动时不会重复请求网络。
class CoverImage extends ConsumerStatefulWidget {
  const CoverImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = AppRadius.md,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  @override
  ConsumerState<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends ConsumerState<CoverImage> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = _load();
    }
  }

  Future<File?> _load() {
    if (widget.url.isEmpty) return Future<File?>.value();
    return ref.read(diskImageCacheProvider).get(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: widget.width,
      height: widget.height,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_outlined,
        size: 20,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: FutureBuilder<File?>(
          future: _future,
          builder: (context, snapshot) {
            final file = snapshot.data;
            if (file == null) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return placeholder;
              }
              return placeholder;
            }
            return Image.file(
              file,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              filterQuality: FilterQuality.medium,
              // 按显示宽度解码，长列表不会把整张大图塞进内存
              cacheWidth: (widget.width != null && widget.width!.isFinite)
                  ? (widget.width! * 2).round()
                  : null,
              errorBuilder: (_, _, _) => placeholder,
              frameBuilder: (context, child, frame, syncLoaded) {
                if (syncLoaded || frame != null) return child;
                return placeholder;
              },
            );
          },
        ),
      ),
    );
  }
}
