import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../data/services/chapter_content_service.dart';
import '../../../domain/contracts/cloud_tts_repository.dart';
import '../../../domain/contracts/cloud_tts_synthesizer.dart';
import '../../../domain/contracts/http_tts_repository.dart';
import '../../../domain/contracts/http_tts_synthesizer.dart';
import '../../../domain/contracts/read_aloud_voice_repository.dart';
import '../../../domain/contracts/read_aloud_selection_repository.dart';
import '../../../domain/contracts/read_aloud_settings_repository.dart';
import '../../../domain/contracts/tts_cache_repository.dart';
import '../../../domain/contracts/cloud_tts_provider.dart';
import '../../../domain/models/read_aloud_content.dart';
import '../../../providers/audio/audio_state.dart';
import '../../../providers/audio/read_aloud_position.dart';
import '../../../platform/tts/system_tts.dart';
import '../../../services/stream_audio_player.dart';
import '../../../utils/read_aloud_text.dart';
import '../http_tts_voice_selection.dart';
import 'read_aloud_engine.dart';
import 'read_aloud_host.dart';
import 'system_read_aloud_engine.dart';
import 'http_read_aloud_engine.dart';
import 'cloud_read_aloud_engine.dart';
import 'read_aloud_synthesis_queue.dart';
import 'read_aloud_synthesis_adapter.dart';

const String kNoUsableEngineHint = '未配置可用朗读引擎，将按估算节奏朗读';

/// 段落、原文位置与引擎控制只有本会话持有；书籍/媒体状态由宿主拥有。— Codex + UI
class ReadAloudController {
  ReadAloudController({
    required this._host,
    required ChapterContentService content,
    required this._settings,
    required this._httpTts,
    required this._cloudTts,
    required this._voices,
    required this._selections,
    required HttpTtsSynthesizer httpSynthesizer,
    required CloudTtsSynthesizer cloudSynthesizer,
    required TtsCacheRepository cache,
    required StreamAudioPlayer player,
    required SystemTts systemTts,
  }) : _chapterContent = content,
       _ttsCache = cache,
       _streamPlayer = player {
    _systemEngine = SystemReadAloudEngine(systemTts);
    _synthesisQueue = ReadAloudSynthesisQueue(
      synthesize: (request, cancel) => synthesizeReadAloudRequest(
        request,
        cancel,
        http: httpSynthesizer,
        cloud: cloudSynthesizer,
      ),
      cache: () => _ttsCache,
    );
    _httpEngine = HttpReadAloudEngine(
      queue: _synthesisQueue,
      synthesizer: () => httpSynthesizer,
      player: player,
    );
    _cloudEngine = CloudReadAloudEngine(
      queue: _synthesisQueue,
      repository: () => _cloudTts,
      synthesizer: () => cloudSynthesizer,
      player: player,
      cache: () => _ttsCache,
    );
  }

  final ReadAloudHost _host;
  final ChapterContentService _chapterContent;
  final ReadAloudSettingsRepository _settings;
  final HttpTtsRepository _httpTts;
  final CloudTtsRepository _cloudTts;
  final ReadAloudVoiceRepository _voices;
  final ReadAloudSelectionRepository _selections;
  final TtsCacheRepository _ttsCache;
  final StreamAudioPlayer _streamPlayer;
  late final SystemReadAloudEngine _systemEngine;
  late final HttpReadAloudEngine _httpEngine;
  late final CloudReadAloudEngine _cloudEngine;
  late final ReadAloudSynthesisQueue _synthesisQueue;
  AudioState get _state => _host.readState();
  set _state(AudioState value) => _host.writeState(value);
  int get _playToken => _host.currentToken();
  bool get _disposed => _released || _host.isDisposed();
  bool _released = false;

  static const double _kCharsPerSecond = 5.0;
  static const Duration _kMinParagraphDuration = Duration(milliseconds: 800);
  static const Duration _kMaxParagraphDuration = Duration(seconds: 90);
  int _cacheRetentionMinutes = 10;
  bool _cachePrepared = false;
  List<String> _paragraphs = [];
  List<ReadAloudParagraph> _paragraphUnits = [];
  final readAloudPosition = ValueNotifier<ReadAloudPosition?>(null);
  final followReadAloud = ValueNotifier(true);
  int _readAloudSession = 0;
  int _paragraphIndex = 0;
  int _paragraphStartOffset = 0;
  Timer? _paragraphTimer;
  final _inFlightChapterContent = <String, Future<String>>{};
  int _speakGeneration = 0;
  Future<void> _ttsPauseBarrier = Future.value();
  int? _pendingParagraphIndex;
  int? _pendingChapterPos;
  bool _waitingForParagraph = false;
  bool _noEngineHintShown = false;
  ({String bookUrl, int chapterIndex})? _paragraphChapter;
  final _pageRanges =
      <(String, int), ({String content, List<ReadAloudPageRange> ranges})>{};

  int get currentParagraphIndex => _paragraphIndex;
  int get paragraphCount => _paragraphs.length;
  int get generation => _speakGeneration;
  bool get hasUnits => _paragraphUnits.isNotEmpty;
  int get unitCount => _paragraphUnits.length;
  bool get hasPrevParagraph => _paragraphs.isNotEmpty && _paragraphIndex > 0;
  bool get hasNextParagraph =>
      _paragraphs.isNotEmpty && _paragraphIndex < _paragraphs.length - 1;
  List<String> get currentParagraphs =>
      _paragraphChapter ==
          (bookUrl: _state.bookUrl, chapterIndex: _state.currentIndex)
      ? _paragraphs
      : const [];
  List<String> get prefetchDiagnostics => _synthesisQueue.diagnostics;

