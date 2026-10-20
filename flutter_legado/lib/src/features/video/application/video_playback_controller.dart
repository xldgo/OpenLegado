import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../domain/contracts/book_source_repository.dart';
import '../../../domain/contracts/reading_repository.dart';
import '../../../domain/contracts/video_danmaku_service.dart';
import '../../../domain/contracts/video_progress_repository.dart';
import '../../../models/models.dart';
import '../../../services/video_float_window.dart';
import '../../../utils/video_play_utils.dart';
import 'video_play_settings.dart';
import 'video_playback_request.dart';

/// 视频播放仍独占音频焦点，避免继承其他媒体后端的共享选项。— Codex + UI
final VideoPlayerOptions videoPlaybackOptions = VideoPlayerOptions(
  mixWithOthers: false,
);

/// 编排数据、播放器与资源归属；不读取页面context或Provider。— Codex + UI
final class VideoPlaybackController extends ChangeNotifier {
  VideoPlaybackController({
    required this.request,
    required this._reading,
    required this._sources,
    required this._danmaku,
    required this._progress,
    required this._floating,
    this._temporaryDirectory = getTemporaryDirectory,
    this._loadSettings = VideoPlaySettings.load,
    this._onMessage,
    this._onTip,
    this._onFloatEntered,
    this._onStartFull,
  });

  final VideoPlaybackRequest request;
  final ReadingRepository _reading;
  final BookSourceRepository _sources;
  final VideoDanmakuService _danmaku;
  final VideoProgressRepository _progress;
  final VideoFloatWindowCoordinator _floating;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<VideoPlaySettings> Function() _loadSettings;
  final void Function(String)? _onMessage, _onTip;
  final VoidCallback? _onFloatEntered, _onStartFull;
  bool _disposed = false;
  Future<void>? _started;
  int _generation = 0;
  bool get isActive => !_disposed;
  bool _isCurrent(int generation) =>
      isActive && !_handedToFloat && generation == _generation;
  void _change(VoidCallback change) {
    if (!isActive) return;
    change();
    notifyListeners();
  }

  /// 视频控制器
  late VideoPlayerController _controller;

  /// 控制器是否已创建（[VideoPlayerController] 为 late 字段，未创建时直接
  /// 读 `_controller` 会抛 LateInitializationError；`value.isInitialized`
  /// 只能表达「已创建但未就绪」，无法区分「字段未赋值」）
  bool _controllerCreated = false;

  /// 未创建时返回 null 的安全只读兜底（默认悬浮窗首播在控制器创建前即
  /// 判定移交：对齐原版 VideoPlayerActivity.kt:179-193，Activity 不建
  /// 播放器而直接转发 VideoPlayService，位置/播放态取持久化状态）
  VideoPlayerController? get _safeController =>
      _controllerCreated ? _controller : null;

  /// 控制器初始化 Future
  Future<void> _initializeVideoPlayerFuture = Future.value();

  // ===== 视频源书籍（章节播放）状态 =====
  List<BookChapter> _chapters = const [];
  int _chapterIndex = 0;
  bool _loadingChapter = true;
  String? _chapterError;

  /// 书源原始 header（JSON / 行格式），每集再与 UrlOption 合并
  Map<String, String> _sourceHeaders = const {};

  /// 当前集交给播放器的 header（对齐 AnalyzeUrl.headerMap）
  Map<String, String> _videoHeaders = const {};

  /// 当前实际播放地址（网络 URL 或本地 MPD file URI）
  String _currentPlayUrl = '';

  /// MPD 临时文件（切换章/退出时清理）
  File? _mpdTempFile;

  // ===== [V-B3] 悬浮窗移交状态 =====

  /// 悬浮窗回全屏/接管后的预置播放目标（不重新解析章节正文）
  VideoPlayTarget? _presetTarget;

  /// 状态已移交悬浮窗（页面正在退出；禁止再 setState/起播）
  bool _handedToFloat = false;

  /// 默认悬浮窗播放：首次解析成功后只判定一次
  /// （对齐原版仅 Activity 创建时转发，VideoPlayerActivity.kt:177-193）
  bool _autoFloatPending = true;

  /// 悬浮窗回全屏的播放态覆写（null = 沿用 autoPlay 设置）
  bool? _resumePlayingOverride;

  /// 悬浮窗回全屏时书籍续播的绝对章节索引
  int? _resumeChapterIndex;

  VideoPlaySettings _playSettings = VideoPlaySettings();

  // ===== [P4-3 波次1b V3] 选集/倍速（对齐原版 gsyVideo） =====

