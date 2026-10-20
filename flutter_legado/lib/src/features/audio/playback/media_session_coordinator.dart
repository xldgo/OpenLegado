import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../domain/models/read_aloud_media_timeline.dart';
import '../../../models/book.dart';
import '../application/audio_state.dart';
import '../../../services/audio_service.dart';
import '../../../services/media_artwork_loader.dart';
import '../../../services/media_session_models.dart';
import '../../../services/stream_audio_player.dart';
import 'media_session_host.dart';

/// 朗读与音频书共用的系统媒体协调，不拥有播放事实。— Codex + UI
final class MediaSessionCoordinator {
  MediaSessionCoordinator({
    required this._host,
    required this._audioService,
    required StreamAudioPlayer player,
    required this._artwork,
    required this._clock,
  }) : _streamPlayer = player;

  final MediaSessionHost _host;
  final AudioService _audioService;
  final StreamAudioPlayer _streamPlayer;
  final MediaArtworkLoader _artwork;
  final int Function() _clock;
  AudioState get _state => _host.readState();
  set _state(AudioState value) => _host.writeState(value);
  int get _playToken => _host.currentToken();
  bool get _disposed => _released || _host.isDisposed();
  bool _released = false;
  bool _resumeAfterInterruption = false;
  (int, String)? _interruptionTarget;
  Future<void>? _initializing;
  StreamSubscription<MediaButtonEvent>? _mediaButtonSub;
  StreamSubscription<AudioFocusEvent>? _audioFocusSub;
  StreamSubscription<MediaSeekRequest>? _mediaSeekSub;
  Timer? _mediaProgressTicker;
  ReadAloudMediaClock _ttsMediaClock = ReadAloudMediaClock();
  String _mediaClockKey = '', _lastProgressSignature = '';
  int _mediaTimelineRevision = 0,
      _mediaSeekGeneration = 0,
      _lastMediaProgressAt = -1000;
  (String, int)? _publishedMediaChapter;
  Future<void> _mediaSeekBarrier = Future.value();
  String _lastMediaMetadataSignature = '';
  String? _mediaArtworkIdentity;
  int _mediaArtworkGeneration = 0;