  void restoreReadAloudFollow() => followReadAloud.value = true;
  void detachReadAloudFollow() => followReadAloud.value = false;
  void _publishReadAloudPosition({int? offset}) {
    if (_disposed ||
        _state.isStreamMode ||
        _state.state == PlayerState.idle ||
        _paragraphChapter !=
            (bookUrl: _state.bookUrl, chapterIndex: _state.currentIndex) ||
        _paragraphIndex >= _paragraphUnits.length) {
      return;
    }
    final unit = _paragraphUnits[_paragraphIndex];
    readAloudPosition.value = ReadAloudPosition(
      bookUrl: _state.bookUrl,
      chapterIndex: _state.currentIndex,
      paragraphIndex: _paragraphIndex,
      paragraphStart: unit.start,
      paragraphEnd: unit.start + unit.text.length,
      offset: offset ?? unit.start + _paragraphStartOffset,
      session: _readAloudSession,
    );
    unawaited(_host.publishProgress());
  }

  ReadAloudSession _createReadAloudSession(
    int token,
    int gen,
    String engineUrl,
  ) {
    final unit = _paragraphUnits[_paragraphIndex];
    final base = unit.start + _paragraphStartOffset;
    return ReadAloudSession(
      isCurrent: () =>
          !isStale(token, gen) &&
          !_state.isStreamMode &&
          _host.resolveEngineUrl() == engineUrl,
      onProgress: (offset) {
        if (_state.isPlaying) _publishReadAloudPosition(offset: base + offset);
      },
      onCompleted: () => unawaited(_onParagraphFinished()),
      onError: (error) {
        if (engineUrl != systemTtsEngineUrl) {
          final currentUnit = _paragraphUnits[_paragraphIndex];
          _paragraphStartOffset =
              ((readAloudPosition.value?.offset ?? base) - currentUnit.start)
                  .clamp(0, currentUnit.text.length);
        }
        _host.pause();
        _state = _state.copyWith(errorMessage: '朗读不可用：$error');
      },
    );
  }

  ReadAloudEngine _engineForUrl(String engineUrl) =>
      engineUrl == systemTtsEngineUrl
      ? _systemEngine
      : isCloudTts(engineUrl)
      ? _cloudEngine
      : _httpEngine;

  Future<void> play({int? paragraphIndex, bool startPlaying = true}) async {
    _state = _state.copyWith(state: PlayerState.loading);
    final token = _host.advanceToken();
    _synthesisQueue.cancelAll();
    // 切章/重播入口先停掉上一段残留音频：新段合成期间保持静默而非叠音
    if (!await _stopTtsPaths(token)) return;
    try {
      if (!_cachePrepared && _ttsCache.supportsAudioFiles) {
        await _settings.load();
        if (token != _playToken || _disposed) return;
        _cacheRetentionMinutes = _settings.current.audioCacheCleanTime;
        if (_cacheRetentionMinutes <= 0) {
          await _synthesisQueue.whenIdle();
          if (token != _playToken || _disposed) return;
          await _ttsCache.clear();
        }
        _cachePrepared = true;
      }
      await _settings.load();
      if (token != _playToken || _disposed) return;
      final content = await _ensureChapterContent(_state.currentIndex);
      if (token != _playToken || _disposed) return;
      final units = _contentUnits(content, _state.currentIndex);
      final paragraphs = units.map((p) => p.text).toList();
      if (paragraphs.isEmpty && content.trim().isNotEmpty) {
        paragraphs.add(content.trim());
      }
      _paragraphs = List.unmodifiable(paragraphs);
      _paragraphUnits = List.unmodifiable(units);
      _paragraphChapter = (
        bookUrl: _state.bookUrl,
        chapterIndex: _state.currentIndex,
      );
      final pending = _pendingParagraphIndex;
      _pendingParagraphIndex = null;
      final chapterPos = _pendingChapterPos;
      _pendingChapterPos = null;
      final start = chapterPos == null
          ? null
          : readAloudStartAt(units, chapterPos);
      final target =
          paragraphIndex ??
          start?.paragraph ??
          pending ??
          (_paragraphs.isNotEmpty
              ? _paragraphIndex.clamp(0, _paragraphs.length - 1)
              : 0);
      _paragraphIndex = _paragraphs.isEmpty
          ? 0
          : target.clamp(0, _paragraphs.length - 1);
      if (start != null) _paragraphStartOffset = start.offset;
      if (paragraphIndex != null) _paragraphStartOffset = 0;
      _host.changed();
      _state = _state.copyWith(
        state: startPlaying ? PlayerState.playing : PlayerState.paused,
      );
      _publishReadAloudPosition();
      if (startPlaying) {
        await _host.activateMedia();
        if (token != _playToken || _disposed) return;
        await _speakCurrentParagraph(token);
      }
    } catch (e) {
      if (token != _playToken || _disposed) return;
      // [P0 | 2026-10-03] 在线书正文抓取失败（网络/书源失效等）必须有用户
      // 可见提示：errorMessage 由朗读条警示条/听书页错误行展示（不静默）
      _state = _state.copyWith(
        errorMessage: '章节正文获取失败，无法朗读：$e',
        state: PlayerState.error,
      );
    }
  }

  Future<String> _ensureChapterContent(int chapterIndex) async {
    final chapter = _state.chapters[chapterIndex];
    if (chapter.text.isNotEmpty) return chapter.text;
    final bookUrl = _state.bookUrl;
    final key = '$bookUrl\u0001$chapterIndex';
    final inFlight = _inFlightChapterContent[key];
    if (inFlight != null) return inFlight;
    final future = _chapterContent.read(bookUrl, chapterIndex).then((content) {
      _cacheFetchedChapterContent(bookUrl, chapterIndex, content);
      return content;
    });
    _inFlightChapterContent[key] = future;
    try {
      return await future;
    } finally {
      _inFlightChapterContent.remove(key);
    }
  }

