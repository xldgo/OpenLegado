import '../services/audio_book_preferences_service.dart';
import '../services/audio_preferences_host.dart';
import '../../read_aloud/services/read_aloud_selection_service.dart';
export '../services/audio_book_preferences_service.dart'
    show kSpeedPersistDebounce;
export '../../read_aloud/services/read_aloud_selection_service.dart'
    show normalizeTtsEngineUrl, kTtsEngineConfigKey, kTtsEngineIdConfigKey;
import '../playback/audio_book_controller.dart';
import '../playback/audio_book_host.dart';
export '../playback/audio_book_controller.dart'
    show
        StreamChapterTag,
        kStreamProgressSaveDeltaMs,
        kStreamRestoreNearEndToleranceMs;
import '../playback/media_session_coordinator.dart';
import '../playback/media_session_host.dart';
import '../../read_aloud/playback/read_aloud_controller.dart';
import '../../read_aloud/playback/read_aloud_host.dart';
import '../../read_aloud/read_aloud_settings_provider.dart';
export '../../read_aloud/playback/read_aloud_controller.dart'
    show kNoUsableEngineHint;
import '../../../domain/contracts/bookshelf_repository.dart';
import '../../../domain/contracts/cloud_tts_repository.dart';
import '../../../domain/contracts/http_tts_repository.dart';
import '../../../domain/contracts/http_tts_synthesizer.dart';
import '../../../domain/contracts/read_aloud_voice_repository.dart';
import '../../../app/bootstrap/application_dependencies.dart';
export 'audio_state.dart';
import '../../../providers/config_settings_provider.dart';
import '../../../providers/domain_config_provider.dart';
import '../../../domain/contracts/audio_playback_settings_repository.dart';
import '../../../domain/contracts/read_aloud_selection_repository.dart';
import '../../../domain/contracts/audio_book_service.dart';
import '../../../domain/contracts/reading_repository.dart';
import '../../../providers/chapter_content_provider.dart';
import '../../../domain/models/read_aloud_content.dart';

import '../../read_aloud/cloud_tts_providers.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/book.dart';
import '../../../services/audio_service.dart';
import '../../../services/media_artwork_loader.dart';
import '../../../services/media_session_models.dart';
import '../../privacy/privacy_controller.dart';
import '../../../services/stream_audio_player.dart';
import '../../../services/read_aloud_audio_player.dart';
import '../../../platform/tts/system_tts.dart';
import '../../read_aloud/tts_providers.dart';
import 'audio_state.dart';
import 'read_aloud_preferences.dart';
import 'read_aloud_position.dart';

/// 分钟倒计时上限——对齐原版 SleepTimerDialog.MAX_MINUTES = 180
/// [A4 | 2026-10-03]
const int kMaxSleepTimerMinutes = 180;

/// 按章停止上限——对齐原版 MAX_CHAPTER_STOP_COUNT = 99
/// （ChapterStopTimer.kt:3）[A4 | 2026-10-03]
const int kMaxChapterStopCount = 99;

/// 听书播放器 Riverpod Notifier
///
/// 双路径：
/// - 音频书（BookType.audio）：getAudioChapterMedia 取址 → StreamAudioPlayer
/// - TTS 朗读：HTTP 文件播放或系统直接朗读，统一会话完成回调推进段落
///
/// — Auto + UI｜2026-08-12（P0-2 流媒体接线；A1 批 TTS 真实播放 2026-10-03）
class AudioNotifier extends Notifier<AudioState> with ChangeNotifier {
  late final MediaSessionCoordinator _media;
  late final AudioBookPreferencesService _bookPreferences;
  late final ReadAloudSelectionService _engineSelection;
  late final AudioBookController _audioBookController;
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

  int _playToken = 0;