  /// 当前播放倍速（会话级，对齐原版 VideoPlayer.playSpeed：
  /// 视图级成员、切集保留、不持久化；1.0 = 正常）
  double _playbackSpeed = 1.0;

  // ===== [V-B4] 直链进度（video_pos_）与自然播完连播 =====

  /// 直链进度存取（仅直链模式；经既有 config/caches 通道，20 天 TTL）
  VideoProgressRepository? _directPosStore;

  /// 本次起播要恢复的位置（毫秒）：直链 = video_pos_ 读值；
  /// 书籍 = 初始章的 durChapterPos（换集 saveRead(0) 后归零，对齐原版）
  int _pendingResumeMs = 0;

  /// 直链进度定期落盘定时器（原版仅 onDestroy/onError 落盘，此处加固；
  /// 进程被杀时减少进度丢失）
  Timer? _directPosTimer;

  /// 上一帧 completed 态：自然播完只在「未完成 → 完成」边沿触发一次连播
  bool _wasCompleted = false;

  // ===== [V-B4] 长按倍速 =====

  /// 是否正处于长按临时提速（对齐原版 isLongPressSpeed）
  bool _isLongPressSpeed = false;

  /// 当前生效倍速：长按期间 = 设置的长按档位，否则 = 会话倍速
  /// （对齐 VideoPlayer.kt:108-133；弹幕层与控制器共用该值）
  double get _effectivePlaybackSpeed => effectiveVideoSpeed(
    sessionSpeed: _playbackSpeed,
    longPressActive: _isLongPressSpeed,
    longPressSpeed: _playSettings.pressSpeedFactor,
  );

  List<VideoDanmakuItem> _danmakuItems = const [];
  bool _danmakuAvailable = false;

  VideoPlayerController? get player => _safeController;
  Future<void> get initialization => _initializeVideoPlayerFuture;
  List<BookChapter> get chapters => _chapters;
  int get chapterIndex => _chapterIndex;
  bool get loading => _loadingChapter;
  String? get error => _chapterError;
  bool get handedToFloat => _handedToFloat;
  String get currentUrl => _currentPlayUrl;
  VideoPlaySettings get settings => _playSettings;
  double get speed => _playbackSpeed;
  double get effectiveSpeed => _effectivePlaybackSpeed;
  bool get longPressActive => _isLongPressSpeed;
  List<VideoDanmakuItem> get danmakuItems => _danmakuItems;
  bool get danmakuAvailable => _danmakuAvailable;
  bool get supportsFloating => _floating.isSupported;
  Future<void> start() => _started ??= _start();
  Future<void> _start() async {
    try {
      final settings = await _loadSettings();
      if (!isActive) return;
      _change(() => _playSettings = settings);
      if (settings.startFull) _onStartFull?.call();
      await _bootstrapPlayback();
    } catch (error) {
      if (isActive) {
        _change(() {
          _loadingChapter = false;
          _chapterError = '$error';
        });
      }
    }
  }

  void updateSettings(VideoPlaySettings settings) =>
      _change(() => _playSettings = settings);
  void setSpeed(double speed) {
    _change(() => _playbackSpeed = speed);
    _safeController?.setPlaybackSpeed(speed);
  }

  void setLongPress(bool active) {
    _change(() => _isLongPressSpeed = active);
    _safeController?.setPlaybackSpeed(_effectivePlaybackSpeed);
  }

  /// 起播引导：显式预置（app.dart 经路由参数回全屏）或探测活动悬浮窗
  Future<void> _bootstrapPlayback() async {
    if (!isActive || _handedToFloat) return;
    await _applyExplicitOrActiveFloatState();
    if (!isActive || _handedToFloat) return;
    if (request.book != null) {
      await _loadBookVideo();
    } else {
      await _startDirectPlayback();
    }
  }

  /// 悬浮窗状态接入：
  /// - 路由显式携带 preset（回全屏导航）→ 直接采用；
  /// - 否则探测活动悬浮窗：同源 → 接管（停服 + 取最终位置），
  ///   异源 → 落库旧内容进度并关闭（probeAndTakeOver 内处理）。
  Future<void> _applyExplicitOrActiveFloatState() async {
    if (request.presetUrl != null) {
      _applyFloatState(
        VideoFloatWindowState(
          url: request.presetUrl!,
          headers: request.presetHeaders,
          positionMs: request.initialResumeMs,
          playing: request.initialPlaying,
          speed: request.initialSpeed,
          bookUrl: request.book?.bookUrl,
          chapterIndex: request.initialChapterIndex ?? -1,
          mpdTempPath: request.presetMpdPath,
        ),
      );
      return;
    }
    final taken = await _floating.probeAndTakeOver(
      bookUrl: request.book?.bookUrl,
      videoUrl: request.book == null ? request.videoUrl : null,
      reading: _reading,
      progress: _progress,
    );
    if (taken == null) return;
    if (!isActive) {
      final path = taken.mpdTempPath;
      if (path != null && path.isNotEmpty) await _deleteFile(File(path));
      return;
    }
    _applyFloatState(taken);
  }

