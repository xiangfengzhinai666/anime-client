import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/providers/app_providers.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/logging/app_logger.dart';
import '../catalog/catalog_providers.dart';
import '../catalog/data/catalog_models.dart';
import 'arrow_key_gesture.dart';
import 'data/play_models.dart';
import 'play_providers.dart';
import 'widgets/cycani_login_dialog.dart';

/// 播放页。
///
/// 两种模式：
/// - 在线：`/watch/{source}:{id}/{episode}`，分集经次元城换播放地址；
/// - 本地：`/watch/local?path=...`，直接播本地文件（不依赖任何账号）。
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    super.key,
    this.internalId,
    this.episode = 1,
    this.localPath,
  });

  final String? internalId;
  final int episode;
  final String? localPath;

  bool get isLocal => localPath != null && localPath!.isNotEmpty;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> with WindowListener {
  late final Player _player;
  late final VideoController _controller;
  late final void Function({
    required AnimeSummary? summary,
    required int episode,
    required int positionSeconds,
    required int durationSeconds,
    required String episodeTitle,
  }) _saveProgress;
  late final AppLogger _log;
  late final Widget _video;

  final List<StreamSubscription<dynamic>> _subs = [];

  bool _playing = false;
  bool _buffering = true;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  bool _muted = false;
  bool _ready = false;
  String? _error;
  String _errorTitle = '播放失败';

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100;
  double _speed = 1.0;
  double _speedBeforeHold = 1.0;
  bool _holdingFastForward = false;
  late final ArrowKeyHoldGesture _arrowKeyGesture;

  Timer? _hideTimer;
  Timer? _saveTimer;

  AnimeDetail? _detail;
  AnimeEpisode? _episode;
  List<PlayLine> _lines = const [];
  int _lineIndex = 0;
  bool _needsLogin = false;

  int get _episodeIndex => widget.episode;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _player = Player();
    _controller = VideoController(_player);
    // 只创建一次：控件层频繁 setState 时不要重建 Video（重建纹理容易卡死）
    _video = Video(
      controller: _controller,
      controls: NoVideoControls,
      fit: BoxFit.contain,
    );
    // 提前拿好保存函数：dispose 阶段再用 ref 会抛异常（导致进度没写进去）
    _saveProgress = ref.read(saveProgressProvider);
    _log = ref.read(appLoggerProvider);
    _bindPlayer();
    _load();
    _arrowKeyGesture = ArrowKeyHoldGesture(
      onShortPress: () => _seekRelative(5),
      onLongPressStart: _holdFastForward,
      onLongPressEnd: _releaseFastForward,
    );
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  void _bindPlayer() {
    _subs.add(_player.stream.playing.listen((v) => setState(() => _playing = v)));
    _subs.add(_player.stream.buffering
        .listen((v) => setState(() => _buffering = v)));
    _subs.add(_player.stream.position
        .listen((v) => setState(() => _position = v)));
    _subs.add(_player.stream.duration
        .listen((v) => setState(() => _duration = v)));
    _subs.add(_player.stream.volume
        .listen((v) => setState(() => _volume = v)));
    _subs.add(_player.stream.rate.listen((v) => setState(() => _speed = v)));
    _subs.add(_player.stream.error.listen((e) {
      if (e.trim().isEmpty) return;
      setState(() {
        _errorTitle = '播放出错';
        _error = e;
      });
    }));
    // 播放状态里 media_kit 会在播放开始时给 null error
    _player.stream.error.listen((_) {});
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _ready = false;
      _needsLogin = false;
    });

    try {
      if (widget.isLocal) {
        await _startPlayback(widget.localPath!, resume: 0);
        setState(() {
          _ready = true;
          _errorTitle = '本地文件播放失败';
        });
        return;
      }

      final internalId = widget.internalId ?? '';
      final detail = await ref.read(animeDetailProvider(internalId).future);
      if (!mounted) return;

      AnimeEpisode? target;
      for (final ep in detail.episodes) {
        if (ep.index == _episodeIndex) {
          target = ep;
          break;
        }
      }
      target ??= detail.episodes.isEmpty ? null : detail.episodes.first;

      if (target == null) {
        setState(() {
          _errorTitle = '没有可播放的分集';
          _error = '这个番还没有分集数据，换个源或稍后再试';
        });
        return;
      }

      final sectionId = target.sectionId;
      if (sectionId.isEmpty) {
        setState(() {
          _errorTitle = '这条只有元数据，不能播放';
          _error = 'B 站 / AniList 条目只提供信息；请到详情页点「在次元城找这部」，'
              '或用「设置 → 打开本地视频」播放本地文件';
        });
        return;
      }

      // 用 refresh 而不是 read：登录前失败的结果会被缓存，登录后必须重新请求
      final lines = await ref.refresh(playLinesProvider(sectionId).future);
      if (!mounted) return;

      final resume = await ref.read(
        resumePositionProvider((internalId: internalId, episode: target.index))
            .future,
      );
      if (!mounted) return;

      setState(() {
        _detail = detail;
        _episode = target;
        _lines = lines;
        _lineIndex = 0;
      });

      await _startPlayback(lines.first.url, resume: resume);
      if (mounted) setState(() => _ready = true);
      _startSaveTimer();
    } catch (e) {
      if (!mounted) return;
      final message = '$e';
      setState(() {
        if (message.contains('登录')) {
          _needsLogin = true;
          _errorTitle = '需要登录次元城';
          _error = message;
        } else {
          _errorTitle = '加载失败';
          _error = message;
        }
      });
    }
  }

  Future<void> _startPlayback(String url, {required int resume}) async {
    _log.debug('play', 'open resume=$resume url=${url.split('?').first}');
    await _player.open(Media(url), play: true);
    if (resume > 0) {
      // 媒体刚 open 时 seek 会被忽略，等 duration 出来再跳
      final ready = await _waitForDuration(const Duration(seconds: 10));
      _log.debug('play', 'duration ready=$ready current=$_duration');
      if (ready && mounted) {
        await _player.seek(Duration(seconds: resume));
        if (mounted) setState(() => _position = Duration(seconds: resume));
      }
    }
    _scheduleHide();
    _save();
  }

  /// 等播放器拿到时长（说明已解码出媒体），最多等 [timeout]。
  Future<bool> _waitForDuration(Duration timeout) async {
    if (_duration > Duration.zero) return true;
    final completer = Completer<bool>();
    late final StreamSubscription<Duration> sub;
    sub = _player.stream.duration.listen((value) {
      if (value > Duration.zero && !completer.isCompleted) {
        completer.complete(true);
      }
    });
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });
    final result = await completer.future;
    timer.cancel();
    await sub.cancel();
    return result;
  }

  void _startSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _save());
  }

  void _save() {
    final detail = _detail;
    final ep = _episode;
    if (detail == null || ep == null) return;
    if (_position.inSeconds <= 0) return;
    _saveProgress(
      summary: detail.summary,
      episode: ep.index,
      positionSeconds: _position.inSeconds,
      durationSeconds: _duration.inSeconds,
      episodeTitle: ep.title,
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _arrowKeyGesture.dispose();
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _save();
    windowManager.removeListener(this);
    for (final sub in _subs) {
      sub.cancel();
    }
    // 先停播、再释放控制器、最后 dispose 播放器。
    // 顺序不对时 mpv 可能继续在后台出声（"退出页面还在播"的根因）。
    _player.stop().catchError((_) {});
    _player.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- 交互

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_playing) return;
    _hideTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  DateTime _lastShow = DateTime.fromMillisecondsSinceEpoch(0);

  void _showControls() {
    final now = DateTime.now();
    if (_controlsVisible &&
        now.difference(_lastShow) < const Duration(milliseconds: 500)) {
      _scheduleHide();
      return;
    }
    _lastShow = now;
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  /// 按住右键 → 2 倍速；松开还原（常见的"按住快进"手势）。
  Future<void> _holdFastForward() async {
    if (_holdingFastForward) return;
    _holdingFastForward = true;
    _speedBeforeHold = _speed;
    _log.debug('play', 'hold-right: 2.0x（原 $_speed）');
    await _player.setRate(2.0);
    if (mounted) setState(() {});
  }

  Future<void> _releaseFastForward() async {
    if (!_holdingFastForward) return;
    _holdingFastForward = false;
    final restored = _speedBeforeHold == 2.0 ? 1.0 : _speedBeforeHold;
    _log.debug('play', 'hold-right: 恢复 $restored x');
    await _player.setRate(restored);
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    _player.playOrPause();
    _showControls();
  }

  Future<void> _toggleFullscreen() async {
    _fullscreen = !_fullscreen;
    await windowManager.setFullScreen(_fullscreen);
    if (mounted) setState(() {});
  }

  Future<void> _seek(Duration position) async {
    final max = _duration;
    var target = position;
    if (target < Duration.zero) target = Duration.zero;
    if (max > Duration.zero && target > max) target = max;
    await _player.seek(target);
    _showControls();
  }

  Future<void> _setSpeed(double speed) async {
    await _player.setRate(speed);
    if (mounted) setState(() => _speed = speed);
  }

  /// 键盘 → ：短按跳 5 秒；按住超过 350ms 进入 2 倍速，松开还原。
  bool _onHardwareKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.arrowRight) return false;
    _arrowKeyGesture.handle(event);
    return true;
  }

  void _seekRelative(int seconds) {
    _seek(_position + Duration(seconds: seconds));
  }

  Future<void> _playLine(int index) async {
    if (index < 0 || index >= _lines.length) return;
    setState(() => _lineIndex = index);
    final resume = _position.inSeconds;
    await _startPlayback(_lines[index].url, resume: resume);
  }

  bool get _hasPrev {
    final eps = _detail?.episodes ?? const <AnimeEpisode>[];
    return eps.isNotEmpty && _episodeIndex > eps.first.index;
  }

  bool get _hasNext {
    final eps = _detail?.episodes ?? const <AnimeEpisode>[];
    return eps.isNotEmpty && _episodeIndex < eps.last.index;
  }

  void _gotoEpisode(int index) {
    final id = widget.internalId;
    if (id == null) return;
    context.pushReplacement(
      '/watch/${Uri.encodeComponent(id)}/$index',
    );
  }

  // ---------------------------------------------------------------- 构建

  @override
  Widget build(BuildContext context) {
    final title = widget.isLocal
        ? (widget.localPath ?? '').split(RegExp(r'[\\/]')).last
        : '${_detail?.summary.title ?? '加载中'}${_episode == null ? '' : ' · ${_episode!.title}'}';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.keyK): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _seekRelative(-5),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _player.setVolume((_volume + 5).clamp(0, 100)),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _player.setVolume((_volume - 5).clamp(0, 100)),
        const SingleActivator(LogicalKeyboardKey.keyM): () {
          _muted = !_muted;
          _player.setVolume(_muted ? 0 : 100);
        },
        const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
        const SingleActivator(LogicalKeyboardKey.keyJ): () => _seekRelative(-10),
        const SingleActivator(LogicalKeyboardKey.keyL): () => _seekRelative(10),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_fullscreen) {
            _toggleFullscreen();
          } else {
            _back();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: MouseRegion(
            onHover: (_) => _showControls(),
            child: GestureDetector(
              // 单击画面 = 暂停/继续；双击 = 全屏
              onTap: _togglePlay,
              onDoubleTap: _toggleFullscreen,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_ready)
                    _video
                  else
                    const ColoredBox(color: Colors.black),
                  if (_buffering && _ready)
                    const Center(
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                  if (_holdingFastForward)
                    Positioned(
                      top: 56,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: AppRadius.pillAll,
                        ),
                        child: const Text(
                          '2x 快进中',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  if (_error != null) _ErrorPanel(
                    title: _errorTitle,
                    message: _error!,
                    needsLogin: _needsLogin,
                    onRetry: _load,
                    onLogin: _openLogin,
                    onBack: _back,
                  ),
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: AppDurations.normal,
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: _buildChrome(title),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _openLogin() async {
    final ok = await CycaniLoginDialog.show(context);
    if (!mounted) return;
    if (ok || ref.read(cycaniSessionProvider) != null) _load();
  }

  Widget _buildChrome(String title) {
    return Column(
      children: [
        _TopBar(title: title, onBack: _back, onFullscreen: _toggleFullscreen),
        const Spacer(),
        _BottomBar(
          playing: _playing,
          position: _position,
          duration: _duration,
          volume: _volume,
          speed: _speed,
          hasPrev: _hasPrev,
          hasNext: _hasNext,
          lines: _lines,
          lineIndex: _lineIndex,
          hasEpisodes: (_detail?.episodes.isNotEmpty ?? false),
          onPlayPause: _togglePlay,
          onSeek: _seek,
          onPrev: () {
            if (_episode != null) _gotoEpisode(_episodeIndex - 1);
          },
          onNext: () {
            if (_episode != null) _gotoEpisode(_episodeIndex + 1);
          },
          onVolume: (v) => _player.setVolume(v),
          onSpeed: _setSpeed,
          onFullscreen: _toggleFullscreen,
          onPickLine: _playLine,
          onShowEpisodes: _showEpisodes,
        ),
      ],
    );
  }

  Future<void> _showEpisodes() async {
    final detail = _detail;
    if (detail == null || detail.episodes.isEmpty) return;
    setState(() => _controlsVisible = true);
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF141418),
      builder: (context) => _EpisodeSheet(
        episodes: detail.episodes,
        current: _episodeIndex,
      ),
    );
    if (picked != null) _gotoEpisode(picked);
  }

  @override
  void onWindowBlur() {
    // 失焦时松开快进，避免"按住右键切走窗口"后一直 2 倍速
    _releaseFastForward();
  }

  @override
  void onWindowLeaveFullScreen() {
    if (_fullscreen) setState(() => _fullscreen = false);
  }
}

// ---------------------------------------------------------------- 顶部栏

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onFullscreen,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: '返回（Esc）',
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: onFullscreen,
            icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
            tooltip: '全屏（F）',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 底部控制

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.playing,
    required this.position,
    required this.duration,
    required this.volume,
    required this.speed,
    required this.hasPrev,
    required this.hasNext,
    required this.lines,
    required this.lineIndex,
    required this.hasEpisodes,
    required this.onPlayPause,
    required this.onSeek,
    required this.onPrev,
    required this.onNext,
    required this.onVolume,
    required this.onSpeed,
    required this.onFullscreen,
    required this.onPickLine,
    required this.onShowEpisodes,
  });

  final bool playing;
  final Duration position;
  final Duration duration;
  final double volume;
  final double speed;
  final bool hasPrev;
  final bool hasNext;
  final List<PlayLine> lines;
  final int lineIndex;
  final bool hasEpisodes;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<double> onVolume;
  final ValueChanged<double> onSpeed;
  final VoidCallback onFullscreen;
  final ValueChanged<int> onPickLine;
  final VoidCallback onShowEpisodes;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds.toDouble();
    final current = position.inMilliseconds.toDouble().clamp(0.0, total);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xDD000000), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(_fmt(position),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: total <= 0 ? 0 : current,
                  max: total <= 0 ? 1 : total,
                  onChanged: total <= 0
                      ? null
                      : (v) => onSeek(Duration(milliseconds: v.round())),
                ),
              ),
              Text(_fmt(duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: hasPrev ? onPrev : null,
                icon: const Icon(Icons.skip_previous_rounded,
                    color: Colors.white),
                tooltip: '上一集',
              ),
              IconButton(
                onPressed: onPlayPause,
                iconSize: 34,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                tooltip: '播放/暂停（空格）',
              ),
              IconButton(
                onPressed: hasNext ? onNext : null,
                icon:
                    const Icon(Icons.skip_next_rounded, color: Colors.white),
                tooltip: '下一集',
              ),
              const SizedBox(width: 8),
              PopupMenuButton<double>(
                tooltip: '倍速',
                initialValue: speed,
                onSelected: onSpeed,
                itemBuilder: (context) => [
                  for (final s in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                    PopupMenuItem(value: s, child: Text('${s}x')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  child: Text('${speed}x',
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
              if (lines.length > 1)
                PopupMenuButton<int>(
                  tooltip: '线路',
                  initialValue: lineIndex,
                  onSelected: onPickLine,
                  itemBuilder: (context) => [
                    for (var i = 0; i < lines.length; i++)
                      PopupMenuItem(value: i, child: Text(lines[i].name)),
                  ],
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text('线路 ${lineIndex + 1}/${lines.length}',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              const Spacer(),
              const Icon(Icons.volume_up_rounded,
                  color: Colors.white70, size: 18),
              SizedBox(
                width: 90,
                child: Slider(
                  value: volume.clamp(0, 100),
                  max: 100,
                  onChanged: onVolume,
                ),
              ),
              IconButton(
                onPressed: hasEpisodes ? onShowEpisodes : null,
                icon: const Icon(Icons.list_rounded, color: Colors.white),
                tooltip: '选集',
              ),
              IconButton(
                onPressed: onFullscreen,
                icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                tooltip: '全屏（F）',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ---------------------------------------------------------------- 选集

class _EpisodeSheet extends StatelessWidget {
  const _EpisodeSheet({required this.episodes, required this.current});

  final List<AnimeEpisode> episodes;
  final int current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选集（共 ${episodes.length} 集）',
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ep in episodes)
                      ChoiceChip(
                        label: Text('${ep.index}'),
                        selected: ep.index == current,
                        onSelected: (_) => Navigator.of(context).pop(ep.index),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 错误面板

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.title,
    required this.message,
    required this.needsLogin,
    required this.onRetry,
    required this.onLogin,
    required this.onBack,
  });

  final String title;
  final String message;
  final bool needsLogin;
  final VoidCallback onRetry;
  final VoidCallback onLogin;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xF2000000),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                needsLogin ? Icons.lock_outline_rounded : Icons.error_outline,
                color: Colors.white70,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                children: [
                  if (needsLogin)
                    FilledButton(
                      onPressed: onLogin,
                      child: const Text('登录次元城'),
                    ),
                  FilledButton.tonal(
                    onPressed: onRetry,
                    child: const Text('重试'),
                  ),
                  TextButton(onPressed: onBack, child: const Text('返回')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
