import '../../features/audio/playback/media_session_coordinator.dart';
import '../../features/audio/playback/media_session_host.dart';
import '../../features/read_aloud/playback/read_aloud_controller.dart';
import '../../features/read_aloud/playback/read_aloud_host.dart';
import '../../features/read_aloud/read_aloud_settings_provider.dart';
export '../../features/read_aloud/playback/read_aloud_controller.dart'
    show kNoUsableEngineHint;
import '../../domain/contracts/bookshelf_repository.dart';
import '../../domain/contracts/cloud_tts_repository.dart';
import '../../domain/contracts/http_tts_repository.dart';
import '../../domain/contracts/http_tts_synthesizer.dart';
import '../../domain/contracts/read_aloud_voice_repository.dart';
import '../../app/bootstrap/application_dependencies.dart';
export 'audio_state.dart';
import '../../providers/config_settings_provider.dart';
import '../../providers/domain_config_provider.dart';
import '../../domain/contracts/audio_playback_settings_repository.dart';
import '../../domain/contracts/read_aloud_selection_repository.dart';
import '../../domain/contracts/audio_book_service.dart';
import '../../domain/contracts/reading_repository.dart';
import '../chapter_content_provider.dart';
import '../../domain/models/read_aloud_content.dart';

import '../../features/read_aloud/cloud_tts_providers.dart';
import '../../features/read_aloud/http_tts_voice_selection.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/book.dart';
import '../../services/audio_service.dart';
import '../../services/media_artwork_loader.dart';
import '../../services/media_session_models.dart';
import '../../features/privacy/privacy_controller.dart';
import '../../services/stream_audio_player.dart';
import '../../services/read_aloud_audio_player.dart';
import '../../platform/tts/system_tts.dart';
import '../../features/read_aloud/tts_providers.dart';
import '../../utils/audio_skip_policy.dart';
import 'audio_state.dart';
import '../../features/read_aloud/http_tts_seed.dart';
import 'read_aloud_preferences.dart';
import 'read_aloud_position.dart';

/// 朗读引擎 URL 归一：把历史「名称,URL」复合形态还原为裸 URL 模板
///
/// [P0 | 2026-10-03] 朗读条引擎选择器曾把 `'名称,URL'` 复合串写入
/// [TtsConfig.engineUrl]（read_aloud_bar.dart），而 Rust `tts_speak` 把该值
/// 原样当 URL 模板与缓存键（rust/legado-ffi/src/api/tts_speak_api.rs:57-59），
/// 请求以「名称」开头必然失败 → 选完引擎合成仍报错、朗读落降级提示。
/// 选择器已改为只存裸 URL；本函数是消费端（HTTP 合成前）的向后兼容兜底，
/// 兼容同一进程内残留的旧形态状态。
///
/// 归一策略（测试钉死）：
/// - 整串已以 `http://`/`https://` 开头 → 原样返回（URL 自身含逗号也不拆）；
/// - 否则取「首个其后紧跟 http(s):// 的逗号」之后的部分——名称本身含逗号
///   （`甲,乙,http://…`）时仍能定位真正的 URL 起点；
/// - 逗号后不是 http(s) 开头（如原版 POST 模板 `url,{json}`）→ 原样返回，
///   不做猜测性截断，交由合成管线报错。
///
/// 不采用「首个逗号硬拆」：名称可能含逗号，硬拆会把名称残段混进 URL。
String normalizeTtsEngineUrl(String engineUrl) {
  final trimmed = engineUrl.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  var index = trimmed.indexOf(',');
  while (index >= 0) {
    final rest = trimmed.substring(index + 1).trim();
    if (rest.startsWith('http://') || rest.startsWith('https://')) {
      return rest;
    }
    index = trimmed.indexOf(',', index + 1);
  }
  return trimmed;
}

/// 流媒体进度写库的位置增量阈值（毫秒）
///
/// 播放中高频 onProgress 回调下仅做内存比较，累计播放位置增量达到该阈值
/// 才真正写库（避免高频 IO）；生命周期节点（完成/切章/暂停/停止/退出）
/// 不受该阈值限制。[A3 | 2026-10-03]
const int kStreamProgressSaveDeltaMs = 5000;

/// 书级语速写库防抖窗口（滑条拖动期间合并为一次写库）[A2 | 2026-10-03]
const Duration kSpeedPersistDebounce = Duration(milliseconds: 600);

/// 分钟倒计时上限——对齐原版 SleepTimerDialog.MAX_MINUTES = 180
/// [A4 | 2026-10-03]
const int kMaxSleepTimerMinutes = 180;

/// 按章停止上限——对齐原版 MAX_CHAPTER_STOP_COUNT = 99
/// （ChapterStopTimer.kt:3）[A4 | 2026-10-03]
const int kMaxChapterStopCount = 99;

/// 全局朗读引擎持久化键
///
/// 对齐原版 `PreferKey.ttsEngine = "appTtsEngine"`（app/.../constant/PreferKey.kt:46
/// → `AppConfig.ttsEngine`，app/.../help/config/AppConfig.kt:506-509）：原版
/// 「全局」按钮把所选引擎写入该键，「书」按钮只写书级 `readConfig.ttsEngine`。
/// 本项目全局值经既有 config 存储（ConfigRepository）持久化，书级值经
/// `Book.copyWith(readConfig:)` + [BookshelfRepository.updateBook] 落 `books.readConfig` 列。
/// [引擎双持久化 | 2026-10-04]
const String kTtsEngineConfigKey = 'appTtsEngine';

/// 全局稳定 HTTP TTS 引擎 ID 持久化键
const String kTtsEngineIdConfigKey = 'appTtsEngineId';

/// 恢复进度「接近章尾」容差（毫秒）
///
/// [P1 竞态修复 | 2026-10-03] 存量进度 ≥ duration - 该值 时视为「本章已播完」，
/// 恢复时不再 seek（否则 seek 到章尾会立即触发完成回调 → 秒完切章级联）。
/// 依据：原版无对应恢复判定——完成的章不落可恢复位置：AudioPlay.next() 在
/// completeCurrentChapter 之后立即把 durChapterPos 清零；末章播完由
/// isPlayToEnd() 走 playNew() 从头播（AudioPlay.kt:615-621、752-778）。
/// 故按最小防护取「从头播」。取 1s：覆盖本应用完成判定
/// （stream_audio_player.dart：position ≥ duration-200ms 且停止）写入的完成值，
/// 并给真机时长/位置上报粒度留余量；不取 95% 比例阈值，避免长章节尾部真实
/// 续听位置（如 3 小时章的最后 2 分钟）被误判为播完。
const int kStreamRestoreNearEndToleranceMs = 1000;

/// 流媒体章节归属标识
///
/// [_playAudioBookStream] 发起 `playUrl` 时绑定，[StreamAudioPlayer] 在进度/
/// 完成回调中原样回传；回调先与当前 state.bookUrl/currentIndex 比对，归属
/// 不一致（切章后迟到的旧章事件）整条丢弃——旧章最终位置不得写进新章进度键，
/// 这是 P1 级联跳章的根因修复。[P1 竞态修复 | 2026-10-03]
typedef StreamChapterTag = ({String bookUrl, int chapterIndex});

/// 听书播放器 Riverpod Notifier
///
/// 双路径：
/// - 音频书（BookType.audio）：getAudioChapterMedia 取址 → StreamAudioPlayer
/// - TTS 朗读：HTTP 文件播放或系统直接朗读，统一会话完成回调推进段落
///
/// — Auto + UI｜2026-08-12（P0-2 流媒体接线；A1 批 TTS 真实播放 2026-10-03）
class AudioNotifier extends Notifier<AudioState> with ChangeNotifier {
  late final MediaSessionCoordinator _media;
  late final StreamAudioPlayer _streamPlayer;
  List<String> get prefetchDiagnostics => _readAloud.prefetchDiagnostics;
  late AudioPlaybackSettingsRepository _playbackSettings;
  late ReadAloudSelectionRepository _selections;

  late final BookshelfRepository _bookshelf = ref.read(
    bookshelfRepositoryProvider,
  );
  late final CloudTtsRepository _cloudTts = ref.read(
    cloudTtsRepositoryProvider,
  );
  late final HttpTtsRepository _httpTts = ref.read(httpTtsRepositoryProvider);
  late final HttpTtsSynthesizer _httpSynthesizer = ref.read(
    httpTtsSynthesizerProvider,
  );
  late final ReadAloudVoiceRepository _voices = ref.read(
    readAloudVoiceRepositoryProvider,
  );
  late ReadingRepository _reading;
  late AudioBookService _audioBook;

  // Riverpod 3 销毁回调不能再访问 Ref/state；只供退出保存使用。
  AudioState? _stateForDispose;