  /// 抓取结果写回章节缓存
  ///
  /// 仅当书籍未切换且章号仍在范围内时写入：旧书/旧章的迟到结果不得污染
  /// 新书章节列表（在线抓取耗时更长，该窗口更宽）。
  void _cacheFetchedChapterContent(
    String bookUrl,
    int chapterIndex,
    String content,
  ) {
    if (_disposed || _state.bookUrl != bookUrl) return;
    if (chapterIndex < 0 || chapterIndex >= _state.chapters.length) return;
    final chapters = [..._state.chapters];
    final chapter = chapters[chapterIndex];
    if (chapter.text.isNotEmpty) return; // 已有缓存不覆盖
    chapters[chapterIndex] = AudioChapter(
      index: chapter.index,
      title: chapter.title,
      text: content,
    );
    _state = _state.copyWith(chapters: chapters);
  }

  /// 合成并播放当前段落（A1 批主路径）
  ///
  /// 链路：HTTP 合成（Rust 缓存落盘）→ 统一纯音频后端播放
  /// → 播放完成回调（onCompleted）驱动 [_onParagraphFinished] 推进下一段。
  /// 估算时长 Timer 仅在合成/播放失败降级时使用，且失败经
  /// [AudioState.errorMessage] 给用户可见提示（不静默）。
  ///
  /// HTTP/云端共用有界预合成；实际播放按单元顺序进行，完成后才推进。
  Future<void> _speakCurrentParagraph(int token) async {
    _paragraphTimer?.cancel();
    _waitingForParagraph = false;
    if (_paragraphs.isEmpty) return;
    final gen = ++_speakGeneration;
    // 先停掉上一段残留音频（手动切段/切章时避免叠音）
    if (!await _stopTtsPaths(token, generation: gen)) return;

    final paragraph = _paragraphs[_paragraphIndex];
    final text = paragraph.substring(
      _paragraphStartOffset.clamp(0, paragraph.length),
    );
    _publishReadAloudPosition();
    final config = _state.config;
    // [引擎双持久化 | 2026-10-04] 消费端单点解析：书级优先、空则全局回退
    // （对齐原版 ReadAloud.kt:41）；归一仍在此完成，历史「名称,URL」复合形态
    // 不会破坏解析（见 normalizeTtsEngineUrl）。
    final engineUrl = _host.resolveEngineUrl();
    if (engineUrl.isEmpty) {
      // [A4] 无可用引擎：温和一次性提示（复用 errorMessage 展示面）后按
      // 估算节奏朗读；不视为失败，无正文时前面的空段落判定已提前返回。
      _showNoEngineHintOnce();
      _scheduleEstimateAdvance(text, config.speed, token, gen);
      return;
    }
    final engine = _engineForUrl(engineUrl);
    final session = _createReadAloudSession(token, gen, engineUrl);
    Object? failure;
    try {
      final engineId = await _host.resolveEngineId() ?? 0;
      final source =
          engineUrl == systemTtsEngineUrl ||
              isCloudTts(engineUrl) ||
              !_ttsCache.supportsAudioFiles
          ? null
          : (await _httpTts.getHttpTts())
                .where((e) => e.id == engineId)
                .firstOrNull;
      if (isStale(token, gen)) return;
      if (source != null) {
        await _settings.load();
        if (isStale(token, gen)) return;
        _synthesisQueue.configure(
          source.synthesisThreadCount <
                  _settings.current.ttsPreSynthesisConcurrency
              ? source.synthesisThreadCount
              : _settings.current.ttsPreSynthesisConcurrency,
        );
      }
      CloudTtsEngine? cloud;
      String? cloudVersion;
      if (isCloudTts(engineUrl)) {
        cloud = (await _cloudTts.list())
            .where((e) => e.id == cloudTtsId(engineUrl))
            .firstOrNull;
        if (isStale(token, gen)) return;
        if (cloud == null || !cloud.enabled) throw StateError('云端引擎不存在或已停用');
        final voices = await _voices.list();
        if (isStale(token, gen)) return;
        cloudVersion = jsonEncode([
          cloud.toJson(),
          for (final v in voices.where(
            (v) => v.engineType == 'cloud_tts' && v.engineId == cloud!.id,
          ))
            v.toJson(),
        ]);
        _synthesisQueue.configure(_settings.current.ttsPreSynthesisConcurrency);
      }
      final voice = engineUrl == systemTtsEngineUrl || isCloudTts(engineUrl)
          ? const HttpTtsVoiceResolution()
          : await _httpVoice(engineId);
      if (isStale(token, gen)) return;
      final cloudVoice = isCloudTts(engineUrl)
          ? await _selections.getCloudVoice(cloudTtsId(engineUrl))
          : null;
      if (isStale(token, gen)) return;
      final request = ReadAloudRequest(
        voicePresetId: cloudVoice?.isEmpty == true ? null : cloudVoice,
        toneId: voice.voice?.speakerId,
        speakerName: voice.voice?.displayName,
        emotionTag: voice.emotionTag,
        text: text,
        engineId: engineId,
        engineUrl: engineUrl,
        speed: config.speed,
        pitch: config.pitch,
        volume: config.volume,
        voiceName: config.voiceName,
        sourceVersion:
            cloudVersion ??
            (source == null ? null : jsonEncode(source.toJson())),
        cacheContext: TtsCacheContext(
          bookUrl: _state.bookUrl,
          bookName: _state.bookName,
          chapterIndex: _state.currentIndex,
          chapterTitle: _state.currentChapter?.title ?? '',
          paragraphIndex: _paragraphIndex,
          text: text,
        ),
      );
      final playlist = switch (engine) {
        ReadAloudPlaylistEngine candidate => candidate,
        _ => null,
      };
      final result =
          playlist?.supportsPlaylist == true && _ttsCache.supportsAudioFiles
          ? await playlist!.speakPlaylist(
              _filePlaybackCues(request, cloud),
              session,
              onCueStarted: (cue) {
                // 暂停续播替换段落会话，队列自身检查新会话；此处只核对书章身份。
                if (_disposed ||
                    !_state.isPlaying ||
                    _state.bookUrl != request.cacheContext!.bookUrl ||
                    _state.currentIndex != request.cacheContext!.chapterIndex ||
                    _host.resolveEngineUrl() != request.engineUrl) {
                  return;
                }
                _paragraphIndex = cue.paragraphIndex;
                _paragraphStartOffset =
                    cue.sourceOffset - _paragraphUnits[_paragraphIndex].start;
                _publishReadAloudPosition(offset: cue.sourceOffset);
                _host.changed();
              },
            )
          : await engine.speak(request, session);
      if (isStale(token, gen) || result == ReadAloudStart.cancelled) {
        return;
      }
      if (engineUrl == systemTtsEngineUrl) return;
      if (result == ReadAloudStart.started) {
        // [A4] 真实播放恢复：允许后续再次提示（如引擎后续被移除）
        _noEngineHintShown = false;
        if (_state.errorMessage != null) {
          // 上一段降级/无引擎提示在恢复真实播放后清除
          _state = _state.copyWith(errorMessage: null);
        }
        if (voice.warning != null) {
          _state = _state.copyWith(errorMessage: voice.warning);
        }
        if (cloud != null && _ttsCache.supportsAudioFiles) {
          _startCloudPrefetch(request, cloud);
        }
        if (source != null) {
          _startHttpPrefetch(request, source.synthesisThreadCount);
        }
        // 正常路径到此为止：推进由统一段落会话完成回调触发。
        return;
      }
      failure = StateError('TTS 合成未返回音频文件（引擎或缓存异常）');
    } catch (e) {
      failure = e;
    }
    if (isStale(token, gen)) return;
    session.cancel();
    if (engineUrl == systemTtsEngineUrl || isCloudTts(engineUrl)) {
      _host.pause();
      _state = _state.copyWith(errorMessage: '朗读不可用：$failure');
      return;
    }

    // 降级：合成/播放失败 → 估算时长推进 + 用户可见提示
    // （无引擎配置时已在上面的空判定提前返回，保持既有静默估算行为）
    _state = _state.copyWith(errorMessage: '朗读音频不可用，本段按估算时长继续：$failure');
    _scheduleEstimateAdvance(text, config.speed, token, gen);
  }

