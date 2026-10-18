import '../application/video_playback_controller.dart';
import '../application/video_playback_request.dart';
import '../../../providers/reading_provider.dart';
import '../../book_sources/book_source_repository_provider.dart';
import '../../../providers/media_provider.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/legado_app_bar.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../models/models.dart';
import '../../../services/video_float_window.dart';
import '../../../widgets/app_progress_indicator.dart';
import '../../../widgets/video_danmaku_layer.dart';
import '../../../widgets/video_float_window_button.dart';
import '../../../widgets/video_long_press_speed.dart';
import '../../../widgets/video_settings_dialog.dart';

class VideoScreen extends ConsumerStatefulWidget {
  /// 视频播放地址
  final String videoUrl;

  /// 视频标题（显示在 AppBar）
  final String title;

  /// 视频源书籍（非空时启用章节列表与切换）
  final Book? book;

  // ===== [V-B3] 悬浮窗回全屏的续播参数（对齐原版 isNew=false 转移） =====

  /// 已解析的播放地址（悬浮窗原生层交回；null = 按常规流程解析）
  final String? presetUrl;

  /// 与 [presetUrl] 配套的 header
  final Map<String, String> presetHeaders;

  /// 与 [presetUrl] 配套的 MPD 临时文件路径（所有权随回全屏交回本页）
  final String? presetMpdPath;

  /// 续播位置（毫秒）
  final int initialResumeMs;

  /// 书籍模式续播的绝对章节索引
  final int? initialChapterIndex;

  /// 会话倍速（悬浮窗切回后保持，对齐原版 playSpeed 视图级语义）
  final double initialSpeed;

  /// 悬浮窗内的播放态（false = 回到页面后保持暂停）
  final bool initialPlaying;

  const VideoScreen({
    super.key,
    required this.videoUrl,
    this.title = '视频播放',
    this.book,
    this.presetUrl,
    this.presetHeaders = const {},
    this.presetMpdPath,
    this.initialResumeMs = 0,
    this.initialChapterIndex,
    this.initialSpeed = 1.0,
    this.initialPlaying = true,
  });

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  /// 浮层提示文案（对齐原版 tip_view / showOverlayTip）
  String? _tipText;

  /// 提示自动隐藏定时器（原版 showOverlayTip(delay) 2 秒后淡出）
  Timer? _tipTimer;

  /// 原版 showOverlayTip(message, 2000)：居中提示，[durationMs] 后自动消失
  void _showTip(String text, {int durationMs = 2000}) {
    setState(() => _tipText = text);
    _tipTimer?.cancel();
    _tipTimer = Timer(Duration(milliseconds: durationMs), () {
      if (mounted) setState(() => _tipText = null);
    });
  }

  /// 原版 showOverlayTip()（无参）：立即隐藏提示（长按松手时调用）
  void _hideTip() {
    _tipTimer?.cancel();
    if (_tipText != null && mounted) setState(() => _tipText = null);
  }

  /// 选集（对齐原版 showEpisodeDialog：选集 → chapterInVolumeIndex=position
  /// → saveRead(0) → startPlay；此侧经 [_playback.playChapter] 解析播放并写回进度）
  Future<void> _openEpisodeDialog() async {
    if (widget.book == null || _playback.chapters.isEmpty) return;
    final index = await showVideoEpisodeDialog(
      context,
      episodes: [
        for (var i = 0; i < _playback.chapters.length; i++)
          VideoEpisodeItem(title: _playback.chapters[i].title, chapterIndex: i),
      ],
      currentChapterIndex: _playback.chapterIndex,
    );
    if (index != null && mounted && index != _playback.chapterIndex) {
      unawaited(_playback.playChapter(index));
    }
  }