  static const int _kProgressThrottleMs = 400;

  int _playToken = 0;

  bool _introSkipEvaluated = false;
  AudioSkipWindow? _skipWindow;
  Book? _book;
  bool _disposed = false;
  int _lastProgressEmitMs = 0;

  /// A3：流媒体进度写库节流状态（bookUrl:chapterIndex → 最近写入位置）
  String _lastProgressSaveKey = '';
  int _lastProgressSavedPosMs = 0;

  /// A2：书级语速写库防抖（拖动期间合并；仅绑定书籍后落库）
  Timer? _speedPersistTimer;
  ({String bookUrl, double speed})? _pendingSpeedPersist;
  String _lastSpeedPersistKey = '';
  double? _lastSpeedPersistValue;

  /// A4：定时停止（下沉 Notifier，退出听书页不失效）
  ///
  /// 分钟倒计时剩余秒数（>0 时 duration 模式生效）
  int _sleepRemainingSeconds = 0;
  bool _finishCurrentChapterAfterTimer = false;
  bool _waitingForTimerChapterEnd = false;

  bool get finishCurrentChapterAfterTimer => _finishCurrentChapterAfterTimer;
  bool get isWaitingForTimerChapterEnd => _waitingForTimerChapterEnd;

  /// 按章停止剩余章数（>0 时 chapters 模式生效）
  int _chaptersToStopRemaining = 0;

  /// 分钟倒计时 ticker：1s 粒度仅用于 UI 展示；递减语义对齐原版
  /// doDs 的 60s 循环（`if (!pause)` 守卫，暂停期间冻结）
  Timer? _sleepTicker;

  /// 定时停止模式（分钟与按章互斥；均未启用为 off）
  SleepTimerMode get sleepTimerMode {
    if (_chaptersToStopRemaining > 0) return SleepTimerMode.chapters;
    if (_sleepRemainingSeconds > 0 || _waitingForTimerChapterEnd) {
      return SleepTimerMode.duration;
    }
    return SleepTimerMode.off;
  }

  /// 是否启用了定时停止（分钟倒计时或按章停止）
  bool get isSleepTimerActive => sleepTimerMode != SleepTimerMode.off;

  /// 分钟倒计时剩余秒数（未启用时为 0）
  int get sleepRemainingSeconds => _sleepRemainingSeconds;

  /// 按章停止剩余章数（未启用时为 0）
  int get chaptersToStopRemaining => _chaptersToStopRemaining;

  /// 定时剩余量展示文案（通知标题/锁屏副标题组合用；未启用时为空串）
  ///
  /// 形态对齐原版通知标题的括号段（BaseReadAloudService.kt:701-707、
  /// AudioPlayService.kt:873-879）：分钟倒计时为「剩余 N 分钟」，按章停止为
  /// 「剩余 N 章」。分钟数向上取整——与原版 timeMinute 每分钟减一的展示
  /// 节奏一致（开始 5 分钟先显示 5，走过 1 分钟后显示 4）。
  /// 未启用定时时必须为空串，不得让标题出现「剩余 0」字样。[第2项 | 2026-10-03]
  String get sleepTimerRemainingLabel {
    switch (sleepTimerMode) {
      case SleepTimerMode.chapters:
        return '剩余 $_chaptersToStopRemaining 章';
      case SleepTimerMode.duration:
        if (_waitingForTimerChapterEnd) return '计时已结束，读完本章后停止';
        return '剩余 ${(_sleepRemainingSeconds + 59) ~/ 60} 分钟';
      case SleepTimerMode.off:
        return '';
    }
  }

  late final ReadAloudController _readAloud;
  ValueNotifier<ReadAloudPosition?> get readAloudPosition =>
      _readAloud.readAloudPosition;
  ValueNotifier<bool> get followReadAloud => _readAloud.followReadAloud;
  void restoreReadAloudFollow() => _readAloud.restoreReadAloudFollow();
  void detachReadAloudFollow() => _readAloud.detachReadAloudFollow();
  int get currentParagraphIndex => _readAloud.currentParagraphIndex;
  int get paragraphCount => _readAloud.paragraphCount;
  List<String> get currentParagraphs => _readAloud.currentParagraphs;
  Book? get currentBook => _book?.bookUrl == state.bookUrl ? _book : null;
  bool get hasPrevParagraph => _readAloud.hasPrevParagraph;
  bool get hasNextParagraph => _readAloud.hasNextParagraph;
  bool get isAudioBookMode => state.isStreamMode;
  String? get currentMediaUrl => state.mediaUrl.isEmpty ? null : state.mediaUrl;
  int get streamPositionMs => state.positionMs;
  int get streamDurationMs => state.durationMs;

  void setAudioBookMode(bool isAudioBook) {
    if (state.isStreamMode == isAudioBook) return;
    _playToken++;
    _readAloud.interrupt();
    state = state.copyWith(
      isStreamMode: isAudioBook,
      mediaUrl: isAudioBook ? state.mediaUrl : '',
      positionMs: 0,
      durationMs: 0,
      lyric: isAudioBook ? state.lyric : null,
    );
  }