  /// 把悬浮窗状态转为本页续播参数（原版 clonePlayState 语义）
  void _applyFloatState(VideoFloatWindowState state) {
    if (state.positionMs > 0) _pendingResumeMs = state.positionMs;
    _playbackSpeed = state.speed.clamp(0.5, 3.0);
    _resumePlayingOverride = state.playing;
    _videoHeaders = Map<String, String>.from(state.headers);
    if (state.chapterIndex >= 0) _resumeChapterIndex = state.chapterIndex;
    _presetTarget = VideoPlayTarget(
      url: state.url,
      headers: Map<String, String>.from(state.headers),
      mpdFilePath: state.mpdTempPath,
    );
  }

  /// 直链起播：读 20 天内进度 → 解析播放（对齐 VideoPlay.kt:143 seekOnStart）
  Future<void> _startDirectPlayback() async {
    final store = _progress;
    _directPosStore = store;
    // [V-B3] 悬浮窗回全屏：位置/URL 已随状态交回，不再读 video_pos_
    if (_presetTarget == null) {
      try {
        _pendingResumeMs = await store.read(request.videoUrl);
      } catch (_) {
        _pendingResumeMs = 0;
      }
    }
    if (!isActive || _handedToFloat) return;
    await _playDirectUrl(request.videoUrl);
    if (!isActive || _handedToFloat) return;
    // 定期落盘（原版仅 onDestroy/onError，此处加固防进程被杀丢进度）
    _directPosTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(saveDirectProgress()),
    );
  }

  /// 直链进度落盘（毫秒；未起播/读到 0 时跳过）
  Future<void> saveDirectProgress() async {
    final store = _directPosStore;
    if (store == null || request.book != null) return;
    var pos = 0;
    // 页面可能在控制器创建前退出（dispose 落盘路径）
    final live = _safeController;
    try {
      pos = (live != null && live.value.isInitialized)
          ? live.value.position.inMilliseconds
          : 0;
    } catch (_) {
      pos = 0;
    }
    if (pos <= 0) return;
    try {
      await store.write(request.videoUrl, pos);
    } catch (_) {}
  }

  /// 直链模式：同样走复合 URL / header / MPD 解析；
  /// [V-B3] 悬浮窗回全屏时直接用交回的目标，不重复解析正文
  Future<void> _playDirectUrl(String raw) async {
    if (!isActive || _handedToFloat) return;
    final generation = ++_generation;
    _change(() {
      _loadingChapter = true;
      _chapterError = null;
    });
    try {
      final target =
          _presetTarget ??
          resolveVideoPlayTarget(
            content: raw,
            chapterUrl: raw,
            sourceHeaders: _sourceHeaders,
          );
      await _startFromTarget(target, generation);
      if (_isCurrent(generation)) _change(() => _loadingChapter = false);
    } catch (e) {
      if (_isCurrent(generation)) {
        _change(() {
          _loadingChapter = false;
          _chapterError = '$e';
        });
      }
    }
  }

  /// 视频源书籍：加载章节列表并播放当前可播章（对齐 VideoPlayerActivity）
  Future<void> _loadBookVideo() async {
    if (!isActive || _handedToFloat) return;
    final generation = ++_generation;
    final book = request.book!;
    _change(() => _loadingChapter = true);
    try {
      if (_sourceHeaders.isEmpty && book.origin.isNotEmpty) {
        try {
          final sources = await _sources.getBookSources();
          if (!_isCurrent(generation)) return;
          for (final s in sources) {
            if (s.bookSourceUrl == book.origin &&
                s.header != null &&
                s.header!.isNotEmpty) {
              _sourceHeaders = parseSourceHeaderMap(s.header!);
              break;
            }
          }
        } catch (_) {}
      }
      if (!_isCurrent(generation)) return;
      final chapters = await _reading.getChapters(book.bookUrl);
      if (!_isCurrent(generation)) return;
      _chapters = chapters;
      if (_chapters.isEmpty && book.origin.isNotEmpty) {
        final refreshed = await _reading.refreshToc(book.bookUrl, book.origin);
        if (!_isCurrent(generation)) return;
        _chapters = refreshed;
      }
      if (_chapters.isEmpty) {
        _change(() {
          _loadingChapter = false;
          _chapterError = '暂无章节';
        });
        return;
      }
      final preset = _presetTarget;
      final presetIndex = _resumeChapterIndex;
      final index =
          (preset != null &&
              presetIndex != null &&
              presetIndex >= 0 &&
              presetIndex < _chapters.length)
          ? presetIndex
          : findPlayableChapterIndex(
              _chapters.map((c) => c.isVolume).toList(),
              book.durChapterIndex,
            );
      _chapterIndex = index;
      if (preset != null) {
        // [V-B3] 悬浮窗回全屏：URL/位置/header 已交回，仅补弹幕数据后直接续播
        if (!_isCurrent(generation)) return;
        await _loadDanmakuForChapter(index, generation);
        if (!_isCurrent(generation)) return;
        await _startFromTarget(preset, generation);
        if (_isCurrent(generation)) {
          _change(() => _loadingChapter = false);
        }
        return;
      }
      // 初始章恢复书籍进度（对齐 VideoPlay.startPlay durChapterPos → seekOnStart）
      await playChapter(index, resumeMs: book.durChapterPos);
    } catch (e) {
      if (!_isCurrent(generation)) return;
      _change(() {
        _loadingChapter = false;
        _chapterError = '$e';
      });
    }
  }

  /// 加载当前章弹幕：§2.49 原文 → §2.50 Rust 纯函数解析 → 渲染层数据
  ///
  /// 无记录/读失败/解析失败一律降级为空列表（弹幕是增强层）；[raw] 非空
  /// 即显示开关（对齐原版 VideoPlayer.kt:266-272：原文非空但解析失败时
  /// 开关仍在、画面无弹幕）。
  Future<void> _loadDanmakuForChapter(int index, int generation) async {
    final book = request.book;
    if (book == null) return;
    final danmaku = _danmaku;
    String? raw;
    try {
      raw = await danmaku.getVideoDanmaku(
        bookUrl: book.bookUrl,
        chapterIndex: index,
      );
    } catch (_) {
      raw = null;
    }
    if (!_isCurrent(generation)) return;
    if (raw == null || raw.trim().isEmpty) {
      _change(() {
        _danmakuAvailable = false;
        _danmakuItems = const [];
      });
      return;
    }
    List<VideoDanmakuItem>? items;
    try {
      items = await danmaku.parseVideoDanmaku(raw: raw);
    } catch (_) {
      items = null;
    }
    if (!_isCurrent(generation)) return;
    _change(() {
      _danmakuAvailable = true;
      _danmakuItems = items ?? const [];
    });
  }

  /// 播放指定章节：正文 → [resolveVideoPlayTarget] → 播放器
  ///
  /// [resumeMs] 仅初始章携带书籍进度；换集（手动选集/自动连播）对齐原版
  /// `saveRead(0) → startPlay`，从 0 起播。
  Future<void> playChapter(int index, {int resumeMs = 0}) async {
    if (!isActive || _handedToFloat || index < 0 || index >= _chapters.length) {
      return;
    }
    final generation = ++_generation;
    final book = request.book!;
    final chapter = _chapters[index];
    if (chapter.isVolume) {
      final playable = findPlayableChapterIndex(
        _chapters.map((c) => c.isVolume).toList(),
        index,
      );
      if (playable == index && chapter.isVolume) {
        _change(() {
          _loadingChapter = false;
          _chapterError = '当前为卷标题，无播放地址';
        });
        return;
      }
      return playChapter(playable);
    }
    _change(() {
      _loadingChapter = true;
      _chapterError = null;
    });
    try {
      final content = book.origin.isNotEmpty
          ? await _reading.fetchChapterContent(
              book.bookUrl,
              chapter.url,
              book.origin,
            )
          : await _reading.getChapterContent(book.bookUrl, index);
      if (!_isCurrent(generation)) return;
      // [V-B2] 弹幕与正文同链加载：§2.49 原文 → §2.50 Rust 解析
      await _loadDanmakuForChapter(index, generation);
      if (!_isCurrent(generation)) return;
      final target = resolveVideoPlayTarget(
        content: content,
        chapterUrl: chapter.url,
        sourceHeaders: _sourceHeaders,
      );
      if (!target.isMpd && target.url.isEmpty) {
        _change(() {
          _loadingChapter = false;
          _chapterError = '章节未解析出视频地址';
        });
        return;
      }
      debugPrint(
        '[VideoPlay] chapter=${chapter.title} url=${target.url} '
        'mpd=${target.isMpd} headers=${target.headers.keys.toList()}',
      );
      _pendingResumeMs = resumeMs;
      await _startFromTarget(target, generation);
      if (!_isCurrent(generation)) return;
      _change(() {
        _loadingChapter = false;
        _chapterIndex = index;
      });
      unawaited(saveProgress(chapterPos: 0));
    } catch (e) {
      if (!_isCurrent(generation)) return;
      _change(() {
        _loadingChapter = false;
        _chapterError = '$e';
      });
    }
  }

  /// 将 [VideoPlayTarget] 落到播放器（含 MPD 落盘）
  Future<void> _startFromTarget(VideoPlayTarget target, int generation) async {
    // [V-B3] 默认悬浮窗播放：首次解析成功即移交（不起 Flutter 播放器）
    if (!_isCurrent(generation)) return;
    if (await _maybeAutoEnterFloat(target, generation)) return;
    if (!_isCurrent(generation)) return;
    // 首次起播时控制器尚未创建（_safeController == null）：跳过一次性的
    // 旧控制器回收；换集/重试时控制器必然已存在
    final previous = _safeController;
    _controllerCreated = false;
    if (previous != null) {
      try {
        previous.removeListener(_onPlayerValueChanged);
        await _retirePlayer(previous);
      } catch (_) {}
    }
    // 换集/重试重建控制器：completed 边沿状态归零
    _wasCompleted = false;
    // 同一预置MPD重试时保留当前文件，不能清理后再用原路径播放。
    final retained = _mpdTempFile?.path == target.mpdFilePath
        ? _mpdTempFile
        : null;
    if (retained != null) _mpdTempFile = null;
    await _clearMpdTemp();
    if (!_isCurrent(generation)) {
      if (retained != null) await _deleteFile(retained);
      return;
    }

    _videoHeaders = Map<String, String>.from(target.headers);

    // [V-B3] 悬浮窗回全屏：MPD 临时文件已由原生移交所有权，直接播放
    if (target.mpdFilePath != null && target.mpdFilePath!.isNotEmpty) {
      final file = File(target.mpdFilePath!);
      _mpdTempFile = file;
      _currentPlayUrl = file.uri.toString();
      _initPlayer(filePath: file.path);
      return;
    }

    if (target.isMpd) {
      final file = await _createMpd(target.mpdContent!, generation);
      if (file == null) return;
      _mpdTempFile = file;
      _currentPlayUrl = file.uri.toString();
      _initPlayer(filePath: file.path);
      return;
    }

    _currentPlayUrl = target.url;
    _initPlayer(networkUrl: target.url);
  }

  /// 默认悬浮窗播放（对齐原版 VideoPlayerActivity.kt:177-193）：
  /// 仅在首次解析成功后判定一次，成功移交返回 true（页面随即退出）。
  Future<bool> _maybeAutoEnterFloat(
    VideoPlayTarget target,
    int generation,
  ) async {
    if (!_autoFloatPending) return false;
    _autoFloatPending = false;
    if (!_playSettings.defaultFloatWindow ||
        _handedToFloat ||
        request.presetUrl != null) {
      return false;
    }
    return _handOffToFloatWindow(target, generation: generation);
  }

  /// [V-B3] 移交悬浮窗：Dart 保存 url/header/位置/倍速/播放态 → 原生服务
  /// 新建 Media3 ExoPlayer 续播（对齐原版 `VideoPlay.savePlayState` /
  /// `clonePlayState` 的「状态克隆」语义，VideoPlay.kt:386-398）。
  ///
  /// [positionMs] 省略时取 Flutter 控制器当前位置。
  Future<bool> _performHandoff(
    VideoPlayTarget target, {
    int? positionMs,
    required int generation,
  }) async {
    if (!_isCurrent(generation)) return false;
    // [W2] 非 Android 无全局悬浮窗概念：静默降级全屏播放页
    //（对齐 JS 入口 `!kIsWeb && Platform.isAndroid` 的既有降级语义）
    if (!_floating.isSupported) return false;
    final reading = _reading;
    final progress = _progress;
    final book = request.book;
    var mpdPath = target.mpdFilePath;
    if (target.isMpd && (mpdPath == null || mpdPath.isEmpty)) {
      final file = await _createMpd(target.mpdContent!, generation);
      if (file == null) return false;
      await _clearMpdTemp();
      if (!_isCurrent(generation)) {
        await _deleteFile(file);
        return false;
      }
      _mpdTempFile = file;
      mpdPath = file.path;
    }
    final playUrl = (mpdPath != null && mpdPath.isNotEmpty)
        ? File(mpdPath).uri.toString()
        : target.url;
    if (playUrl.isEmpty) return false;
    // 控制器可能尚未创建（默认悬浮窗首播）：未创建/未就绪时位置取持久化
    // 进度（对齐原版 VideoPlayService 转发路径 startPlay 的 seekOnStart，
    // VideoPlay.kt:143 直链 video_pos_ / :166 书籍 durChapterPos）
    final live = _safeController;
    final liveReady = live?.value.isInitialized ?? false;
    final pos =
        positionMs ??
        (liveReady ? live!.value.position.inMilliseconds : _pendingResumeMs);
    final title =
        book != null &&
            _chapters.isNotEmpty &&
            _chapterIndex >= 0 &&
            _chapterIndex < _chapters.length
        ? _chapters[_chapterIndex].title
        : request.title;
    final state = VideoFloatWindowState(
      url: playUrl,
      title: title,
      bookName: book?.name ?? '',
      headers: Map<String, String>.from(target.headers),
      positionMs: pos,
      // 未创建/未就绪：播放态取 autoPlay（对齐原版 startPlay 内部
      // `if (autoPlay) player.startPlayLogic()`，VideoPlay.kt:157）；
      // 已就绪则保持当前播放态（用户手动移交的 clonePlayState 语义）
      playing:
          _resumePlayingOverride ??
          (liveReady ? live!.value.isPlaying : _playSettings.autoPlay),
      speed: _playbackSpeed,
      bookUrl: book?.bookUrl,
      chapterIndex: _chapterIndex,
      chapterTitle: title,
      directUrl: book == null ? request.videoUrl : null,
      hasPrev: book != null && _chapters.isNotEmpty
          ? _chapterHasPlayable(_chapterIndex, -1)
          : false,
      hasNext: book != null && _chapters.isNotEmpty
          ? _chapterHasPlayable(_chapterIndex, 1)
          : false,
      mpdTempPath: mpdPath,
    );
    // 进度先落库（对齐原版 startFloatingWindow → savePlayState 即时保存语义）
    if (pos > 0) {
      if (book != null) {
        await saveProgress(chapterPos: pos);
      } else {
        final store = _directPosStore;
        if (store != null) {
          try {
            await store.write(request.videoUrl, pos);
          } catch (_) {}
        }
      }
    }
    if (!_isCurrent(generation)) return false;
    // [W1] 移交前确定性暂停本页播放器：原生 ExoPlayer 为异步 prepare，而本页
    // 要等 pop 转场结束才 dispose；不暂停则存在双播放器并行发声窗口（此前
    // 仅靠音频焦点仲裁兜底，非确定性）。播放态/位置已捕获进 state，不受影响。
    // 控制器未创建（默认悬浮窗首播）时无本页播放器可暂停，直接跳过。
    try {
      if (liveReady && live!.value.isPlaying) {
        await live.pause();
      }
    } catch (_) {}
    if (!_isCurrent(generation)) return false;
    final coordinator = _floating;
    final ok = await coordinator.enterWindow(
      state: state,
      book: book,
      chapters: book != null ? _chapters : null,
      sourceHeaders: _sourceHeaders,
      reading: reading,
      progress: progress,
    );
    if (!ok) {
      // [W2/W4] 失败提示按原因分流：权限缺失 → 引导授权；FGS 后台启动受限
      // → 引导回应用内重试；其他 → 中性失败提示
      if (!_isCurrent(generation)) return false;
      final reason = coordinator.lastEnterError;
      if (reason == 'no_overlay_permission') {
        await coordinator.requestOverlayPermission();
        if (isActive) {
          _onMessage?.call('请允许「显示在其他应用上层」后重试');
        }
      } else if (reason == 'background_start_rejected') {
        // 原版此类失败仅日志记录、无用户文案（BaseService
        // tryStartForegroundNotification），此处用中性描述
        if (isActive) {
          _onMessage?.call('请回到应用内后重试');
        }
      } else if (isActive) {
        _onMessage?.call('悬浮窗启动失败，请重试');
      }
      return false;
    }
    _handedToFloat = true;
    _mpdTempFile = null; // 所有权移交原生服务（关闭时按语义删除/交回）
    if (isActive) _onFloatEntered?.call();
    return true;
  }

  bool _chapterHasPlayable(int from, int delta) {
    var i = from + delta;
    while (i >= 0 && i < _chapters.length) {
      if (!_chapters[i].isVolume) return true;
      i += delta;
    }
    return false;
  }

  /// 悬浮窗入口（对齐原版 menu_float_window → startFloatingWindow）：
  /// 在当前播放内容上转全局悬浮窗
  Future<void> enterFloatWindow() async {
    if (_handedToFloat || _loadingChapter) return;
    final target = _currentFloatTarget();
    if (target == null) return;
    await _handOffToFloatWindow(target);
  }

  VideoPlayTarget? _currentFloatTarget() {
    final mpd = _mpdTempFile;
    if (mpd != null && _currentPlayUrl.isNotEmpty) {
      return VideoPlayTarget(
        url: _currentPlayUrl,
        headers: _videoHeaders,
        mpdFilePath: mpd.path,
      );
    }
    if (_currentPlayUrl.isEmpty) return null;
    return VideoPlayTarget(url: _currentPlayUrl, headers: _videoHeaders);
  }

  Future<void> _clearMpdTemp() async {
    final f = _mpdTempFile;
    _mpdTempFile = null;
    if (f == null) return;
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 上一集/下一集：跳过卷标题
  void switchChapter(int delta) {
    if (request.book == null || _chapters.isEmpty) return;
    var next = _chapterIndex + delta;
    while (next >= 0 && next < _chapters.length && _chapters[next].isVolume) {
      next += delta;
    }
    if (next < 0 || next >= _chapters.length) return;
    unawaited(playChapter(next));
  }

  /// 写回阅读进度（durChapterIndex / durChapterPos）
  Future<void> saveProgress({int? chapterPos}) async {
    final book = request.book;
    if (book == null) return;
    try {
      var pos = chapterPos;
      if (pos == null) {
        // 加载中退出页面（PopScope 落盘）时控制器可能尚未创建
        final live = _safeController;
        try {
          pos = (live != null && live.value.isInitialized)
              ? live.value.position.inMilliseconds
              : 0;
        } catch (_) {
          pos = 0;
        }
      }
      await _reading.updateReadingProgress(
        bookUrl: book.bookUrl,
        chapterIndex: _chapterIndex,
        chapterPos: pos,
      );
    } catch (_) {}
  }

  /// 错误态「重试」：book 模式重试当前章；直链模式重解析当前 URL
  Future<void> retry() {
    if (request.book != null) {
      if (_chapters.isEmpty) {
        return _loadBookVideo();
      } else {
        return playChapter(_chapterIndex);
      }
    }
    return _retryDirectPlayback();
  }

  /// 直链错误重试：先落盘当前位置再恢复播放
  /// （对齐原版 onError → saveRead() → mSeekOnStart = durChapterPos）
  Future<void> _retryDirectPlayback() async {
    if (!isActive || _handedToFloat) return;
    await saveDirectProgress();
    if (!isActive || _handedToFloat) return;
    final store = _directPosStore;
    if (store != null) {
      try {
        _pendingResumeMs = await store.read(request.videoUrl);
      } catch (_) {
        _pendingResumeMs = 0;
      }
    }
    if (!isActive) return;
    await _playDirectUrl(request.videoUrl);
  }

  /// 初始化视频播放器（网络或本地 MPD 文件）
  void _initPlayer({String? networkUrl, String? filePath}) {
    if (!isActive || _handedToFloat) return;
    _installedGeneration = _generation;
    // 本函数所有分支都会给 _controller 赋值；先置创建标记，
    // 供 [_safeController] 区分「字段未赋值」与「播放器未就绪」
    _controllerCreated = true;
    if (filePath != null && filePath.isNotEmpty) {
      _controller = VideoPlayerController.file(
        File(filePath),
        videoPlayerOptions: videoPlaybackOptions,
      );
      _wireControllerInit();
      return;
    }

    final videoUrl =
        networkUrl ??
        (_currentPlayUrl.isNotEmpty ? _currentPlayUrl : request.videoUrl);
    if (networkUrl != null) _currentPlayUrl = networkUrl;
    final uri = Uri.tryParse(videoUrl);
    if (uri == null || videoUrl.isEmpty) {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(''),
        videoPlayerOptions: videoPlaybackOptions,
      );
      _initializeVideoPlayerFuture = Future<void>.error(Exception('无效的视频地址'));
      _observeInitialization();
      return;
    }

    _controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: _videoHeaders,
      videoPlayerOptions: videoPlaybackOptions,
    );
    _wireControllerInit();
  }

  /// 初始化后恢复进度并自动播放（对齐 VideoPlay.seekOnStart）
  void _wireControllerInit() {
    final player = _controller;
    final generation = _generation;
    final resumeMs = _pendingResumeMs;
    bool current() =>
        _isCurrent(generation) && identical(_safeController, player);
    player.addListener(_onPlayerValueChanged);
    _initializeVideoPlayerFuture = () async {
      try {
        await player.initialize();
        if (!current()) return;
        if (resumeMs > 0) {
          try {
            await player.seekTo(Duration(milliseconds: resumeMs));
          } catch (_) {}
          if (!current()) return;
        }
        _change(() {});
        if (!current()) return;
        final shouldPlay = _resumePlayingOverride ?? _playSettings.autoPlay;
        _resumePlayingOverride = null;
        if (shouldPlay) {
          await player.play();
          if (!current()) return;
        }
        if (_effectivePlaybackSpeed != 1.0) {
          await player.setPlaybackSpeed(_effectivePlaybackSpeed);
          if (!current()) return;
        }
        _change(() {});
      } catch (error, stack) {
        if (!current()) return;
        Error.throwWithStackTrace(error, stack);
      }
    }();
    _observeInitialization();
  }

  void _observeInitialization() {
    // 退场或换集后FutureBuilder可能不再订阅，仍消费旧初始化的错误。
    unawaited(
      _initializeVideoPlayerFuture.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {},
      ),
    );
  }

  /// 播放器值变化：仅在自然播完边沿触发连播
  /// （对齐 onAutoCompletion，VideoPlayer.kt:185-188）
  void _onPlayerValueChanged() {
    if (!isActive ||
        _handedToFloat ||
        _installedGeneration != _generation ||
        !_controllerCreated) {
      return;
    }
    final completed = _controller.value.isCompleted;
    if (shouldAdvanceOnCompletion(
      wasCompleted: _wasCompleted,
      isCompleted: completed,
    )) {
      _wasCompleted = true;
      unawaited(_onPlaybackCompleted());
    } else if (!completed) {
      _wasCompleted = false;
    }
  }

  /// 自然播完：自动切下一集；无下一集 → 提示「已播放完」
  ///
  /// 对齐 VideoPlay.upDurIndex(1)（VideoPlay.kt:474-490）：越界 toast
  /// 「已播放完」；推进后是否自动开始播放仍由 autoPlay 决定
  /// （原版 startPlay 内 `if (autoPlay) player.startPlayLogic()`）。
  /// 用户主动停止/错误不产生 completed 边沿，自然不连播
  /// （对齐 onCompletion，VideoPlayer.kt:190-193）。
  Future<void> _onPlaybackCompleted() async {
    if (!isActive || request.book == null || _loadingChapter) return;
    final next = nextPlayableChapterIndex(
      _chapters.map((c) => c.isVolume).toList(),
      _chapterIndex,
    );
    if (next == null) {
      _onTip?.call('已播放完');
      return;
    }
    await playChapter(next);
  }

  int _installedGeneration = -1;
  final _retired = <Future<void>>[];
  Future<bool>? _handoff;
  Future<bool> _handOffToFloatWindow(
    VideoPlayTarget target, {
    int? positionMs,
    int? generation,
  }) async {
    if (_handoff != null) return _handoff!;
    final pending = _performHandoff(
      target,
      positionMs: positionMs,
      generation: generation ?? _generation,
    );
    _handoff = pending;
    try {
      return await pending;
    } finally {
      if (identical(_handoff, pending)) _handoff = null;
    }
  }

  Future<void> _retirePlayer(VideoPlayerController player) {
    final release = () async {
      try {
        await player.dispose();
      } catch (_) {}
    }();
    _retired.add(release);
    return release;
  }

  Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<File?> _createMpd(String content, int generation) async {
    final directory = await _temporaryDirectory();
    if (!_isCurrent(generation)) return null;
    final file = File(
      '${directory.path}/legado_video_${DateTime.now().microsecondsSinceEpoch}_$generation.mpd',
    );
    try {
      await file.writeAsString(content);
    } catch (_) {
      await _deleteFile(file);
      rethrow;
    }
    if (!_isCurrent(generation)) {
      await _deleteFile(file);
      return null;
    }
    return file;
  }

  Future<void> _released = Future.value();
  Future<void> get released => _released;
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _directPosTimer?.cancel();
    final progress = saveDirectProgress();
    final live = _safeController;
    _controllerCreated = false;
    live?.removeListener(_onPlayerValueChanged);
    if (live != null) unawaited(_retirePlayer(live));
    final handoff = _handoff;
    _released = () async {
      await progress;
      await Future.wait(_retired);
      if (handoff != null) {
        try {
          await handoff;
        } catch (_) {}
      }
      await _clearMpdTemp();
      final presetPath = _presetTarget?.mpdFilePath ?? request.presetMpdPath;
      if (!_handedToFloat && presetPath != null && presetPath.isNotEmpty) {
        await _deleteFile(File(presetPath));
      }
    }();
    unawaited(_released);
    super.dispose();
  }
}