  /// 原生队列只预先起播当前章；段间停顿不作用于同段内部的长度分片。
  List<ReadAloudPlaylistCue> _filePlaybackCues(
    ReadAloudRequest request,
    CloudTtsEngine? cloud,
  ) {
    final end = _settings.current.paragraphIntervalMs > 0
        ? _paragraphIndex + 1
        : _paragraphUnits.length;
    final cues = <ReadAloudPlaylistCue>[];
    for (var index = _paragraphIndex; index < end; index++) {
      final unit = _paragraphUnits[index];
      final offset = index == _paragraphIndex ? _paragraphStartOffset : 0;
      final text = unit.text.substring(offset);
      final List<ReadAloudUnit> parts = cloud == null
          ? [(text: text, start: 0)]
          : splitSpeechRequests(
              text,
              limit: cloudTtsProfile(cloud.provider).textLimit,
            ).map((part) => (text: part.text, start: part.start)).toList();
      for (final part in parts) {
        cues.add(
          ReadAloudPlaylistCue(
            request: request.copyWith(
              text: part.text,
              cacheContext: TtsCacheContext(
                bookUrl: _state.bookUrl,
                bookName: _state.bookName,
                chapterIndex: _state.currentIndex,
                chapterTitle: _state.currentChapter?.title ?? '',
                paragraphIndex: index,
                text: part.text,
              ),
            ),
            sourceOffset: unit.start + offset + part.start,
            paragraphIndex: index,
          ),
        );
      }
    }
    return cues;
  }

  void registerPages(
    String bookUrl,
    int chapter,
    String content,
    List<ReadAloudPageRange> ranges,
  ) {
    final key = (bookUrl, chapter);
    final old = _pageRanges[key];
    final unchanged =
        old != null && old.content == content && listEquals(old.ranges, ranges);
    if (unchanged) return;
    splitReadAloudContent(
      content,
      mode: ReadAloudSplitMode.page,
      pages: ranges,
    );
    _pageRanges[key] = (content: content, ranges: List.unmodifiable(ranges));
    if (_pageRanges.length > 6) _pageRanges.remove(_pageRanges.keys.first);
    if (old != null &&
        !_disposed &&
        _state.bookUrl == bookUrl &&
        _state.currentIndex == chapter &&
        !_state.isStreamMode &&
        _state.state != PlayerState.idle &&
        _settings.current.splitMode == ReadAloudSplitMode.page) {
      final playing = _state.isPlaying;
      _pendingChapterPos = readAloudPosition.value?.offset ?? 0;
      unawaited(play(startPlaying: playing));
    }
  }

  List<ReadAloudUnit> _contentUnits(String text, int chapter) {
    final prefs = _settings.current;
    final pages = _pageRanges[(_state.bookUrl, chapter)];
    return splitReadAloudContent(
      text,
      mode: prefs.splitMode,
      symbols: prefs.splitSymbols,
      pages: pages?.content == text ? pages?.ranges : null,
    );
  }

  Future<void> setContentSplit(ReadAloudSplitMode mode, String symbols) async {
    final anchor = readAloudPosition.value?.offset;
    final token = _playToken, generation = _speakGeneration;
    final playing = _state.isPlaying;
    await _settings.update(
      (current) => current.copyWith(splitMode: mode, splitSymbols: symbols),
    );
    if (isStale(token, generation)) return;
    _synthesisQueue.cancelBackground();
    if (_disposed || _state.isStreamMode || _state.state == PlayerState.idle) {
      return;
    }
    _pendingChapterPos = anchor;
    await play(startPlaying: playing);
  }