  Future<void> init() {
    if (_disposed || _state.isMediaSessionReady) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  /// 宿主在唯一播放状态变化时调用；周期刷新只在有效媒体会话中运行。
  void stateChanged(AudioState? previous, AudioState next) {
    if (_disposed) return;
    if (!next.isMediaSessionReady || next.state == PlayerState.idle) {
      _mediaProgressTicker?.cancel();
      _mediaProgressTicker = null;
      return;
    }
    _mediaProgressTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(publishProgress());
    });
    scheduleMicrotask(() {
      if (!_disposed) {
        unawaited(publishProgress(force: previous?.state != next.state));
      }
    });
  }

  void reviseTimeline() => _mediaTimelineRevision++;

  void preparePause({bool dueToInterruption = false}) {
    _resumeAfterInterruption = dueToInterruption && _state.isPlaying;
    if (!dueToInterruption) {
      _interruptionTarget = null;
    }
  }

  void prepareResume() {
    _resumeAfterInterruption = false;
    _interruptionTarget = null;
  }

  Future<void> notifyPaused({Future<void>? after}) async {
    final token = _playToken;
    await _audioService.notifyPaused();
    await after;
    if (!_disposed &&
        token == _playToken &&
        !_resumeAfterInterruption &&
        (_state.state == PlayerState.paused ||
            _state.state == PlayerState.error)) {
      await _audioService.abandonAudioFocus();
    }
  }

  void notifyStopped({Future<void>? after}) {
    final token = _playToken;
    unawaited(_audioService.notifyStopped());
    unawaited(
      Future<void>.sync(() async {
        await after;
        if (!_disposed &&
            token == _playToken &&
            _state.state == PlayerState.idle) {
          await _audioService.abandonAudioFocus();
        }
      }).catchError((Object error) {
        debugPrint('释放停止音频会话失败：$error');
      }),
    );
  }

  Future<void> setWakeLock(bool enabled) => _audioService.setWakeLock(enabled);

  Future<void> _initialize() async {
    _cancelSubscriptions();
    await _audioService.init();
    if (_disposed) return;

    _mediaButtonSub = _audioService.mediaButtonStream.listen((event) {
      switch (event) {
        case MediaButtonEvent.play:
          unawaited(_host.resumeOrPlay());
        case MediaButtonEvent.pause:
          _host.pause();
        case MediaButtonEvent.skipToNext:
          unawaited(_skip(forward: true));
        case MediaButtonEvent.skipToPrevious:
          unawaited(_skip(forward: false));
        case MediaButtonEvent.stop:
          _host.stop();
      }
    });
    _mediaSeekSub = _audioService.seekStream.listen((request) {
      unawaited(seek(request));
    });

    _audioFocusSub = _audioService.audioFocusStream.listen((event) {
      switch (event) {
        case AudioFocusEvent.gain:
          final resume =
              _resumeAfterInterruption &&
              _interruptionTarget == (_playToken, _state.bookUrl);
          prepareResume();
          if (resume && _state.state == PlayerState.paused) {
            unawaited(_host.resumeOrPlay());
          }
        case AudioFocusEvent.loss:
          prepareResume();
          _host.pause();
        case AudioFocusEvent.lossTransient:
          if (_state.state != PlayerState.paused) {
            _host.pause(dueToInterruption: true);
            _interruptionTarget = (_playToken, _state.bookUrl);
          }
        case AudioFocusEvent.lossTransientCanDuck:
          break;
      }
    });

    _state = _state.copyWith(isMediaSessionReady: _audioService.isInitialized);
  }

  Future<void> release() async {
    if (_disposed) return;
    invalidate();
    _mediaProgressTicker?.cancel();
    _mediaProgressTicker = null;
    _cancelSubscriptions();
    await _audioService.dispose();
    if (!_disposed) _state = _state.copyWith(isMediaSessionReady: false);
  }

  Future<void> activate() async {
    if (_disposed) return;
    final token = _playToken;
    if (!_state.isMediaSessionReady) await init();
    if (_disposed || token != _playToken) return;
    final granted = await _audioService.requestAudioFocus();
    if (_disposed || token != _playToken || !_state.isPlaying) return;
    if (!granted) throw StateError('无法取得音频会话，请稍后重试');
    if (!_state.isMediaSessionReady) return;
    await updateMetadata();
    await _audioService.notifyPlaying();
    await publishProgress(force: true);
  }

  bool ownsTarget(MediaPlaybackTarget target, {bool matchChapter = true}) =>
      !_disposed &&
      _state.isMediaSessionReady &&
      _state.state != PlayerState.idle &&
      _mediaArtworkIdentity != null &&
      target.mediaId == _state.bookUrl &&
      target.sessionToken == _mediaArtworkGeneration &&
      (!matchChapter || target.chapterIndex == _state.currentIndex);

  Future<void> _skip({required bool forward}) async {
    final bookUrl = _state.bookUrl;
    final session = _mediaArtworkGeneration;
    try {
      await _host.loadPreferences();
      if (_disposed ||
          _state.state == PlayerState.idle ||
          _state.bookUrl != bookUrl ||
          session != _mediaArtworkGeneration) {
        return;
      }
      final byChapter = _state.isStreamMode || _host.mediaButtonPerChapter();
      if (byChapter) {
        await (forward ? _host.nextChapter() : _host.previousChapter());
      } else {
        await (forward ? _host.nextParagraph() : _host.previousParagraph());
      }
      await publishProgress(force: true);
    } catch (error) {
      if (!_disposed) _state = _state.copyWith(errorMessage: '媒体切换失败：$error');
    }
  }

  /// 串行提交系统拖动，等待期间只保留最新请求，旧章/旧会话不执行。
  Future<void> seek(MediaSeekRequest request) {
    if (!ownsTarget(request.target)) return Future.value();
    final generation = ++_mediaSeekGeneration;
    final next = _mediaSeekBarrier.then((_) async {
      if (generation != _mediaSeekGeneration || !ownsTarget(request.target)) {
        return;
      }
      try {
        if (_state.isStreamMode) {
          final duration = _state.durationMs;
          if (duration <= 0 || !_streamPlayer.isInitialized) return;
          final position = request.position.clamp(0, duration);
          final token = _playToken;
          await _streamPlayer.seek(Duration(milliseconds: position));
          if (generation != _mediaSeekGeneration ||
              !ownsTarget(request.target) ||
              token != _playToken) {
            return;
          }
          _state = _state.copyWith(positionMs: position);
          unawaited(
            _host.persistStreamPosition(force: true, positionMs: position),
          );
        } else {
          final content = _state.currentChapter?.text ?? '';
          if (content.isEmpty || !_host.hasReadAloudUnits()) return;
          final offset = readAloudMediaOffset(
            request.position,
            content.length,
            _state.config.speed,
          );
          await _host.seekReadAloud(_state.currentIndex, offset);
        }
        if (generation == _mediaSeekGeneration && ownsTarget(request.target)) {
          await publishProgress(force: true);
        }
      } catch (error) {
        if (generation == _mediaSeekGeneration && ownsTarget(request.target)) {
          _state = _state.copyWith(errorMessage: '媒体定位失败：$error');
        }
      }
    });
    _mediaSeekBarrier = next.catchError((Object _) {});
    return next;
  }

  Future<void> publishProgress({bool force = false}) async {
    if (_disposed ||
        !_state.isMediaSessionReady ||
        _state.state == PlayerState.idle ||
        _publishedMediaChapter != (_state.bookUrl, _state.currentIndex)) {
      return;
    }
    final now = _clock();
    if (!force && now - _lastMediaProgressAt < 900) return;
    _lastMediaProgressAt = now;
    final isStream = _state.isStreamMode;
    final content = _state.currentChapter?.text ?? '';
    final duration = isStream
        ? _state.durationMs
        : readAloudMediaTime(content.length, _state.config.speed);
    var position = _state.positionMs;
    if (!isStream) {
      final key = jsonEncode([
        _state.bookUrl,
        _state.currentIndex,
        _state.config.speed,
        _mediaTimelineRevision,
      ]);
      if (key != _mediaClockKey) {
        _mediaClockKey = key;
        _ttsMediaClock = ReadAloudMediaClock();
      }
      final source = _host.readPosition();
      final offset =
          source?.bookUrl == _state.bookUrl &&
              source?.chapterIndex == _state.currentIndex
          ? source!.offset
          : 0;
      position = _ttsMediaClock.update(
        estimate: readAloudMediaTime(offset, _state.config.speed),
        duration: duration,
        playing: _state.isPlaying,
        now: now,
      );
    }
    final byChapter = isStream || _host.mediaButtonPerChapter();
    final progress = MediaPlaybackProgress(
      mediaId: _state.bookUrl,
      sessionToken: _mediaArtworkGeneration,
      chapterIndex: _state.currentIndex,
      state: switch (_state.state) {
        PlayerState.playing => 'playing',
        PlayerState.loading => 'buffering',
        _ => 'paused',
      },
      position: position.clamp(0, duration > 0 ? duration : 0),
      duration: duration > 0 ? duration : 0,
      speed: isStream ? _state.config.speed : 1,
      canSeek:
          duration > 0 &&
          !_state.isLoading &&
          (isStream ? _streamPlayer.isInitialized : _host.hasReadAloudUnits()),
      hasPrevious:
          _state.hasPrevious || (!byChapter && _host.paragraphIndex() > 0),
      hasNext:
          _state.hasNext ||
          (!byChapter && _host.paragraphIndex() + 1 < _host.paragraphCount()),
      isStream: isStream,
    );
    final signature = jsonEncode(progress.toMap());
    if (signature == _lastProgressSignature) return;
    _lastProgressSignature = signature;
    try {
      await _audioService.updateProgress(progress);
    } catch (_) {
      // 媒体展示失败不改变真实播放；后续时钟或状态更新可重试。
      _lastProgressSignature = '';
    }
  }

  /// 书名、章节和定时分开传递；异步封面不阻塞媒体会话起播。— Codex + UI
  Future<void> updateMetadata() async {
    if (_disposed ||
        !_state.isMediaSessionReady ||
        _state.state == PlayerState.idle) {
      return;
    }
    final book = _host.currentBook();
    final hidden = book != null && _host.isBookHidden(book);
    final title = hidden ? '私密书籍' : _state.bookName;
    final artist = hidden ? '' : _state.currentChapter?.title ?? '';
    final album = title;
    final timerText = _host.timerLabel();
    final mediaId = _state.bookUrl;
    final identity = jsonEncode([
      mediaId,
      book?.origin,
      MediaArtworkLoader.coverUrl(book),
      hidden,
    ]);
    final changedArtwork = identity != _mediaArtworkIdentity;
    if (changedArtwork) {
      _mediaArtworkIdentity = identity;
      _mediaArtworkGeneration++;
    }
    final generation = _mediaArtworkGeneration;
    final signature = jsonEncode([
      mediaId,
      _state.currentIndex,
      generation,
      title,
      artist,
      album,
      timerText,
    ]);
    if (signature == _lastMediaMetadataSignature) return;
    _lastMediaMetadataSignature = signature;
    final chapter = _state.currentIndex;
    await _audioService.updateMetadata(
      title: title,
      artist: artist,
      album: album,
      mediaId: mediaId,
      sessionToken: generation,
      timerText: timerText,
    );
    if (!_disposed &&
        generation == _mediaArtworkGeneration &&
        signature == _lastMediaMetadataSignature) {
      _publishedMediaChapter = (mediaId, chapter);
    }
    if (changedArtwork && !_disposed && generation == _mediaArtworkGeneration) {
      unawaited(_loadMediaArtwork(book, hidden, mediaId, generation));
    }
  }

  Future<void> _loadMediaArtwork(
    Book? book,
    bool hidden,
    String mediaId,
    int generation,
  ) async {
    try {
      final bytes = await _artwork.load(book, hidden: hidden);
      if (_disposed ||
          generation != _mediaArtworkGeneration ||
          _state.bookUrl != mediaId ||
          !_state.isMediaSessionReady ||
          _state.state == PlayerState.idle) {
        return;
      }
      await _audioService.updateArtwork(
        mediaId: mediaId,
        sessionToken: generation,
        artworkBytes: bytes,
      );
    } catch (_) {
      // 封面不影响音频状态，原生已在身份变化时清空旧图。
    }
  }

  void invalidate() {
    prepareResume();
    _mediaSeekGeneration++;
    _publishedMediaChapter = null;
    _lastProgressSignature = '';
    _mediaClockKey = '';
    _mediaArtworkIdentity = null;
    _mediaArtworkGeneration++;
    _lastMediaMetadataSignature = '';
  }

  void _cancelSubscriptions() {
    final subscriptions = <StreamSubscription<dynamic>?>[
      _mediaSeekSub,
      _mediaButtonSub,
      _audioFocusSub,
    ];
    _mediaSeekSub = null;
    _mediaButtonSub = null;
    _audioFocusSub = null;
    for (final subscription in subscriptions) {
      if (subscription != null) unawaited(subscription.cancel());
    }
  }

  /// 容器与显式释放共用；此路径不再读取宿主状态或Ref。
  void dispose() {
    if (_released) return;
    _released = true;
    invalidate();
    _mediaProgressTicker?.cancel();
    _mediaProgressTicker = null;
    _cancelSubscriptions();
    unawaited(_audioService.dispose());
  }
}