  Book? _book;
  bool _disposed = false;
  Future<void> _pauseCompletion = Future.value();

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
    final preferencesHost = AudioPreferencesHost(
      readState: () => state,
      writeState: (value) => state = value,
      readBook: () => _book,
      writeBook: (book) => _book = book,
      currentToken: () => _playToken,
      isDisposed: () => _disposed,
      updateConfig:
          ({
            engineUrl,
            engineId,
            speed,
            restartPlayback = true,
            persistBookSpeed = true,
          }) => updateConfig(
            engineUrl: engineUrl,
            engineId: engineId,
            speed: speed,
            restartPlayback: restartPlayback,
            persistBookSpeed: persistBookSpeed,
          ),
      restartReadAloud: restartCurrentTts,
    );
    _bookPreferences = AudioBookPreferencesService(
      host: preferencesHost,
      bookshelf: _bookshelf,
      audioBook: _audioBook,
    );
    _engineSelection = ReadAloudSelectionService(
      host: preferencesHost,
      preferences: _bookPreferences,
      httpTts: _httpTts,
      selections: _selections,
    );
    _audioBookController = AudioBookController(
      host: AudioBookHost(
        readState: () => state,
        writeState: (value) => state = value,
        currentToken: () => _playToken,
        advanceToken: () => ++_playToken,
        isDisposed: () => _disposed,
        boundBook: () => _book,
        stopSystemTts: () => _readAloud.stopSystem(),
        activateMedia: ({bool userInitiated = false}) =>
            _media.activate(userInitiated: userInitiated),
        consumeChapterStop: _consumeChapterStopAtBoundary,
        nextChapter: () => next(userInitiated: false),
        replay: () => play(userInitiated: false),
        pause: pause,
        stop: stop,
      ),
      service: _audioBook,
      settings: _playbackSettings,
      player: _streamPlayer,
    );
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
        persistStreamPosition: _audioBookController.persistPosition,
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
        nextChapter: () => next(userInitiated: false),
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
        _audioBookController.handleCompleted(tag);
        return;
      }
      _readAloud.handleCompleted(tag);
    };
    _streamPlayer.onError = (error, tag) {
      if (_disposed) return;
      if (state.isStreamMode) {
        _audioBookController.handleError(error, tag);
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
      _audioBookController.handleProgress(pos, dur, tag);
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
      _audioBookController.dispose(snapshot: _stateForDispose);
      _bookPreferences.dispose();
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
    await _bookPreferences.bindBook(bookUrl);
    if (_disposed || token != _playToken) return;
    await prepareReadAloudSettings();
    if (_disposed || token != _playToken) return;

    // 解析层级对齐原版 ReadAloud.ttsEngine = 书级 ?: 全局（ReadAloud.kt:41 →
    // AppConfig.kt:506-509）：书级为空时先读回持久化的全局值（原版
    // AppConfig.ttsEngine 重启保留），仍为空才自动选默认引擎（我方降级路径）。
    if (resolveTtsEngineUrl().isEmpty) {
      await _engineSelection.restoreGlobalEngine();
      if (_disposed || token != _playToken) return;
    }
    if (resolveTtsEngineUrl().isEmpty) {
      await _engineSelection.ensureDefaultEngine();
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

  String resolveTtsEngineUrl() => _engineSelection.resolveTtsEngineUrl();
  Future<int?> resolveTtsEngineId() => _engineSelection.resolveTtsEngineId();
  bool get hasCurrentBook => _engineSelection.hasCurrentBook;
  Future<bool> setBookTtsEngine(String engineUrl, {int? engineId}) =>
      _engineSelection.setBookTtsEngine(engineUrl, engineId: engineId);
  Future<void> clearBookTtsEngine() => _engineSelection.clearBookTtsEngine();
  Future<void> setGlobalTtsEngine(String engineUrl, {int? engineId}) =>
      _engineSelection.setGlobalTtsEngine(engineUrl, engineId: engineId);
  Future<String> loadEffectiveTtsEngineUrl() =>
      _engineSelection.loadEffectiveTtsEngineUrl();

  Future<void> play({int? paragraphIndex, bool userInitiated = true}) async {
    if (state.chapters.isEmpty) return;
    if (state.isStreamMode) {
      await _audioBookController.play(userInitiated: userInitiated);
      return;
    }
    // [引擎双持久化 | 2026-10-04] 听书页 TTS 入口（非 startReadAloud 路径）
    // 同样读回持久化全局引擎：原版 AppConfig.ttsEngine 对所有朗读入口生效；
    // 此处只读回、不自动选默认（默认选择仍归 startReadAloud，保持既有语义）。
    final token = _playToken;
    if (resolveTtsEngineUrl().isEmpty) {
      await _engineSelection.restoreGlobalEngine();
    }
    if (_disposed || token != _playToken) return;
    await _readAloud.play(
      paragraphIndex: paragraphIndex,
      userInitiated: userInitiated,
    );
  }

  Future<void> setCloudTtsVoice(String engineId, ReadAloudVoice? voice) =>
      _engineSelection.setCloudTtsVoice(engineId, voice);
  Future<void> setHttpTtsVoice(
    int id,
    ReadAloudVoice? voice, {
    String? emotionTag,
  }) => _engineSelection.setHttpTtsVoice(id, voice, emotionTag: emotionTag);

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
      final paused = state.isStreamMode
          ? _audioBookController.pause()
          : _readAloud.pause();
      _pauseCompletion = paused;
      state = state.copyWith(state: PlayerState.paused);
      unawaited(
        _media.notifyPaused(after: paused).catchError((Object error) {
          debugPrint('暂停音频会话失败：$error');
        }),
      );
    } else if (!dueToInterruption && state.state == PlayerState.paused) {
      // 中断已暂停后用户明确暂停：取消恢复意图，并等待同一原生屏障再交还会话。
      unawaited(
        _media.notifyPaused(after: _pauseCompletion).catchError((Object error) {
          debugPrint('释放暂停音频会话失败：$error');
        }),
      );
    }
  }

  Future<void> resumeOrPlay({bool userInitiated = true}) async {
    _media.prepareResume();
    if (state.state == PlayerState.paused &&
        !state.isStreamMode &&
        await _readAloud.resume(userInitiated: userInitiated)) {
      return;
    }
    if (state.state == PlayerState.paused &&
        state.isStreamMode &&
        await _audioBookController.resume(userInitiated: userInitiated)) {
      return;
    }
    await play(userInitiated: userInitiated);
  }

  void stop() {
    final snapshot = state;
    _clearSleepTimerState();
    _media.invalidate();
    unawaited(_audioBookController.persistPosition(force: true));
    _media.prepareResume();
    _playToken++;
    final stopped = _readAloud.stop(snapshot);
    state = state.copyWith(
      state: PlayerState.idle,
      mediaUrl: '',
      positionMs: 0,
      durationMs: 0,
      lyric: null,
    );
    _media.notifyStopped(after: stopped);
  }

  Future<void> next({bool userInitiated = true}) async {
    _readAloud.cancelBackground();
    if (!state.hasNext && state.mode != AudioPlayMode.singleLoop) return;
    if (!state.isStreamMode) {
      _playToken++;
      _readAloud.interrupt();
    }
    // [A3] 切章前写当前章进度（TTS 模式内部直接返回）
    await _audioBookController.persistPosition(force: true);
    _readAloud.resetParagraphForChapter();
    if (state.mode == AudioPlayMode.singleLoop) {
      await play(paragraphIndex: 0, userInitiated: userInitiated);
      return;
    }
    state = state.copyWith(currentIndex: state.currentIndex + 1);
    await play(paragraphIndex: 0, userInitiated: userInitiated);
  }

  Future<void> previous() async {
    _readAloud.cancelBackground();
    if (!state.hasPrevious) return;
    if (!state.isStreamMode) {
      _playToken++;
      _readAloud.interrupt();
    }
    // [A3] 切章前写当前章进度
    await _audioBookController.persistPosition(force: true);
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
    await _audioBookController.persistPosition(force: true);
    _readAloud.resetParagraphForChapter();
    state = state.copyWith(currentIndex: index);
    await play(paragraphIndex: 0);
  }

  /// 切换播放模式并落库（书级 readConfig.playMode，对齐原版 AudioPlay.changePlayMode）
  Future<void> setMode(AudioPlayMode mode) async {
    if (state.mode == mode) return;
    state = state.copyWith(mode: mode);
    await _bookPreferences.persistMode(mode);
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
      _bookPreferences.scheduleSpeed(updated.speed);
    }
    if (speed != null && _streamPlayer.isInitialized) {
      if (state.isStreamMode || resolveTtsEngineUrl() != systemTtsEngineUrl) {
        unawaited(_streamPlayer.setSpeed(updated.speed));
      }
    }
  }

  Future<void> applyBookPreferences(Book? book, {String? fallbackBookUrl}) =>
      _bookPreferences.apply(book, fallbackBookUrl: fallbackBookUrl);

  @override
  void dispose() {
    _audioBookController.dispose(snapshot: _stateForDispose);
    _bookPreferences.dispose();
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