  void _startCloudPrefetch(ReadAloudRequest request, CloudTtsEngine cloud) {
    final prefs = _settings.current;
    _cacheRetentionMinutes = prefs.audioCacheCleanTime;
    if (prefs.audioPreDownloadNum <= 0) {
      _synthesisQueue.cancelBackground();
      return;
    }
    final bookUrl = _state.bookUrl, bookName = _state.bookName;
    final index = _state.currentIndex, paragraph = _paragraphIndex;
    final chapters = List<AudioChapter>.of(_state.chapters);
    final units = List<String>.of(_paragraphs);
    final remaining = _cloudEngine.remainingRequests;
    final contentService = _chapterContent;
    final key = jsonEncode([
      bookUrl,
      index,
      request.engineUrl,
      request.sourceVersion,
      request.voicePresetId,
      prefs.splitMode.name,
      prefs.splitSymbols,
    ]);
    List<ReadAloudRequest> cues(String text, int chapter, int unit) => [
      for (final part in splitSpeechRequests(
        text,
        limit: cloudTtsProfile(cloud.provider).textLimit,
      ))
        request.copyWith(
          text: part.text,
          cacheContext: TtsCacheContext(
            bookUrl: bookUrl,
            bookName: bookName,
            chapterIndex: chapter,
            chapterTitle: chapters[chapter].title,
            paragraphIndex: unit,
            text: part.text,
          ),
        ),
    ];
    Stream<List<ReadAloudRequest>> window() async* {
      yield [
        ...remaining,
        for (var p = paragraph + 1; p < units.length; p++)
          ...cues(units[p], index, p),
      ];
      if (prefs.splitMode == ReadAloudSplitMode.page) return;
      for (
        var i = index + 1;
        i < chapters.length && i <= index + prefs.audioPreDownloadNum;
        i++
      ) {
        if (!_synthesisQueue.isWindowCurrent(key)) return;
        final text = chapters[i].text.isNotEmpty
            ? chapters[i].text
            : await contentService.read(bookUrl, i);
        if (!_synthesisQueue.isWindowCurrent(key)) return;
        final nextUnits = splitReadAloudContent(
          text,
          mode: prefs.splitMode,
          symbols: prefs.splitSymbols,
        );
        yield [
          for (var p = 0; p < nextUnits.length; p++)
            ...cues(nextUnits[p].text, i, p),
        ];
      }
    }

    _synthesisQueue.startWindow(
      key: key,
      concurrency: prefs.ttsPreSynthesisConcurrency,
      chapters: window(),
    );
  }

  void _startHttpPrefetch(ReadAloudRequest request, int sourceConcurrency) {
    final preferences = _settings.current;
    _cacheRetentionMinutes = preferences.audioCacheCleanTime;
    if (preferences.audioPreDownloadNum <= 0) {
      _synthesisQueue.cancelBackground();
      return;
    }
    final bookUrl = _state.bookUrl, bookName = _state.bookName;
    final index = _state.currentIndex;
    final chapters = List<AudioChapter>.of(_state.chapters);
    final paragraphs = List<String>.of(_paragraphs);
    final paragraphIndex = _paragraphIndex;
    final contentService = _chapterContent;
    final key = jsonEncode([
      bookUrl,
      index,
      request.sourceVersion,
      request.voiceName,
      request.toneId,
      request.speakerName,
      request.emotionTag,
      request.pitch,
      request.volume,
    ]);
    ReadAloudRequest cue(String text, int chapter, int paragraph) =>
        ReadAloudRequest(
          text: text,
          engineId: request.engineId,
          engineUrl: request.engineUrl,
          sourceVersion: request.sourceVersion,
          speed: request.speed,
          pitch: request.pitch,
          volume: request.volume,
          voiceName: request.voiceName,
          toneId: request.toneId,
          speakerName: request.speakerName,
          emotionTag: request.emotionTag,
          cacheContext: TtsCacheContext(
            bookUrl: bookUrl,
            bookName: bookName,
            chapterIndex: chapter,
            chapterTitle: chapters[chapter].title,
            paragraphIndex: paragraph,
            text: text,
          ),
        );
    Stream<List<ReadAloudRequest>> window() async* {
      yield [
        for (var p = paragraphIndex + 1; p < paragraphs.length; p++)
          cue(paragraphs[p], index, p),
      ];
      if (preferences.splitMode == ReadAloudSplitMode.page) return;
      for (
        var i = index + 1;
        i < chapters.length && i <= index + preferences.audioPreDownloadNum;
        i++
      ) {
        if (!_synthesisQueue.isWindowCurrent(key)) return;
        final chapter = chapters[i];
        final text = chapter.text.isNotEmpty
            ? chapter.text
            : await contentService.read(bookUrl, i);
        if (!_synthesisQueue.isWindowCurrent(key)) return;
        final units = _contentUnits(text, i);
        yield [for (var p = 0; p < units.length; p++) cue(units[p].text, i, p)];
      }
    }

    _synthesisQueue.startWindow(
      key: key,
      concurrency: sourceConcurrency < preferences.ttsPreSynthesisConcurrency
          ? sourceConcurrency
          : preferences.ttsPreSynthesisConcurrency,
      chapters: window(),
    );
  }