  /// 倍速档位选择（对齐原版 showSpeedDialog：playSpeed=value → setSpeed →
  /// 入口文案「X.XX X」+ 提示「X倍播放中」2 秒；1.0 时入口回「倍速」无提示）
  Future<void> _openSpeedDialog() async {
    final value = await showVideoSpeedDialog(
      context,
      currentSpeed: _playback.speed,
    );
    if (value == null || !mounted) return;
    _playback.setSpeed(value);
    if (value != 1.0) {
      _showTip(speedTipLabel(value));
    }
  }

  /// 长按倍速：播放中长按 → 临时提速到设置档位
  /// （对齐 VideoPlayer.kt:108-115：setVideoSpeed + tip + isLongPressSpeed）
  void _startLongPressSpeed() {
    if (_playback.longPressActive || !_playback.player!.value.isPlaying) return;
    final speed = _playback.settings.pressSpeedFactor;
    _playback.setLongPress(true);
    _showTip(longPressSpeedTipLabel(speed));
    // 弹幕层经 _playback.effectiveSpeed 联动（对齐 setVideoSpeed 内
    // danmakuSpeed-(speed-1)/6，见 VideoPlayer.kt:135-141）
  }

  /// 松手恢复会话倍速并隐藏提示（对齐 touchSurfaceUp，VideoPlayer.kt:124-133）
  void _endLongPressSpeed() {
    if (!_playback.longPressActive) return;
    _playback.setLongPress(false);
    _hideTip();
    // 原版 resolveDanmakuStart(当前位置)：弹幕层在倍速 prop 变更时
    // 以当前插值位置重锚（video_danmaku_layer.dart didUpdateWidget）
  }

