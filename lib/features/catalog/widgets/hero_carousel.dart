import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../data/catalog_models.dart';
import 'cover_image.dart';

/// 首页顶部轮播。
///
/// 规则：
/// - 从传入的池子里按「当天日期」轮换取 [visibleCount] 部（同一天内稳定）；
/// - 6 秒自动切换，鼠标悬停暂停，底部圆点可点；
/// - 点击整块或按钮都进详情。
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({
    super.key,
    required this.items,
    required this.onOpen,
    this.height = 300,
    this.visibleCount = 5,
    this.interval = const Duration(seconds: 6),
  });

  final List<AnimeSummary> items;
  final void Function(AnimeSummary anime) onOpen;
  final double height;
  final int visibleCount;
  final Duration interval;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  late final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _hovered = false;

  List<AnimeSummary> get _slides {
    final all = widget.items;
    if (all.isEmpty) return const [];
    final count = widget.visibleCount.clamp(1, all.length);
    // 每天的起始位置不同：同一天刷新看到的是同一组
    final offset = DateTime.now().day % all.length;
    return List.generate(count, (i) => all[(offset + i) % all.length]);
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_slides.length <= 1) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || _hovered) return;
      final next = (_index + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: AppDurations.slow,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    if (slides.isEmpty) return const SizedBox.shrink();

    return MouseRegion(
      onEnter: (_) => _hovered = true,
      onExit: (_) => _hovered = false,
      child: Column(
        children: [
          SizedBox(
            height: widget.height,
            child: ClipRRect(
              borderRadius: AppRadius.xlAll,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _Slide(
                      anime: slides[i],
                      onOpen: () => widget.onOpen(slides[i]),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: Row(
                      children: [
                        for (var i = 0; i < slides.length; i++)
                          GestureDetector(
                            onTap: () => _controller.animateToPage(
                              i,
                              duration: AppDurations.normal,
                              curve: Curves.easeOut,
                            ),
                            child: AnimatedContainer(
                              duration: AppDurations.fast,
                              width: i == _index ? 20 : 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: i == _index
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.45),
                                borderRadius: AppRadius.pillAll,
                              ),
                            ),
                          ),
                        const Spacer(),
                        _ArrowButton(
                          icon: Icons.chevron_left_rounded,
                          onTap: () => _controller.previousPage(
                            duration: AppDurations.normal,
                            curve: Curves.easeOut,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _ArrowButton(
                          icon: Icons.chevron_right_rounded,
                          onTap: () => _controller.nextPage(
                            duration: AppDurations.normal,
                            curve: Curves.easeOut,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.anime, required this.onOpen});

  final AnimeSummary anime;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onOpen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CoverImage(url: anime.cover, fit: BoxFit.cover, radius: 0),
          // 底部渐变，保证文字可读
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.35, 1.0],
                colors: [Colors.transparent, Color(0xE6000000)],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.xxl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _meta(anime),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('查看详情'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _meta(AnimeSummary anime) {
    final parts = <String>[
      if (anime.year != null) '${anime.year}',
      if ((anime.totalEpisodes ?? 0) > 0) '${anime.totalEpisodes} 话',
      if (anime.status.isNotEmpty) anime.status,
      if (anime.score != null) '评分 ${anime.score!.toStringAsFixed(1)}',
    ];
    return parts.join(' · ');
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