  Future<void> refreshPrefetchSettings() async {
    if (_disposed) return;
    final token = _playToken, gen = _speakGeneration;
    if (isCloudTts(_host.resolveEngineUrl()) &&
        _state.isPlaying &&
        !_state.isStreamMode) {
      final clouds = await _cloudTts.list();
      if (isStale(token, gen)) return;
      final cloud = clouds
          .where((e) => e.id == cloudTtsId(_host.resolveEngineUrl()))
          .firstOrNull;
      final request = _cloudEngine.currentRequest;
      if (cloud != null && request != null && _ttsCache.supportsAudioFiles) {
        _synthesisQueue.cancelBackground();
        _startCloudPrefetch(request, cloud);
      }
      return;
    }
    _cacheRetentionMinutes = _settings.current.audioCacheCleanTime;
    _synthesisQueue.cancelBackground();
    if (!_disposed &&
        _state.isPlaying &&
        !_state.isStreamMode &&
        _host.resolveEngineUrl() != systemTtsEngineUrl) {
      final id = await _host.resolveEngineId();
      if (isStale(token, gen) || !_state.isPlaying || id == null) return;
      final sources = await _httpTts.getHttpTts();
      final source = sources.where((s) => s.id == id).firstOrNull;
      if (isStale(token, gen) || !_state.isPlaying || source == null) {
        return;
      }
      final voice = await _httpVoice(id);
      if (isStale(token, gen) || !_state.isPlaying) return;
      final config = _state.config;
      _startHttpPrefetch(
        ReadAloudRequest(
          text: '',
          toneId: voice.voice?.speakerId,
          speakerName: voice.voice?.displayName,
          emotionTag: voice.emotionTag,
          engineId: id,
          engineUrl: source.url,
          sourceVersion: jsonEncode(source.toJson()),
          speed: config.speed,
          pitch: config.pitch,
          volume: config.volume,
          voiceName: config.voiceName,
        ),
        source.synthesisThreadCount,
      );
    }
  }

  Future<void> _cleanTtsCache(
    AudioState snapshot,
    int minutes, {
    int? token,
  }) async {
    if (!_ttsCache.supportsAudioFiles) return;
    try {
      await _synthesisQueue.whenIdle();
      if (token != null && token != _playToken) return;
      await _ttsCache.clear(
        beforeTimestampMs: minutes <= 0
            ? null
            : DateTime.now().millisecondsSinceEpoch - minutes * 60000,
        keepBookUrl: minutes <= 0 ? null : snapshot.bookUrl,
        keepChapterIndex: minutes <= 0 ? null : snapshot.currentIndex,
      );
    } catch (error) {
      debugPrint('朗读缓存清理失败：$error');
    }
  }

  Future<HttpTtsVoiceResolution> _httpVoice(int id) async {
    if (!_voices.supportsCatalog) {
      return const HttpTtsVoiceResolution();
    }
    final selection = await _selections.getHttpVoice(id);
    if (selection == null) return const HttpTtsVoiceResolution();
    return resolveHttpTtsVoice(id, await _voices.list(), selection);
  }

  Future<void> stopFilePlayback() {
    final stopped = _streamPlayer.stop();
    return Future.wait([
      _httpEngine.stop(playbackStopped: stopped),
      _cloudEngine.stop(playbackStopped: stopped),
    ]).then((_) {});
  }

  Future<bool> _stopTtsPaths(int token, {int? generation}) async {
    // 旧会话的暂停屏障不能阻塞切章、换引擎后的新会话。
    _ttsPauseBarrier = Future.value();
    bool stale() =>
        token != _playToken ||
        _disposed ||
        (generation != null && generation != _speakGeneration);
    try {
      // 同时失效两条路径，不能等待系统停止后才让旧 HTTP 续播失效。
      await Future.wait([_systemEngine.stop(), stopFilePlayback()]);
    } catch (error) {
      if (stale()) return false;
      _host.pause();
      _state = _state.copyWith(errorMessage: '朗读控制失败，已暂停：$error');
      return false;
    }
    return !stale();
  }

  void observeControl(
    Future<void> operation, {
    String errorPrefix = '系统朗读控制失败',
  }) {
    final token = _playToken;
    final gen = _speakGeneration;
    unawaited(
      operation.catchError((Object error, StackTrace stack) {
        debugPrint('$errorPrefix：$error');
        if (isStale(token, gen)) return;
        _host.advanceToken();
        _speakGeneration++;
        _paragraphTimer?.cancel();
        _state = _state.copyWith(
          state: _state.state == PlayerState.idle
              ? PlayerState.idle
              : PlayerState.paused,
          errorMessage: '$errorPrefix：$error',
        );
        unawaited(_host.notifyPaused());
      }),
    );
  }

  /// 系统语音设置只影响系统路径，避免重启正在播放的 HTTP 音频。
  Future<void> refreshSystemSettings() async {
    if (_host.resolveEngineUrl() == systemTtsEngineUrl) {
      await restart();
    }
  }

  /// 用户更改引擎或语音时失效旧请求，并按当前段重启；暂停时保持暂停。
  Future<void> restart() async {
    _synthesisQueue.cancelBackground();
    if (_disposed || _state.isStreamMode) return;
    final playing = _state.isPlaying || _state.state == PlayerState.loading;
    final token = _host.advanceToken();
    _speakGeneration++;
    _paragraphTimer?.cancel();
    if (!await _stopTtsPaths(token)) return;
    if (playing &&
        token == _playToken &&
        !_disposed &&
        (_state.isPlaying || _state.state == PlayerState.loading)) {
      await play();
    }
  }

  /// 段落级失效判定：播放会话 token 或合成代数任一变化即视为过期
  bool isStale(int token, int gen) =>
      token != _playToken || gen != _speakGeneration || _disposed;

  /// 降级推进：按字符数估算当前段时长，到点后推进下一段
  void _scheduleEstimateAdvance(String text, double speed, int token, int gen) {
    final s = speed <= 0 ? 1.0 : speed;
    final seconds = text.length / (_kCharsPerSecond * s);
    var duration = Duration(milliseconds: (seconds * 1000).round());
    if (duration < _kMinParagraphDuration) {
      duration = _kMinParagraphDuration;
    } else if (duration > _kMaxParagraphDuration) {
      duration = _kMaxParagraphDuration;
    }
    _paragraphTimer = Timer(duration, () {
      if (isStale(token, gen)) return;
      unawaited(_onParagraphFinished());
    });
  }