  late final VideoPlaybackController _playback;
  bool _bound = false;
  bool _isFullScreen = false, _showControls = true, _danmakuShow = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bound) return;
    _playback = VideoPlaybackController(
      request: VideoPlaybackRequest(
        videoUrl: widget.videoUrl,
        title: widget.title,
        book: widget.book,
        presetUrl: widget.presetUrl,
        presetHeaders: widget.presetHeaders,
        presetMpdPath: widget.presetMpdPath,
        initialResumeMs: widget.initialResumeMs,
        initialChapterIndex: widget.initialChapterIndex,
        initialSpeed: widget.initialSpeed,
        initialPlaying: widget.initialPlaying,
      ),
      reading: ref.read(readingRepositoryProvider),
      sources: ref.read(bookSourceRepositoryProvider),
      danmaku: ref.read(videoDanmakuServiceProvider),
      progress: ref.read(videoProgressRepositoryProvider),
      floating: VideoFloatWindowCoordinator.instance,
      onTip: _showTip,
      onMessage: (message) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      },
      onFloatEntered: () {
        if (mounted) Navigator.of(context).pop();
      },
      onStartFull: () {
        if (mounted && !_isFullScreen) _toggleFullScreen();
      },
    )..addListener(_onPlaybackChanged);
    _bound = true;
    unawaited(_playback.start());
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    if (_bound) {
      _playback.removeListener(_onPlaybackChanged);
      _playback.dispose();
    }
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    super.dispose();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        // 移交悬浮窗时进度已在移交前落库（_handOffToFloatWindow）；此处
        // 若继续读「已无本地控制器」的位置会把进度覆盖成 0
        //（默认悬浮窗首播移交后本页从未创建控制器）
        if (_playback.handedToFloat) return;
        if (widget.book != null) {
          unawaited(_playback.saveProgress());
        } else {
          // 直链退出落盘（对齐原版 onDestroy → saveRead）
          unawaited(_playback.saveDirectProgress());
        }
      },
      child: Scaffold(
        appBar: _isFullScreen
            ? null
            : LegadoAppBar(
                title: Text(
                  widget.book != null && _playback.chapters.isNotEmpty
                      ? _playback.chapters[_playback.chapterIndex].title
                      : widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // [LAYOUT_PLAN P3] 沉浸域仅顶栏动作行规范：动作顺序上一集/下一集/设置/全屏（本体不动）
                actions: [
                  // [V-B3][W2] 悬浮窗入口（对齐原版 menu_float_window：视频页
                  // 菜单第一组 always 动作；解析出播放地址后可用）。
                  // 仅 Android 提供：桌面/Web 无全局悬浮窗概念，与 JS 入口
                  // 一致降级为全屏播放页。
                  if (_playback.supportsFloating)
                    VideoFloatWindowButton(
                      onPressed:
                          (_playback.currentUrl.isNotEmpty &&
                              !_playback.loading)
                          ? () => unawaited(_playback.enterFloatWindow())
                          : null,
                    ),
                  if (widget.book != null && _playback.chapters.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Symbols.skip_previous_rounded),
                      tooltip: '上一集',
                      onPressed: _playback.chapterIndex > 0
                          ? () => _playback.switchChapter(-1)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Symbols.skip_next_rounded),
                      tooltip: '下一集',
                      onPressed:
                          _playback.chapterIndex < _playback.chapters.length - 1
                          ? () => _playback.switchChapter(1)
                          : null,
                    ),
                  ],
                  // P2-15：视频设置（对标原版 menu_config_settings → SettingsDialog）
                  IconButton(
                    icon: const Icon(Symbols.settings_rounded),
                    tooltip: '播放设置',
                    onPressed: () async {
                      final updated = await showVideoSettingsDialog(context);
                      if (updated != null && mounted) {
                        _playback.updateSettings(updated);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Symbols.fullscreen_rounded),
                    tooltip: '全屏',
                    onPressed: _toggleFullScreen,
                  ),
                ],
              ),
        body: _playback.error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.error_rounded,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '视频加载失败',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _playback.error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _playback.retry,
                        icon: const Icon(Symbols.refresh_rounded),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              )
            : _playback.loading
            // [STAGE-UI-P43UNIFY2 B3] 裸环换接统一封装（默认参数视觉等价）
            ? const Center(child: AppCircularProgressIndicator())
            : FutureBuilder<void>(
                future: _playback.initialization,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // [STAGE-UI-P43UNIFY2 B3] 裸环换接统一封装
                          AppCircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('正在加载视频...'),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Symbols.error_rounded,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '视频加载失败',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _playback.retry,
                              icon: const Icon(Symbols.refresh_rounded),
                              label: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return _buildPlayerView();
                },
              ),
      ),
    );
  }

  /// 播放区布局：视频占剩余高度（Expanded），控件/信息固定在底部，
  /// 避免宽屏片源 AspectRatio 按宽度算出超高画面导致
  /// `BOTTOM OVERFLOWED BY … PIXELS`（量子资源网等）。— Reasonix + UI
  Widget _buildPlayerView() {
    if (_isFullScreen) {
      // 全屏：画面铺满，控件叠在底部（对齐原版沉浸播放）
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black, child: _buildVideoSurface()),
          if (_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: _buildControlBar()),
            ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: ColoredBox(color: Colors.black, child: _buildVideoSurface()),
        ),
        SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_buildControlBar(), _buildVideoInfo()],
          ),
        ),
      ],
    );
  }

  /// 在可用约束内居中按比例绘制，绝不撑破父级
  Widget _buildVideoSurface() {
    final raw = _playback.player!.value.isInitialized
        ? _playback.player!.value.aspectRatio
        : 16 / 9;
    // 防御异常 size（宽/高对调或 0）导致比例极端
    final aspectRatio = (raw.isFinite && raw > 0.2 && raw < 5.0) ? raw : 16 / 9;

    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: VideoLongPressSpeedArea(
          enabled: _playback.player!.value.isPlaying,
          onSpeedUp: _startLongPressSpeed,
          onRestore: _endLongPressSpeed,
          onTap: () => setState(() => _showControls = !_showControls),
          onDoubleTap: () {
            setState(() {
              _playback.player!.value.isPlaying
                  ? _playback.player!.pause()
                  : _playback.player!.play();
            });
          },
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              VideoPlayer(_playback.player!),
              // [V-B2] 弹幕层：视频之上、控制层之下（对齐原版
              // video_layout_controller.xml 中 danmaku_view 的层序）
              if (_playback.danmakuAvailable)
                VideoDanmakuLayer(
                  items: _playback.danmakuItems,
                  player: _playback.player!,
                  show: _danmakuShow,
                  // [V-B4] 长按期间随临时倍速联动（VideoPlayer.kt:135-141）
                  playbackSpeed: _playback.effectiveSpeed,
                ),
              if (_showControls) _buildOverlayControls(),
              // [P4-3 波次1b V3] 原版 tip_view：画面居中提示（如「1.5倍播放中」）
              if (_tipText != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _tipText!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayControls() {
    return Container(
      color: Colors.black26,
      child: Center(
        child: IconButton(
          iconSize: 64,
          color: Colors.white,
          icon: Icon(
            _playback.player!.value.isPlaying
                ? Symbols.pause_rounded
                : Symbols.play_arrow_rounded,
          ),
          onPressed: () {
            setState(() {
              _playback.player!.value.isPlaying
                  ? _playback.player!.pause()
                  : _playback.player!.play();
            });
          },
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _playback.player!,
      builder: (context, value, _) {
        final position = value.position;
        final duration = value.duration;
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: _isFullScreen ? Colors.black : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: (v) {
                    final newPosition = Duration(
                      milliseconds: (duration.inMilliseconds * v).round(),
                    );
                    _playback.player!.seekTo(newPosition);
                  },
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      value.isPlaying
                          ? Symbols.pause_rounded
                          : Symbols.play_arrow_rounded,
                      color: _isFullScreen ? Colors.white : null,
                    ),
                    onPressed: () {
                      setState(() {
                        value.isPlaying
                            ? _playback.player!.pause()
                            : _playback.player!.play();
                      });
                    },
                  ),
                  Text(
                    _formatDuration(position),
                    style: TextStyle(
                      fontSize: 12,
                      color: _isFullScreen ? Colors.white70 : null,
                    ),
                  ),
                  const Text(' / ', style: TextStyle(fontSize: 12)),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      fontSize: 12,
                      color: _isFullScreen ? Colors.white70 : null,
                    ),
                  ),
                  // [V-B2] 弹幕开关（对齐原版控制器条 toggle_danmaku：
                  // 仅一个文本按钮「关弹幕/开弹幕」，无弹幕时 GONE）
                  if (_playback.danmakuAvailable)
                    TextButton(
                      onPressed: () =>
                          setState(() => _danmakuShow = !_danmakuShow),
                      child: Text(
                        _danmakuShow ? '关弹幕' : '开弹幕',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isFullScreen ? Colors.white : null,
                        ),
                      ),
                    ),
                  const Spacer(),
                  // [P4-3 波次1b V3] 选集/倍速入口。原版二者仅存在于全屏控制器
                  // （video_layout_controller_full.xml 的 episode_list /
                  // playback_speed；非全屏 video_layout_controller.xml 无此二项，
                  // findViewById 为 null 安全跳过），故仅全屏渲染。
                  // 原版自右向左顺序：next → 选集 → 倍速；此侧最右为全屏键，
                  // 选集/倍速置于其左侧，顺序：倍速、选集。
                  if (_isFullScreen) ...[
                    TextButton(
                      onPressed: _openSpeedDialog,
                      child: Text(
                        speedEntryLabel(_playback.speed),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (widget.book != null && _playback.chapters.isNotEmpty)
                      TextButton(
                        onPressed: _openEpisodeDialog,
                        child: const Text(
                          '选集',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                  ],
                  IconButton(
                    icon: Icon(
                      _isFullScreen
                          ? Symbols.fullscreen_exit_rounded
                          : Symbols.fullscreen_rounded,
                      color: _isFullScreen ? Colors.white : null,
                    ),
                    tooltip: _isFullScreen ? '退出全屏' : '全屏',
                    onPressed: _toggleFullScreen,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _playback.currentUrl.isNotEmpty
                ? _playback.currentUrl
                : widget.videoUrl,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