  @override
  AudioState build() {
    _playbackSettings = ref.read(audioPlaybackSettingsRepositoryProvider);
    _selections = ref.read(readAloudSelectionRepositoryProvider);
    _audioBook = ref.read(audioBookServiceProvider);
    _reading = ref.read(readingRepositoryProvider);
    final initialState = AudioState(config: TtsConfig());
    _stateForDispose = initialState;
    _streamPlayer = ref.read(streamAudioPlayerProvider);
    _media = MediaSessionCoordinator(
      host: MediaSessionHost(
        readState: () => state,
        writeState: (value) => state = value,
        currentToken: () => _playToken,
        isDisposed: () => _disposed,
        currentBook: () => currentBook,
        isBookHidden: (book) {
          final privacy = ref.read(privacyControllerProvider);
          return privacy.locked(privacy.find(book.bookUrl) ?? book);
        },
        timerLabel: () => sleepTimerRemainingLabel,
        readPosition: () => _readAloud.readAloudPosition.value,
        hasReadAloudUnits: () => _readAloud.hasUnits,
        paragraphIndex: () => _readAloud.currentParagraphIndex,
        paragraphCount: () => _readAloud.unitCount,
        loadPreferences: () =>
            ref.read(readAloudPreferencesProvider.notifier).load(),
        mediaButtonPerChapter: () =>
            ref.read(readAloudPreferencesProvider).mediaButtonPerNext,
        resumeOrPlay: resumeOrPlay,
        pause: pause,
        stop: stop,
        nextChapter: next,
        previousChapter: previous,
        nextParagraph: nextParagraph,
        previousParagraph: prevParagraph,
        seekReadAloud: seekToChapterPosition,
        persistStreamPosition: _persistStreamPosition,
      ),
      audioService: ref.read(audioServiceProvider),
      player: _streamPlayer,
      artwork: ref.read(mediaArtworkLoaderProvider),
      clock: ref.read(mediaMonotonicClockProvider),
    );
    listenSelf((previous, next) {
      _stateForDispose = next;
      _media.stateChanged(previous, next);
    });
    _readAloud = ReadAloudController(
      host: ReadAloudHost(
        readState: () => state,
        writeState: (value) => state = value,
        currentToken: () => _playToken,
        advanceToken: () => ++_playToken,
        isDisposed: () => _disposed,
        resolveEngineUrl: resolveTtsEngineUrl,
        resolveEngineId: resolveTtsEngineId,
        changed: notifyListeners,
        activateMedia: _media.activate,
        publishProgress: _media.publishProgress,
        reviseTimeline: _media.reviseTimeline,
        consumeChapterStop: _consumeChapterStopAtBoundary,
        nextChapter: next,
        previousChapter: previous,
        pause: pause,
        stop: stop,
        notifyPaused: _media.notifyPaused,
      ),
      content: ref.read(chapterContentServiceProvider),
      settings: ref.read(readAloudSettingsRepositoryProvider),
      httpTts: _httpTts,
      cloudTts: _cloudTts,
      voices: _voices,
      selections: _selections,
      httpSynthesizer: _httpSynthesizer,
      cloudSynthesizer: ref.read(cloudTtsSynthesizerProvider),
      cache: ref.read(ttsCacheRepositoryProvider),
      player: _streamPlayer,
      systemTts: ref.read(systemTtsServiceProvider),
    );
    // 完成回调按当前模式分发：音频书 → 下一章；TTS → 下一段
    _streamPlayer.onCompleted = (tag) {
      if (_disposed) return;
      if (state.isStreamMode) {
        // [P1] 迟到的旧章完成事件（切章后才送达）：丢弃，避免误触发再切一章
        if (!_isCurrentStreamChapter(tag)) return;
        unawaited(_onStreamCompleted());
        return;
      }
      _readAloud.handleCompleted(tag);
    };
    _streamPlayer.onError = (error, tag) {
      if (_disposed) return;
      if (state.isStreamMode) {
        if (!_isCurrentStreamChapter(tag)) return;
        pause();
        state = state.copyWith(
          state: PlayerState.error,
          errorMessage: '音频播放失败：$error',
        );
        return;
      }
      _readAloud.handleError(error, tag);
    };
    _streamPlayer.onProgress = (pos, dur, tag) {
      if (_disposed) return;
      if (!state.isStreamMode) {
        if (state.isPlaying) {
          _readAloud.handleProgress(pos, dur, tag);
        }
        return;
      }
      // [P1] 回调必须归属当前章：切章瞬间旧播放器 stop 前送达的最终回调
      // （position≈旧章时长）若按 state.currentIndex 归属会写进新章进度键，
      // 恢复逻辑随即 seek 到新章章尾 → 秒完 → 再切章，形成自持级联；
      // 归属不一致则整条丢弃（不写库、不刷新 UI）。
      if (!_isCurrentStreamChapter(tag)) return;
      // [A3] 播放中周期写进度：显式传入回调位置，位置增量 <5s 时仅内存比较不写库
      unawaited(_persistStreamPosition(positionMs: pos.inMilliseconds));
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastProgressEmitMs < _kProgressThrottleMs &&
          dur.inMilliseconds == state.durationMs) {
        // 片尾仍需检测
        unawaited(_maybeApplySkip(pos.inMilliseconds, dur.inMilliseconds));
        return;
      }
      _lastProgressEmitMs = now;
      state = state.copyWith(
        positionMs: pos.inMilliseconds,
        durationMs: dur.inMilliseconds,
      );
      unawaited(_maybeApplySkip(pos.inMilliseconds, dur.inMilliseconds));
    };
    ref.listen(privacyControllerProvider, (previous, next) {
      final book = currentBook;
      if (book != null &&
          previous?.locked(previous.find(book.bookUrl) ?? book) !=
              next.locked(next.find(book.bookUrl) ?? book)) {
        unawaited(_media.updateMetadata());
      }
    });
    ref.onDispose(() {
      // [A3] 容器销毁（退出听书/应用生命周期结束）尽力写一次当前进度
      _saveStreamProgressOnDispose();
      _speedPersistTimer?.cancel();
      // [A4] 定时停止 ticker 随容器销毁清理
      _sleepTicker?.cancel();
      _disposed = true;
      _readAloud.dispose(snapshot: _stateForDispose);
      _media.dispose();
    });
    return initialState;
  }

  Future<void> initMediaSession({String bookName = ''}) async {
    if (bookName.isNotEmpty) state = state.copyWith(bookName: bookName);
    await _media.init();
  }

  Future<void> releaseMediaSession() => _media.release();

  Future<void> loadChapters(String bookUrl) async {
    _readAloud.prepareBookLoad();
    if (state.bookUrl != bookUrl) {
      _playToken++;
      _readAloud.invalidateSpeech();
      if (state.bookUrl.isNotEmpty) {
        final token = _playToken;
        if (!await _readAloud.stopForChapterChange(token)) return;
      }
      // A4：切换书籍视为新朗读会话，重置无引擎提示的一次性标记
      _readAloud.clearNoEngineHint();
    }
    state = state.copyWith(
      bookUrl: bookUrl,
      state: PlayerState.loading,
      errorMessage: null,
    );
    final token = _playToken;

    try {
      var chapterList = await _reading.getChapters(bookUrl);
      if (_disposed || token != _playToken) return;
      final book = await _bookshelf.getBook(bookUrl);
      if (_disposed || token != _playToken) return;
      if (book != null) _book = book;
      if (chapterList.isEmpty) {
        final origin = book?.origin ?? '';
        if (origin.isNotEmpty) {
          chapterList = await _reading.refreshToc(bookUrl, origin);
          if (_disposed || token != _playToken) return;
        }
      }
      final inferredAudio =
          book != null && (book.bookType & BookType.audio) == BookType.audio;
      final chapters = chapterList
          .asMap()
          .entries
          .map(
            (e) => AudioChapter(index: e.key, title: e.value.title, text: ''),
          )
          .toList();
      state = state.copyWith(
        chapters: chapters,
        currentIndex: 0,
        state: PlayerState.idle,
        // 听书页已 setAudioBookMode(true) 时保留；否则按落库 type 位推断
        isStreamMode: state.isStreamMode || inferredAudio,
      );
    } catch (e) {
      if (_disposed || token != _playToken) return;
      state = state.copyWith(
        errorMessage: e.toString(),
        state: PlayerState.error,
      );
    }
  }

  /// 阅读器朗读入口（固定 TTS，不走音频书流媒体）
  Future<void> startReadAloud({
    required String bookUrl,
    required String bookName,
    int chapterIndex = 0,
    int? startChapterPos,
    String? startParagraphText,
  }) async {
    _readAloud.beginSession();
    setAudioBookMode(false);
    final token = ++_playToken;
    _readAloud.invalidateSpeech();
    if (!await _readAloud.stopForChapterChange(token)) return;
    final needReload = state.chapters.isEmpty || state.bookUrl != bookUrl;
    state = state.copyWith(
      bookUrl: bookUrl,
      bookName: bookName,
      isStreamMode: false,
      mediaUrl: '',
      positionMs: 0,
      durationMs: 0,
      lyric: null,
    );
    await initMediaSession(bookName: bookName);
    if (_disposed || token != _playToken) return;

    if (needReload) {
      await loadChapters(bookUrl);
      if (_disposed || token != _playToken) return;
      // loadChapters 可能按 type 位推断流媒体；朗读入口强制 TTS
      setAudioBookMode(false);
    }
    if (state.chapters.isEmpty) return;

    // [引擎双持久化 | 2026-10-04] 绑定当前书：书级引擎（readConfig.ttsEngine）
    // 的解析依赖当前书对象。此前阅读器入口不绑定（仅听书页 bindBook/
    // applyBookPreferences 绑定），书级值不会生效；同时顺带修正片头/片尾
    // 跳过取陈旧书配置的隐患（_resolveSkipWindow）。
    await _bindBookForEngine(bookUrl);
    if (_disposed || token != _playToken) return;
    await prepareReadAloudSettings();
    if (_disposed || token != _playToken) return;

    // 解析层级对齐原版 ReadAloud.ttsEngine = 书级 ?: 全局（ReadAloud.kt:41 →
    // AppConfig.kt:506-509）：书级为空时先读回持久化的全局值（原版
    // AppConfig.ttsEngine 重启保留），仍为空才自动选默认引擎（我方降级路径）。
    if (resolveTtsEngineUrl().isEmpty) {
      await _restorePersistedGlobalEngine();
      if (_disposed || token != _playToken) return;
    }
    if (resolveTtsEngineUrl().isEmpty) {
      await _ensureDefaultEngine();
      if (_disposed || token != _playToken) return;
    }

    final target = chapterIndex.clamp(0, state.chapters.length - 1).toInt();
    if (target != state.currentIndex) {
      state = state.copyWith(currentIndex: target);
    }
    await _readAloud.locateStart(
      sourceOffset: startChapterPos,
      text: startParagraphText,
    );
    if (_disposed || token != _playToken) return;
    await play();
  }

  Future<void> _ensureDefaultEngine() async {
    final token = _playToken;
    try {
      // [D3 | 2026-10-03] 首启/升级导入原版 httpTTS 种子（版本门控；
      // 失败不阻塞，仍按无引擎降级估算）。
      final engines = _httpTts;
      await ensureDefaultHttpTts(engines);
      final list = await engines.getHttpTts();
      if (_disposed || token != _playToken) return;
      if (list.isEmpty) return;
      // 规则语法能力已接入 POST/JS；远程可用性由合成响应和登录状态判断。
      final compatible = list.where((e) => isCompatibleHttpTtsEngineUrl(e.url));
      if (compatible.isEmpty) return;
      final defaultEngine = compatible.first;
      final url = defaultEngine.url.trim();
      if (url.isNotEmpty) {
        updateConfig(engineUrl: url, engineId: defaultEngine.id);
      }
    } catch (e) {
      debugPrint('获取默认朗读引擎失败: $e');
    }
  }

  // ===== 朗读引擎双持久化（书级 / 全局）=====
  //
  // 对齐原版 SpeakEngineDialog（app/.../ui/book/read/config/SpeakEngineDialog.kt）：
  // - 解析：书级 `Book.getTtsEngine()` 优先、空则全局 `AppConfig.ttsEngine`
  //   （ReadAloud.kt:41 → AppConfig.kt:506-509）；
  // - 「书」按钮:164-170 = 只写书级（`ReadBook.book?.setTtsEngine(ttsEngine)`），
  //   不改全局；
  // - 「全局」按钮:171-177 = 先清书级（`setTtsEngine(null)`）再写全局；
  // - 行点击:315-326 = 仅对话框内选中态（upTts），不持久化。

  /// 当前生效朗读引擎 URL：书级优先、空则全局回退（**单点解析**）
  ///
  /// 书级值取当前绑定书籍的 `readConfig.ttsEngine`（原版 Book.setTtsEngine，
  /// Book.kt:267-272 / 字段 :501）；全局值取 [AudioState.config] 的 engineUrl
  /// （用户经朗读条/管理页选择，见 [setGlobalTtsEngine]）。两个来源都经
  /// [normalizeTtsEngineUrl] 归一，历史「名称,URL」形态不会破坏解析。
  /// 播放链（[_speakCurrentParagraph]）与默认引擎判定（[startReadAloud]）
  /// 都必须走本方法，禁止在别处重复判断层级。
  String resolveTtsEngineUrl() {
    final bookLevel = normalizeTtsEngineUrl(_book?.readConfig?.ttsEngine ?? '');
    if (bookLevel.isNotEmpty) return bookLevel;
    return normalizeTtsEngineUrl(state.config.engineUrl);
  }

  /// 解析当前生效的 HTTP TTS 引擎 ID（数值标识稳定，支持合法非零负数）
  Future<int?> resolveTtsEngineId() async {
    final engineUrl = resolveTtsEngineUrl();
    if (engineUrl.isEmpty ||
        engineUrl == systemTtsEngineUrl ||
        isCloudTts(engineUrl)) {
      return null;
    }
    // 1. 如果 URL 是纯数字 ID（兼容存 ID 场景）
    final parsedId = int.tryParse(engineUrl);
    if (parsedId != null && parsedId != 0) {
      try {
        final repo = _httpTts;
        final list = await repo.getHttpTts();
        if (list.any((item) => item.id == parsedId)) {
          return parsedId;
        }
      } catch (e) {
        debugPrint('resolveTtsEngineId 校验 ID 失败: $e');
      }
      debugPrint('resolveTtsEngineId: 未在仓库中找到 ID 为 $parsedId 的引擎');
      return null;
    }
    // 2. 如果 config 中已显式配置合法 engineId，且匹配当前生效引擎 URL
    if (state.config.engineId != null &&
        state.config.engineId != 0 &&
        (normalizeTtsEngineUrl(state.config.engineUrl) == engineUrl ||
            state.config.engineUrl == engineUrl ||
            engineUrl.isEmpty)) {
      return state.config.engineId;
    }
    // 3. 从 HTTP TTS 仓库匹配 URL 获取 ID
    try {
      final repo = _httpTts;
      final list = await repo.getHttpTts();
      final normalized = normalizeTtsEngineUrl(engineUrl);
      for (final item in list) {
        if (item.id != 0 &&
            (normalizeTtsEngineUrl(item.url) == normalized ||
                item.url == engineUrl)) {
          return item.id;
        }
      }
    } catch (e) {
      debugPrint('resolveTtsEngineId 查找引擎失败: $e');
    }
    debugPrint('resolveTtsEngineId: 未在仓库中找到匹配引擎 (url: $engineUrl)');
    return null;
  }

  /// 是否存在可写书级的当前书（UI「书」按钮可用性判定）
  bool get hasCurrentBook => _currentBookUrl().isNotEmpty;

  /// 书级引擎写入（对齐原版「书」按钮，SpeakEngineDialog.kt:164-170）
  ///
  /// 只写当前书的 `readConfig.ttsEngine`，不改全局值；写库复用既有
  /// `Book.copyWith(readConfig:)` + [BookshelfRepository.updateBook] 链路（同
  /// [_persistPlayMode]/[_persistSpeed] 先例），Rust 侧 `update_book` 全行
  /// 回写 readConfig 列（rust/legado-ffi/src/api/bookshelf.rs:68，
  /// rust/legado-db/.../book_repository.rs update）。无当前书返回 false
  /// （对齐原版 `ReadBook.book?.` 空安全语义，不静默假装成功）。
  Future<bool> setBookTtsEngine(String engineUrl, {int? engineId}) async {
    final url = normalizeTtsEngineUrl(engineUrl);
    if (url.isEmpty && (engineId == null || engineId == 0)) return false;
    final book = await _currentBookForEngine();
    if (book == null) return false;
    try {
      final cfg = book.readConfig ?? const ReadConfig();
      final selection = engineId != null && engineId != 0
          ? engineId.toString()
          : url;
      final updated = book.copyWith(
        readConfig: cfg.copyWith(ttsEngine: selection),
      );
      _book = updated;
      await _bookshelf.updateBook(updated);
      await restartCurrentTts();
      return true;
    } catch (e) {
      debugPrint('保存书级朗读引擎失败: $e');
      return false;
    }
  }

  /// 清书级引擎（对齐原版「全局」按钮的 `ReadBook.book?.setTtsEngine(null)`）
  ///
  /// 书级值本就为空时跳过写库（避免无意义 IO）；无当前书时静默跳过。
  Future<void> clearBookTtsEngine() async {
    final book = await _currentBookForEngine();
    if (book == null) return;
    if ((book.readConfig?.ttsEngine ?? '').isEmpty) return;
    try {
      final cfg = book.readConfig ?? const ReadConfig();
      final updated = book.copyWith(readConfig: cfg.copyWith(ttsEngine: null));
      _book = updated;
      await _bookshelf.updateBook(updated);
    } catch (e) {
      debugPrint('清除书级朗读引擎失败: $e');
    }
  }

  /// 全局引擎写入（对齐原版「全局」按钮，SpeakEngineDialog.kt:171-177）
  ///
  /// 同步策略照原版：先清当前书书级覆盖，再把所选引擎写全局。全局值双写——
  /// 内存 [AudioState.config].engineUrl（既有消费路径不变）+ config 存储
  /// [kTtsEngineConfigKey] 与稳定 [kTtsEngineIdConfigKey]（重启后由
  /// [_restorePersistedGlobalEngine] 读回，对齐原版 AppConfig.ttsEngine 持久化语义）。
  Future<void> setGlobalTtsEngine(String engineUrl, {int? engineId}) async {
    final url = normalizeTtsEngineUrl(engineUrl);
    if (url.isEmpty && (engineId == null || engineId == 0)) return;
    await clearBookTtsEngine();
    updateConfig(engineUrl: url, engineId: engineId, restartPlayback: false);
    try {
      await _selections.setEngine(url, httpEngineId: engineId);
    } catch (e) {
      debugPrint('持久化全局朗读引擎失败: $e');
    }
    await restartCurrentTts();
  }

  /// 有效引擎读回（管理页/朗读条对话框初始化选中态用）
  ///
  /// 顺序与 [resolveTtsEngineUrl] 一致；仅当书级与内存全局都为空时，才读回
  /// 持久化全局值（读到则同步应用到内存）。
  Future<String> loadEffectiveTtsEngineUrl() async {
    await _bindBookForEngine(_currentBookUrl());
    final resolved = resolveTtsEngineUrl();
    if (resolved.isNotEmpty) return resolved;
    return _restorePersistedGlobalEngine();
  }

  /// 取当前书的 URL（优先已绑定书，其次当前播放会话的 bookUrl）
  String _currentBookUrl() {
    final bound = _book?.bookUrl ?? '';
    if (bound.isNotEmpty) return bound;
    return state.bookUrl;
  }

  /// 取当前书对象（写书级引擎用；无书返回 null）
  Future<Book?> _currentBookForEngine() async {
    await _bindBookForEngine(_currentBookUrl());
    return _book;
  }

  /// 绑定当前书（仅换书时经 API 补读；失败置空，书级解析回退全局）
  Future<void> _bindBookForEngine(String bookUrl) async {
    if (bookUrl.isEmpty) return;
    if (_book?.bookUrl == bookUrl) return;
    _book = null;
    final token = _playToken;
    try {
      final book = await _bookshelf.getBook(bookUrl);
      if (!_disposed && token == _playToken) _book = book;
    } catch (e) {
      debugPrint('读取书级朗读引擎配置失败: $e');
    }
  }

  /// 读回持久化全局引擎并应用到内存（空/失败不改状态）
  Future<String> _restorePersistedGlobalEngine() async {
    final token = _playToken;
    try {
      final parsedId = await _selections.getHttpEngineId();
      if (parsedId != null && parsedId != 0) {
        try {
          final repo = _httpTts;
          final list = await repo.getHttpTts();
          final matched = list.where((e) => e.id == parsedId).firstOrNull;
          if (matched != null) {
            if (_disposed || token != _playToken) return '';
            final url = normalizeTtsEngineUrl(matched.url);
            updateConfig(
              engineUrl: url,
              engineId: matched.id,
              restartPlayback: false,
            );
            return url;
          }
        } catch (error) {
          debugPrint('读取已保存的朗读引擎失败，保留 ID：$error');
        }
        // 保留失效身份，让后续校验明确报错；不得按相同 URL 换成另一引擎。
        if (_disposed || token != _playToken) return '';
        updateConfig(
          engineUrl: parsedId.toString(),
          engineId: parsedId,
          restartPlayback: false,
        );
        return parsedId.toString();
      }
      final raw = await _selections.getEngineUrl();
      if (_disposed || token != _playToken) return '';
      final url = normalizeTtsEngineUrl(raw ?? '');
      if (url.isEmpty) return '';
      updateConfig(engineUrl: url, restartPlayback: false);
      return url;
    } catch (e) {
      debugPrint('读取持久化朗读引擎失败: $e');
      return '';
    }
  }

  Future<void> play({int? paragraphIndex}) async {
    if (state.chapters.isEmpty) return;
    if (state.isStreamMode) {
      await _playAudioBookStream();
      return;
    }
    // [引擎双持久化 | 2026-10-04] 听书页 TTS 入口（非 startReadAloud 路径）
    // 同样读回持久化全局引擎：原版 AppConfig.ttsEngine 对所有朗读入口生效；
    // 此处只读回、不自动选默认（默认选择仍归 startReadAloud，保持既有语义）。
    final token = _playToken;
    if (resolveTtsEngineUrl().isEmpty) {
      await _restorePersistedGlobalEngine();
    }
    if (_disposed || token != _playToken) return;
    await _readAloud.play(paragraphIndex: paragraphIndex);
  }

  Future<void> _playAudioBookStream() async {
    state = state.copyWith(state: PlayerState.loading, errorMessage: null);
    final token = ++_playToken;
    try {
      await _readAloud.stopSystem();
      if (token != _playToken || _disposed) return;
      var index = state.currentIndex;
      while (index < state.chapters.length) {
        final media = await _audioBook.getAudioChapterMedia(
          state.bookUrl,
          index,
        );
        if (token != _playToken || _disposed) return;
        final isVolume = media.isVolume;
        final mediaUrl = media.mediaUrl.trim();
        if (isVolume || mediaUrl.isEmpty) {
          if (index + 1 >= state.chapters.length) {
            state = state.copyWith(
              errorMessage: (!isVolume && mediaUrl.isEmpty)
                  ? '未获取到资源链接'
                  : '无可播放章节',
              state: PlayerState.error,
            );
            return;
          }
          index++;
          state = state.copyWith(currentIndex: index);
          continue;
        }
        final lyric = media.lyric?.trim();
        state = state.copyWith(
          currentIndex: index,
          mediaUrl: mediaUrl,
          positionMs: 0,
          durationMs: 0,
          lyric: (lyric == null || lyric.isEmpty) ? null : lyric,
          state: PlayerState.playing,
        );
        // [P1] 绑定本章归属：播放器在进度/完成回调中原样回传，切章后旧播放器
        // 迟到的回调据此被丢弃，不会写进新章进度键
        await _streamPlayer.playUrl(
          mediaUrl,
          speed: state.config.speed,
          tag: (bookUrl: state.bookUrl, chapterIndex: index),
        );
        if (token != _playToken || _disposed) return;
        await _media.activate();
        _introSkipEvaluated = false;
        _skipWindow = null;
        // 恢复进度；从头播放时再套用片头跳过
        var restoredPos = 0;
        try {
          final progress = await _audioBook.getAudioProgress(
            state.bookUrl,
            index,
          );
          restoredPos = progress;
          if (restoredPos > 1500 && token == _playToken && !_disposed) {
            if (_isNearChapterEnd(restoredPos)) {
              // [P1 辅修] 历史污染值/完成值按「本章已播完」处理：不 seek，
              // 从头播（依据见 kStreamRestoreNearEndToleranceMs 注释）
              restoredPos = 0;
            } else {
              await _streamPlayer.seek(Duration(milliseconds: restoredPos));
            }
          }
        } catch (e) {
          debugPrint('恢复音频进度失败: $e');
        }
        if (restoredPos <= 1500) {
          await _applyIntroSkipIfNeeded(token);
        }
        return;
      }
    } catch (e) {
      if (token != _playToken || _disposed) return;
      state = state.copyWith(
        errorMessage: e.toString(),
        state: PlayerState.error,
      );
    }
  }

  /// 回调归属校验：tag 是否为当前播放章节（bookUrl + chapterIndex 双匹配）
  ///
  /// 仅流媒体路径的进度/完成回调需要校验（TTS 本地播放不传 tag，恒不匹配）。
  bool _isCurrentStreamChapter(Object? tag) {
    if (tag is! StreamChapterTag) return false;
    return tag.bookUrl == state.bookUrl &&
        tag.chapterIndex == state.currentIndex;
  }

  /// 存量进度是否已到本章末尾（视为已播完）
  ///
  /// 时长未知（未初始化）时不做判定，保持既有恢复行为。
  bool _isNearChapterEnd(int positionMs) {
    final durationMs = _streamPlayer.duration.inMilliseconds;
    if (durationMs <= 0) return false;
    return positionMs >= durationMs - kStreamRestoreNearEndToleranceMs;
  }

  Future<void> _onStreamCompleted() async {
    if (!state.isStreamMode || state.state != PlayerState.playing) return;
    // [A4] 章自然播完：按章停止计数（单曲循环每次完成同样计数，
    // 对齐原版 STATE_ENDED → completeCurrentChapter → onChapterCompleted）
    if (_consumeChapterStopAtBoundary()) {
      stop(); // stop 内 force 写当前章进度（A3）
      return;
    }
    if (state.mode == AudioPlayMode.singleLoop) {
      // [A3] 单曲循环从章首重播：显式清零进度，避免周期写入导致「循环回到结尾」
      await _resetStreamProgress();
      await play();
      return;
    }
    // [A3] 播完（含片尾跳过）/ 自动切章前写当前章进度
    await _persistStreamPosition(force: true);
    if (state.hasNext) {
      await next();
      return;
    }
    stop();
  }

  Future<void> setCloudTtsVoice(String engineId, ReadAloudVoice? voice) async {
    if (voice != null &&
        (voice.engineType != 'cloud_tts' ||
            voice.engineId != engineId ||
            !voice.selectable)) {
      throw StateError('该音色不能用于此引擎');
    }
    await _selections.setCloudVoice(engineId, voice?.id);
    if (!_disposed && resolveTtsEngineUrl() == 'cloud://$engineId') {
      await restartCurrentTts();
    }
  }

  Future<void> setHttpTtsVoice(
    int id,
    ReadAloudVoice? voice, {
    String? emotionTag,
  }) async {
    if (voice != null &&
        (voice.engineType != 'http' ||
            voice.engineId != '$id' ||
            !voice.selectable)) {
      throw StateError('该音色不能用于此引擎');
    }
    if (voice != null) {
      final resolution = resolveHttpTtsVoice(id, [
        voice,
      ], HttpTtsVoiceSelection(voice.id, emotionTag: emotionTag));
      if (resolution.warning != null) throw StateError(resolution.warning!);
    }
    await _selections.setHttpVoice(
      id,
      voice == null
          ? null
          : HttpTtsVoiceSelection(voice.id, emotionTag: emotionTag),
    );
    if (_disposed ||
        state.isStreamMode ||
        resolveTtsEngineUrl() == systemTtsEngineUrl) {
      return;
    }
    final token = _playToken;
    if (await resolveTtsEngineId() == id && !_disposed && token == _playToken) {
      await restartCurrentTts();
    }
  }

  /// 起播时读取一次偏好；打开或重建控制条不写播放配置。
  Future<void> prepareReadAloudSettings() async {
    final token = _playToken;
    try {
      final preferences = ref.read(readAloudPreferencesProvider.notifier);
      await preferences.load();
      if (_disposed || token != _playToken) return;
      // 旧控制条保存的是书级语速；首次迁移保留当前书的手动值。
      final legacySpeed = _book?.readConfig?.playSpeed;
      if (!ref.read(readAloudPreferencesProvider).hasStoredManualSpeed &&
          legacySpeed != null) {
        await preferences.setManualSpeed(legacySpeed);
      }
      if (_disposed || token != _playToken) return;
      updateConfig(
        speed: ref.read(readAloudPreferencesProvider).effectiveSpeed,
        restartPlayback: false,
        persistBookSpeed: false,
      );
    } catch (error) {
      debugPrint('读取朗读偏好失败，保留当前播放参数：$error');
    }
  }

  Future<void> setReadAloudFollowSystem(bool follow) async {
    await ref
        .read(readAloudPreferencesProvider.notifier)
        .setFollowSystem(follow);
    if (_disposed || state.isStreamMode) return;
    updateConfig(
      speed: ref.read(readAloudPreferencesProvider).effectiveSpeed,
      persistBookSpeed: false,
    );
  }

  /// 停顿策略变化后从当前原文锚点重建队列，避免已经入队的下一段绕过新停顿。
  Future<void> setReadAloudParagraphInterval(int milliseconds) async {
    final token = _playToken, generation = _readAloud.generation;
    final playing = state.isPlaying;
    final anchor = readAloudPosition.value?.offset;
    await ref
        .read(readAloudPreferencesProvider.notifier)
        .setParagraphInterval(milliseconds);
    if (_readAloud.isStale(token, generation) ||
        state.isStreamMode ||
        anchor == null ||
        resolveTtsEngineUrl() == systemTtsEngineUrl) {
      return;
    }
    await _readAloud.rebuildAtPosition(anchor, playing: playing);
  }

  Future<void> setReadAloudSpeed(
    double speed, {
    bool activateManual = false,
  }) async {
    await ref
        .read(readAloudPreferencesProvider.notifier)
        .setManualSpeed(speed, activateManual: activateManual);
    if (_disposed || state.isStreamMode) return;
    updateConfig(
      speed: ref.read(readAloudPreferencesProvider).effectiveSpeed,
      persistBookSpeed: false,
    );
  }

  void registerReadAloudPages(
    String bookUrl,
    int chapter,
    String content,
    List<ReadAloudPageRange> ranges,
  ) => _readAloud.registerPages(bookUrl, chapter, content, ranges);
  Future<void> setContentSplit(ReadAloudSplitMode mode, String symbols) =>
      _readAloud.setContentSplit(mode, symbols);
  Future<void> refreshHttpPrefetchSettings() =>
      _readAloud.refreshPrefetchSettings();
  Future<void> refreshSystemTtsSettings() => _readAloud.refreshSystemSettings();
  Future<void> restartCurrentTts() => _readAloud.restart();
  Future<void> seekToChapterPosition(int chapterIndex, int offset) =>
      _readAloud.seekToChapterPosition(chapterIndex, offset);
  Future<void> seekToParagraph(int index) => _readAloud.seekToParagraph(index);
  Future<void> nextParagraph() => _readAloud.nextParagraph();
  Future<void> prevParagraph() => _readAloud.prevParagraph();

  bool ownsMediaTarget(
    MediaPlaybackTarget target, {
    bool matchChapter = true,
  }) => _media.ownsTarget(target, matchChapter: matchChapter);

  Future<void> seekFromMediaSession(MediaSeekRequest request) =>
      _media.seek(request);

  /// 绑定当前书籍（片头/片尾读 readConfig）
  void bindBook(Book? book) {
    _book = book;
    unawaited(_media.updateMetadata());
  }

  /// 听书唤醒锁（对齐 audioPlayWakeLock）
  Future<void> setWakeLockEnabled(bool enabled) async {
    await _media.setWakeLock(enabled);
    try {
      await _playbackSettings.update((s) => s.copyWith(wakeLock: enabled));
    } catch (_) {}
  }

  Future<bool> isWakeLockEnabled() async {
    try {
      return (await _playbackSettings.load()).wakeLock;
    } catch (_) {
      return false;
    }
  }

  Future<void> _applyIntroSkipIfNeeded(int token) async {
    if (_introSkipEvaluated || token != _playToken || _disposed) return;
    final dur = _streamPlayer.duration.inMilliseconds;
    if (dur <= 0) return;
    final window = await _resolveSkipWindow(dur);
    _skipWindow = window;
    _introSkipEvaluated = true;
    if (window == null) return;
    final seekTo = introSeekPosition(currentPositionMs: 0, window: window);
    if (seekTo == null) return;
    await _streamPlayer.seek(Duration(milliseconds: seekTo));
    state = state.copyWith(positionMs: seekTo, durationMs: dur);
  }

  Future<void> _maybeApplySkip(int positionMs, int durationMs) async {
    if (!state.isStreamMode || state.state != PlayerState.playing) return;
    if (!_introSkipEvaluated && positionMs <= 0) {
      await _applyIntroSkipIfNeeded(_playToken);
    }
    final window = _skipWindow ?? await _resolveSkipWindow(durationMs);
    _skipWindow = window;
    if (window == null) return;
    if (shouldSkipOutro(currentPositionMs: positionMs, window: window)) {
      await _onStreamCompleted();
    }
  }

  Future<AudioSkipWindow?> _resolveSkipWindow(int durationMs) async {
    var globalOpen = 0;
    var globalClose = 0;
    try {
      final settings = await _playbackSettings.load();
      globalOpen = settings.openCredits;
      globalClose = settings.closeCredits;
    } catch (_) {}
    final cfg = _book?.readConfig;
    final cfgMap = cfg == null
        ? null
        : <String, dynamic>{
            'openCredits': cfg.openCredits,
            'closeCredits': cfg.closeCredits,
            // freezed 暂无该字段：有书级非零片头/片尾则视为书级
            'useGlobalAudioSkip': cfg.openCredits == 0 && cfg.closeCredits == 0,
          };
    final open = resolveOpenCredits(readConfig: cfgMap, globalOpen: globalOpen);
    final close = resolveCloseCredits(
      readConfig: cfgMap,
      globalClose: globalClose,
    );
    return resolveAudioSkipWindow(
      durationMs: durationMs,
      introSeconds: open,
      outroSeconds: close,
    );
  }

  // ===== 定时停止（A4 批：计时下沉，退出听书页不失效）=====

  /// 启动分钟倒计时：默认到点停止，可选等待自然章末再停止并保存进度。
  ///
  /// 与按章停止互斥（对齐原版 setTimer → chapterStopTimer.clear()，
  /// BaseReadAloudService.kt:553-559）。递减仅在播放中进行（对齐原版
  /// doDs 的 `if (!pause)` 守卫，BaseReadAloudService.kt:586-601）：
  /// 暂停期间剩余时间冻结，恢复播放后继续。
  void startSleepTimer(int minutes, {bool finishCurrentChapter = false}) {
    final normalized = minutes.clamp(0, kMaxSleepTimerMinutes).toInt();
    _clearSleepTimerState();
    if (normalized > 0) {
      _sleepRemainingSeconds = normalized * 60;
      _finishCurrentChapterAfterTimer = finishCurrentChapter;
      _ensureSleepTicker();
    }
    notifyListeners();
    // [第2项] 定时启用/关闭立即反映到通知标题（签名去重）
    unawaited(_media.updateMetadata());
  }

  /// 修改当前时间模式的到点策略，不重置剩余秒数；等待章末时关闭即停止。
  void setFinishCurrentChapterAfterTimer(bool enabled) {
    if (sleepTimerMode != SleepTimerMode.duration) return;
    _finishCurrentChapterAfterTimer = enabled;
    if (!enabled && _waitingForTimerChapterEnd) {
      stop();
      return;
    }
    notifyListeners();
    unawaited(_media.updateMetadata());
  }

  /// 启动按章停止：自然播完 [chapters] 章后在章末停止（不再进入下一章）
  ///
  /// 语义对齐原版 [ChapterStopTimer.onChapterCompleted]（ChapterStopTimer.kt:29-33）：
  /// 每自然播完一章计数减一，归零触发停止；手动切章不计（原版仅在
  /// nextChapter(auto=true) / completeCurrentChapter 中计数）。
  void startChapterStop(int chapters) {
    final normalized = chapters.clamp(0, kMaxChapterStopCount).toInt();
    _clearSleepTimerState();
    if (normalized > 0) {
      _chaptersToStopRemaining = normalized;
    }
    notifyListeners();
    // [第2项] 剩余章数立即反映到通知标题（签名去重）
    unawaited(_media.updateMetadata());
  }

  /// 取消定时停止（分钟倒计时与按章停止同时清空）
  void cancelSleepTimer() {
    if (!isSleepTimerActive) return;
    _clearSleepTimerState();
    notifyListeners();
    // [第2项] 取消后标题恢复原形态并刷新通知
    unawaited(_media.updateMetadata());
  }

  void _clearSleepTimerState() {
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _sleepRemainingSeconds = 0;
    _chaptersToStopRemaining = 0;
    _finishCurrentChapterAfterTimer = false;
    _waitingForTimerChapterEnd = false;
  }

  void _ensureSleepTicker() {
    if (_sleepTicker != null) return;
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      // 对齐原版：暂停期间不计时（唤醒恢复后从剩余时间继续）
      if (!state.isPlaying) return;
      if (_sleepRemainingSeconds <= 0) return;
      _sleepRemainingSeconds--;
      if (_sleepRemainingSeconds <= 0) {
        if (_finishCurrentChapterAfterTimer) {
          _sleepTicker?.cancel();
          _sleepTicker = null;
          _waitingForTimerChapterEnd = true;
          notifyListeners();
          unawaited(_media.updateMetadata());
          return;
        }
        _clearSleepTimerState();
        notifyListeners();
        stop();
        return;
      }
      notifyListeners();
      // [第2项] 每秒 tick 均尝试刷新，内部按签名去重——
      // 仅剩余分钟整数变化时才真正重推通知（节流）
      unawaited(_media.updateMetadata());
    });
  }

  /// 章末边界计数：返回 true 表示已到按章停止点（调用方应停止而非切章）
  ///
  /// 仅在「章自然播完」路径调用（流媒体完成回调 / TTS 末段完成）；手动
  /// next()/jumpTo 不计数，保持与原版一致。
  bool _consumeChapterStopAtBoundary() {
    if (_waitingForTimerChapterEnd) return true;
    if (_chaptersToStopRemaining <= 0) return false;
    _chaptersToStopRemaining--;
    final shouldStop = _chaptersToStopRemaining <= 0;
    if (shouldStop) _chaptersToStopRemaining = 0;
    notifyListeners();
    // [第2项] 剩余章数在章末即时上通知（停止路径 stop() 再推一次，
    // 签名去重不会重复触发）
    unawaited(_media.updateMetadata());
    return shouldStop;
  }

  void pause({bool dueToInterruption = false}) {
    _readAloud.cancelBackground();
    _media.preparePause(dueToInterruption: dueToInterruption);
    if (state.state == PlayerState.playing ||
        state.state == PlayerState.loading) {
      _readAloud.cancelPendingAdvance();
      if (state.isStreamMode) {
        unawaited(_streamPlayer.pause());
        unawaited(_persistStreamPosition(force: true));
      } else {
        _readAloud.pause();
      }
      state = state.copyWith(state: PlayerState.paused);
      _media.notifyPaused();
    }
  }

  Future<void> resumeOrPlay() async {
    _media.prepareResume();
    if (state.state == PlayerState.paused &&
        !state.isStreamMode &&
        await _readAloud.resume()) {
      return;
    }
    if (state.state == PlayerState.paused &&
        state.isStreamMode &&
        _streamPlayer.isInitialized) {
      await _streamPlayer.resume();
      state = state.copyWith(state: PlayerState.playing);
      await _media.activate();
      return;
    }
    await play();
  }

  void stop() {
    final snapshot = state;
    _clearSleepTimerState();
    _media.invalidate();
    unawaited(_persistStreamPosition(force: true));
    _media.prepareResume();
    _playToken++;
    _readAloud.stop(snapshot);
    state = state.copyWith(
      state: PlayerState.idle,
      mediaUrl: '',
      positionMs: 0,
      durationMs: 0,
      lyric: null,
    );
    _media.notifyStopped();
  }

  Future<void> next() async {
    _readAloud.cancelBackground();
    if (!state.hasNext && state.mode != AudioPlayMode.singleLoop) return;
    if (!state.isStreamMode) {
      _playToken++;
      _readAloud.interrupt();
    }
    // [A3] 切章前写当前章进度（TTS 模式内部直接返回）
    await _persistStreamPosition(force: true);
    _readAloud.resetParagraphForChapter();
    if (state.mode == AudioPlayMode.singleLoop) {
      await play(paragraphIndex: 0);
      return;
    }
    state = state.copyWith(currentIndex: state.currentIndex + 1);
    await play(paragraphIndex: 0);
  }

  Future<void> previous() async {
    _readAloud.cancelBackground();
    if (!state.hasPrevious) return;
    if (!state.isStreamMode) {
      _playToken++;
      _readAloud.interrupt();
    }
    // [A3] 切章前写当前章进度
    await _persistStreamPosition(force: true);
    _readAloud.resetParagraphForChapter();
    state = state.copyWith(currentIndex: state.currentIndex - 1);
    await play(paragraphIndex: 0);
  }

  Future<void> jumpTo(int index) async {
    _readAloud.cancelBackground();
    if (index < 0 || index >= state.chapters.length) return;
    if (!state.isStreamMode) {
      _playToken++;
      _readAloud.interrupt();
    }
    // [A3] 切章前写当前章进度
    await _persistStreamPosition(force: true);
    _readAloud.resetParagraphForChapter();
    state = state.copyWith(currentIndex: index);
    await play(paragraphIndex: 0);
  }

  /// 切换播放模式并落库（书级 readConfig.playMode，对齐原版 AudioPlay.changePlayMode）
  Future<void> setMode(AudioPlayMode mode) async {
    if (state.mode == mode) return;
    state = state.copyWith(mode: mode);
    await _persistPlayMode(mode);
  }

  /// 调整朗读与听书倍速（对齐原版全局/书级倍速调节）
  void setSpeechRate(double speed) {
    updateConfig(speed: speed);
  }

  void updateConfig({
    String? engineUrl,
    int? engineId,
    String? voiceName,
    double? speed,
    double? pitch,
    double? volume,
    bool restartPlayback = true,
    bool persistBookSpeed = true,
  }) {
    final config = state.config;
    final oldEngine = resolveTtsEngineUrl();
    final updated = TtsConfig(
      engineUrl: engineUrl ?? config.engineUrl,
      engineId: engineId ?? (engineUrl != null ? null : config.engineId),
      voiceName: voiceName ?? config.voiceName,
      speed: speed != null ? speed.clamp(0.5, 3.0) : config.speed,
      pitch: pitch != null ? pitch.clamp(0.5, 2.0) : config.pitch,
      volume: volume != null ? volume.clamp(0.0, 1.0) : config.volume,
    );
    state = state.copyWith(config: updated);
    if (restartPlayback &&
        (state.isPlaying ||
            state.state == PlayerState.paused ||
            state.state == PlayerState.loading) &&
        !state.isStreamMode &&
        (oldEngine != resolveTtsEngineUrl() ||
            config.engineId != updated.engineId ||
            config.voiceName != updated.voiceName ||
            config.pitch != updated.pitch ||
            config.volume != updated.volume ||
            (resolveTtsEngineUrl() == systemTtsEngineUrl &&
                config.speed != updated.speed))) {
      _readAloud.observeControl(restartCurrentTts());
    }
    if (engineUrl != null && updated.engineUrl.trim().isNotEmpty) {
      // [A4] 用户配置了引擎：清除无引擎提示（可用性由后续合成结果验证）
      _readAloud.clearNoEngineHint();
      if (state.errorMessage == kNoUsableEngineHint) {
        state = state.copyWith(errorMessage: null);
      }
    }
    if (speed != null && persistBookSpeed) {
      _scheduleSpeedPersist(updated.speed);
    }
    if (speed != null && _streamPlayer.isInitialized) {
      if (state.isStreamMode || resolveTtsEngineUrl() != systemTtsEngineUrl) {
        unawaited(_streamPlayer.setSpeed(updated.speed));
      }
    }
  }

  /// 读回并应用书级听书偏好（播放模式 / 语速）
  ///
  /// 打开听书页初始化、切换书籍时调用；书对象未携带 readConfig 时经
  /// [BookshelfRepository.getBook] 补读（对齐原版 AudioPlay.resetData 的 getPlayMode /
  /// getPlaySpeed 读回语义）。[A2 | 2026-10-03]
  Future<void> applyBookPreferences(
    Book? book, {
    String? fallbackBookUrl,
  }) async {
    final url = book != null && book.bookUrl.isNotEmpty
        ? book.bookUrl
        : ((fallbackBookUrl != null && fallbackBookUrl.isNotEmpty)
              ? fallbackBookUrl
              : state.bookUrl);
    if (url.isEmpty) return;

    var target = book;
    if (target == null || target.readConfig == null) {
      // 缓存书可能缺 readConfig：始终向库补读一次，失败沿用传入对象
      try {
        target = await _bookshelf.getBook(url) ?? target;
      } catch (e) {
        debugPrint('读取书级听书配置失败: $e');
      }
    }
    if (target != null) _book = target;

    final cfg = target?.readConfig;
    if (cfg == null) return;

    final mode = _audioPlayModeFromIndex(cfg.playMode);
    if (mode != state.mode) {
      state = state.copyWith(mode: mode);
    }
    final speed = cfg.playSpeed;
    if (speed >= 0.5 && speed <= 3.0) {
      // 记录库内值：读回不触发回写（避免打开听书页即写库）
      _lastSpeedPersistKey = url;
      _lastSpeedPersistValue = speed;
      if ((speed - state.config.speed).abs() > 0.001) {
        updateConfig(speed: speed);
      }
    }
  }

  /// readConfig.playMode → AudioPlayMode（越界回退 sequential，
  /// 兼容原版含 LIST_LOOP=3 的存量数据）
  static AudioPlayMode _audioPlayModeFromIndex(int index) {
    if (index <= 0 || index >= AudioPlayMode.values.length) {
      return AudioPlayMode.sequential;
    }
    return AudioPlayMode.values[index];
  }

  /// 播放模式落库：audioWithPlayMode FFI 合并 readConfig JSON → updateBook
  ///
  /// [A2] 不做全量覆盖：先经 Rust 侧合并（保留 readConfig 既有字段），
  /// 再以更新后的 Book 快照写库。
  Future<void> _persistPlayMode(AudioPlayMode mode) async {
    final bookUrl = (_book?.bookUrl.isNotEmpty ?? false)
        ? _book!.bookUrl
        : state.bookUrl;
    if (bookUrl.isEmpty) return;
    try {
      final book = await _bookForUrl(bookUrl);
      if (book == null) return;
      final cfg = book.readConfig;
      final merged = await _audioBook.audioWithPlayMode(
        readConfig: cfg,
        playMode: mode.index,
      );
      final updated = book.copyWith(readConfig: merged);
      _book = updated;
      await _bookshelf.updateBook(updated);
    } catch (e) {
      debugPrint('保存书级播放模式失败: $e');
    }
  }

  /// 语速落库（防抖合并；仅听书页绑定书籍后写）
  void _scheduleSpeedPersist(double speed) {
    final book = _book;
    if (book == null) return;
    final bookUrl = book.bookUrl.isNotEmpty ? book.bookUrl : state.bookUrl;
    if (bookUrl.isEmpty) return;
    if (_lastSpeedPersistKey == bookUrl &&
        _lastSpeedPersistValue != null &&
        (_lastSpeedPersistValue! - speed).abs() < 0.001) {
      return; // 与库内一致（含读回后的首次），无需回写
    }
    _pendingSpeedPersist = (bookUrl: bookUrl, speed: speed);
    _speedPersistTimer?.cancel();
    _speedPersistTimer = Timer(kSpeedPersistDebounce, () {
      final pending = _pendingSpeedPersist;
      _pendingSpeedPersist = null;
      if (pending != null) {
        unawaited(_persistSpeed(pending.bookUrl, pending.speed));
      }
    });
  }

  /// 语速写 Book readConfig.playSpeed → updateBook（对齐原版 updateAudioPlaySpeed）
  Future<void> _persistSpeed(String bookUrl, double speed) async {
    try {
      final book = await _bookForUrl(bookUrl);
      if (book == null) return;
      final cfg = book.readConfig ?? const ReadConfig();
      final updated = book.copyWith(readConfig: cfg.copyWith(playSpeed: speed));
      _book = updated;
      await _bookshelf.updateBook(updated);
      _lastSpeedPersistKey = bookUrl;
      _lastSpeedPersistValue = speed;
    } catch (e) {
      debugPrint('保存书级语速失败: $e');
    }
  }

  /// 取当前书籍对象（缓存命中直接用；否则按 URL 补读并缓存）
  Future<Book?> _bookForUrl(String bookUrl) async {
    final cached = _book;
    if (cached != null && cached.bookUrl == bookUrl) return cached;
    try {
      final fetched = await _bookshelf.getBook(bookUrl);
      if (fetched != null) _book = fetched;
      return fetched;
    } catch (e) {
      debugPrint('读取书籍失败（听书配置持久化）: $e');
      return null;
    }
  }

  /// 流媒体进度写库（A3）
  ///
  /// 节流：同一 bookUrl+chapterIndex 下，非 [force] 调用仅当播放位置增量
  /// ≥ [kStreamProgressSaveDeltaMs] 时写库（onProgress 高频回调下只做内存
  /// 比较）；[force] 用于生命周期节点（暂停/停止/完成/切章/退出）。
  /// 位置优先取播放器实际位置，未初始化时回退 state.positionMs。
  ///
  /// 写入归属恒为调用时刻的 state.currentIndex；播放器回调路径（onProgress）
  /// 必须先在回调入口经 [_isCurrentStreamChapter] 校验归属，切章后迟到的旧章
  /// 回调不得进入本方法。[P1 竞态修复]
  Future<void> _persistStreamPosition({
    int? positionMs,
    bool force = false,
  }) async {
    if (!state.isStreamMode) return; // TTS 无毫秒时间轴，不写该键（避免污染流媒体恢复）
    final bookUrl = state.bookUrl;
    if (bookUrl.isEmpty) return;
    final chapterIndex = state.currentIndex;
    final key = '$bookUrl:$chapterIndex';
    // 播放器位置只在同一章内可信（切章后 Fake/真机可能仍持有上一章位置）
    final playerPos = _streamPlayer.position.inMilliseconds;
    final position =
        positionMs ??
        ((key == _lastProgressSaveKey && playerPos > 0)
            ? playerPos
            : state.positionMs);
    if (position <= 0) return; // 起始 0 位置不写，避免覆盖已存进度
    if (key == _lastProgressSaveKey) {
      final delta = (position - _lastProgressSavedPosMs).abs();
      if (position == _lastProgressSavedPosMs) return; // 同值去重
      if (!force && delta < kStreamProgressSaveDeltaMs) return;
    }
    _lastProgressSaveKey = key;
    _lastProgressSavedPosMs = position;
    try {
      await _audioBook.saveAudioProgress(bookUrl, chapterIndex, position);
    } catch (e) {
      debugPrint('保存音频进度失败: $e');
    }
  }

  /// 单曲循环重播前清零当前章进度
  Future<void> _resetStreamProgress() async {
    final bookUrl = state.bookUrl;
    if (bookUrl.isEmpty) return;
    final chapterIndex = state.currentIndex;
    try {
      await _audioBook.saveAudioProgress(bookUrl, chapterIndex, 0);
      _lastProgressSaveKey = '$bookUrl:$chapterIndex';
      _lastProgressSavedPosMs = 0;
    } catch (e) {
      debugPrint('重置音频进度失败: $e');
    }
  }

  /// 容器销毁时尽力写一次进度（onDispose 内调用，任何异常不得影响销毁）
  void _saveStreamProgressOnDispose() {
    try {
      final s = _stateForDispose;
      if (s == null || !s.isStreamMode || s.bookUrl.isEmpty) return;
      final key = '${s.bookUrl}:${s.currentIndex}';
      final playerPos = _streamPlayer.position.inMilliseconds;
      final position = (key == _lastProgressSaveKey && playerPos > 0)
          ? playerPos
          : s.positionMs;
      if (position <= 0) return;
      if (key == _lastProgressSaveKey && position == _lastProgressSavedPosMs) {
        return;
      }
      unawaited(
        _audioBook
            .saveAudioProgress(s.bookUrl, s.currentIndex, position)
            .catchError((Object e) {
              debugPrint('退出时保存音频进度失败: $e');
            }),
      );
    } catch (e) {
      debugPrint('退出时保存音频进度失败: $e');
    }
  }

  @override
  void dispose() {
    _saveStreamProgressOnDispose();
    _speedPersistTimer?.cancel();
    _sleepTicker?.cancel();
    _disposed = true;
    _readAloud.dispose(snapshot: _stateForDispose);
    _media.dispose();
    super.dispose();
  }
}

final audioNotifierProvider = NotifierProvider<AudioNotifier, AudioState>(
  AudioNotifier.new,
);

final audioServiceProvider = Provider<AudioService>(
  (ref) => AudioService.instance,
);

/// 独立加载服务可在测试中替换，不让图片请求参与音频起播等待。
final mediaArtworkLoaderProvider = Provider<MediaArtworkLoader>(
  (ref) => MediaArtworkLoader(
    images: ref.watch(bookImageRepositoryProvider),
    sources: ref.watch(bookSourceRepositoryProvider),
  ),
);

final mediaMonotonicClockProvider = Provider<int Function()>((ref) {
  final clock = Stopwatch()..start();
  return () => clock.elapsedMilliseconds;
});

/// StreamAudioPlayer 注入点（单元测试 override 为 Fake/Mock；
/// 生产环境单实例，TTS 与音频书路径共用）
final streamAudioPlayerProvider = Provider<StreamAudioPlayer>((ref) {
  final player = ReadAloudAudioPlayer();
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});