  Future<void> _onParagraphFinished() async {
    if (_state.state != PlayerState.playing) return;
    if (_paragraphIndex < _paragraphs.length - 1) {
      _paragraphIndex++;
      _paragraphStartOffset = 0;
      _host.changed();
      final token = _playToken;
      final interval = _settings.current.paragraphIntervalMs;
      if (interval == 0) {
        await _speakCurrentParagraph(token);
      } else {
        _waitingForParagraph = true;
        _paragraphTimer = Timer(Duration(milliseconds: interval), () {
          if (!_disposed && token == _playToken && _state.isPlaying) {
            unawaited(_speakCurrentParagraph(token));
          }
        });
      }
      return;
    }
    // [A4] 章末（末段播完）：按章停止计数，归零则在章末停止而不切章
    if (_host.consumeChapterStop()) {
      _host.stop();
      return;
    }
    if (_state.mode == AudioPlayMode.singleLoop) {
      _paragraphIndex = 0;
      _paragraphStartOffset = 0;
      _host.changed();
      await _speakCurrentParagraph(_playToken);
      return;
    }
    if (_state.hasNext) {
      await _host.nextChapter();
      return;
    }
    _host.stop();
  }

  /// 手动页面跟读共用既有会话；暂停时只定位，不重新起播。
  Future<void> seekToChapterPosition(int chapterIndex, int offset) async {
    _synthesisQueue.cancelBackground();
    if (_state.isStreamMode ||
        _state.state == PlayerState.idle ||
        chapterIndex < 0 ||
        chapterIndex >= _state.chapters.length) {
      return;
    }
    final playing = _state.isPlaying;
    final token = _host.advanceToken();
    _speakGeneration++;
    _paragraphTimer?.cancel();
    _waitingForParagraph = false;
    if (!await _stopTtsPaths(token)) return;
    _paragraphStartOffset = 0;
    _pendingChapterPos = offset;
    _pendingParagraphIndex = null;
    _state = _state.copyWith(currentIndex: chapterIndex);
    await play(startPlaying: playing);
    // 等原文锚点落定再重置时钟，避免暂停时冻结在定位前的位置。
    _host.reviseTimeline();
    await _host.publishProgress(force: true);
  }

  /// 播放器拖动进度与点击正文共用此入口；暂停中移动后仍保持暂停。
  Future<void> seekToParagraph(int index) async {
    _host.reviseTimeline();
    _synthesisQueue.cancelBackground();
    if (_state.isStreamMode ||
        _state.isLoading ||
        index < 0 ||
        index >= currentParagraphs.length) {
      return;
    }
    final wasPlaying = _state.isPlaying;
    final token = _host.advanceToken();
    _speakGeneration++;
    _paragraphTimer?.cancel();
    _waitingForParagraph = false;
    if (!await _stopTtsPaths(token)) return;
    _paragraphIndex = index;
    _paragraphStartOffset = 0;
    _publishReadAloudPosition();
    _host.changed();
    if (wasPlaying) await _speakCurrentParagraph(token);
  }

  Future<void> nextParagraph() async {
    _host.reviseTimeline();
    _synthesisQueue.cancelBackground();
    if (_state.isStreamMode) return;
    if (_paragraphs.isEmpty || _state.state == PlayerState.idle) return;
    if (_paragraphIndex < _paragraphs.length - 1) {
      _paragraphIndex++;
      _paragraphStartOffset = 0;
      _publishReadAloudPosition();
      _host.changed();
      if (_state.state == PlayerState.paused) {
        _ttsPauseBarrier = Future.value();
        _host.advanceToken();
        _speakGeneration++;
        observeControl(_systemEngine.stop());
        observeControl(stopFilePlayback(), errorPrefix: '音频播放控制失败');
      }
      final token = _playToken;
      if (_state.isPlaying) await _speakCurrentParagraph(token);
      return;
    }
    if (_state.hasNext) {
      _paragraphIndex = 0;
      await _host.nextChapter();
    }
  }

  Future<void> prevParagraph() async {
    _host.reviseTimeline();
    _synthesisQueue.cancelBackground();
    if (_state.isStreamMode) return;
    if (_paragraphs.isEmpty || _state.state == PlayerState.idle) return;
    if (_paragraphIndex > 0) {
      _paragraphIndex--;
      _paragraphStartOffset = 0;
      _publishReadAloudPosition();
      _host.changed();
      if (_state.state == PlayerState.paused) {
        _ttsPauseBarrier = Future.value();
        _host.advanceToken();
        _speakGeneration++;
        observeControl(_systemEngine.stop());
        observeControl(stopFilePlayback(), errorPrefix: '音频播放控制失败');
      }
      final token = _playToken;
      if (_state.isPlaying) await _speakCurrentParagraph(token);
      return;
    }
    if (_state.hasPrevious) {
      _paragraphIndex = 0;
      await _host.previousChapter();
    }
  }

  void handleCompleted(Object? tag) {
    _httpEngine.handleCompleted(tag);
    _cloudEngine.handleCompleted(tag);
  }

  void handleError(Object error, Object? tag) {
    _httpEngine.handleError(error, tag);
    _cloudEngine.handleError(error, tag);
  }

  void handleProgress(Duration position, Duration duration, Object? tag) {
    _httpEngine.handleProgress(position, duration, tag);
    _cloudEngine.handleProgress(position, duration, tag);
  }

  void cancelBackground() => _synthesisQueue.cancelBackground();
  void clearNoEngineHint() => _noEngineHintShown = false;
  Future<void> stopSystem() => _systemEngine.stop();

  void prepareBookLoad() {
    _synthesisQueue.cancelAll();
    _cachePrepared = false;
  }

  void beginSession() {
    prepareBookLoad();
    _readAloudSession++;
    restoreReadAloudFollow();
    readAloudPosition.value = null;
    _noEngineHintShown = false;
  }

  void interrupt() {
    invalidateSpeech();
    observeControl(_systemEngine.stop());
  }

  void invalidateSpeech() {
    _speakGeneration++;
    _paragraphTimer?.cancel();
  }

  void cancelPendingAdvance() => _paragraphTimer?.cancel();

  Future<bool> stopForChapterChange(int token) async {
    await _systemEngine.stop();
    if (_disposed || token != _playToken) return false;
    await stopFilePlayback();
    return !_disposed && token == _playToken;
  }

  void resetParagraphForChapter() {
    _paragraphTimer?.cancel();
    _paragraphIndex = 0;
  }

  Future<void> locateStart({int? sourceOffset, String? text}) async {
    final token = _playToken;
    _pendingParagraphIndex = null;
    _pendingChapterPos = sourceOffset;
    _paragraphIndex = 0;
    _paragraphStartOffset = 0;
    _state = _state.copyWith(state: PlayerState.loading, errorMessage: null);
    try {
      final content = await _ensureChapterContent(_state.currentIndex);
      if (_disposed || token != _playToken) return;
      final paraText = text?.trim();
      if (_pendingChapterPos == null &&
          paraText != null &&
          paraText.isNotEmpty) {
        for (final paragraph in splitReadAloudParagraphs(content)) {
          if (paragraph.text == paraText) {
            _pendingChapterPos = paragraph.start;
            break;
          }
        }
      }
    } catch (error) {
      if (_disposed || token != _playToken) return;
      debugPrint('朗读起点定位失败（回退章首）: $error');
    }
  }

  Future<void> rebuildAtPosition(int offset, {required bool playing}) async {
    _pendingChapterPos = offset;
    await play(startPlaying: playing);
  }

  void pause() {
    _synthesisQueue.cancelBackground();
    _paragraphTimer?.cancel();
    _host.advanceToken();
    _speakGeneration++;
    final waiting = _waitingForParagraph;
    _ttsPauseBarrier = Future.wait([
      waiting ? _systemEngine.stop() : _systemEngine.pause(),
      waiting
          ? stopFilePlayback()
          : (isCloudTts(_host.resolveEngineUrl())
                ? _cloudEngine.pause()
                : _httpEngine.pause()),
    ]).then<void>((_) {});
    observeControl(_ttsPauseBarrier, errorPrefix: '朗读暂停失败');
    _waitingForParagraph = false;
  }

  /// true表示本次暂停续播已处理，false交由上层重新起播。
  Future<bool> resume() async {
    final pausedToken = _playToken;
    final pausedGeneration = _speakGeneration;
    try {
      await _ttsPauseBarrier;
    } catch (_) {
      return true;
    }
    if (isStale(pausedToken, pausedGeneration) ||
        _state.state != PlayerState.paused) {
      return true;
    }
    final engineUrl = _host.resolveEngineUrl();
    final engine = _engineForUrl(engineUrl);
    if (!engine.canResume) return false;
    final token = _host.advanceToken();
    final gen = ++_speakGeneration;
    _state = _state.copyWith(state: PlayerState.playing, errorMessage: null);
    await _host.activateMedia();
    if (isStale(token, gen)) return true;
    final session = _createReadAloudSession(token, gen, engineUrl);
    try {
      await engine.resume(session);
      if (!isStale(token, gen) && engineUrl != systemTtsEngineUrl) {
        unawaited(refreshPrefetchSettings());
      }
    } catch (error) {
      session.fail(error);
    }
    return true;
  }

  /// 宿主先使全局播放标识失效；本方法只清理朗读会话。
  void stop(AudioState snapshot) {
    _synthesisQueue.cancelAll();
    final retention = _settings.current.audioCacheCleanTime;
    _cacheRetentionMinutes = retention;
    _cachePrepared = false;
    _ttsPauseBarrier = Future.value();
    _paragraphTimer?.cancel();
    _noEngineHintShown = false;
    _speakGeneration++;
    final token = _playToken;
    observeControl(_systemEngine.stop());
    _paragraphs = [];
    _paragraphUnits = [];
    readAloudPosition.value = null;
    restoreReadAloudFollow();
    _paragraphIndex = 0;
    _paragraphStartOffset = 0;
    _pendingChapterPos = null;
    _pendingParagraphIndex = null;
    _waitingForParagraph = false;
    observeControl(
      stopFilePlayback().then(
        (_) => _cleanTtsCache(snapshot, retention, token: token),
      ),
      errorPrefix: '音频播放控制失败',
    );
    _host.changed();
  }

  /// 两种宿主释放入口共用同一次清理，不在释放后访问Ref或重新读取状态。
  void dispose({AudioState? snapshot}) {
    if (_released) return;
    _released = true;
    _paragraphTimer?.cancel();
    readAloudPosition.dispose();
    followReadAloud.dispose();
    unawaited(
      _systemEngine.dispose().catchError((Object error) {
        debugPrint('释放系统朗读失败：$error');
      }),
    );
    _synthesisQueue.cancelAll();
    unawaited(
      stopFilePlayback()
          .then((_) async {
            if (snapshot != null) {
              await _cleanTtsCache(snapshot, _cacheRetentionMinutes);
            }
          })
          .catchError((Object error) {
            debugPrint('释放朗读音频失败：$error');
          }),
    );
  }

  /// 无可用引擎提示：同一朗读会话只出现一次
  void _showNoEngineHintOnce() {
    if (_noEngineHintShown) return;
    _noEngineHintShown = true;
    if (_state.errorMessage == kNoUsableEngineHint) return;
    _state = _state.copyWith(errorMessage: kNoUsableEngineHint);
  }
}
