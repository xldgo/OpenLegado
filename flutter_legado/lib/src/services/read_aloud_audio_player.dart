import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as audio;

import 'audio_playlist_player.dart';
import 'stream_audio_player.dart';
import 'read_aloud_diagnostics.dart';

/// 统一纯音频后端：正文队列、音频书和独立试听都使用 just_audio。— Codex + UI
class ReadAloudAudioPlayer extends StreamAudioPlayer
    implements AudioPlaylistPlayer {
  ReadAloudAudioPlayer({audio.AudioPlayer Function()? createPlayer})
    : _createPlayer = createPlayer ?? _defaultPlayer;

  static audio.AudioPlayer _defaultPlayer() => audio.AudioPlayer(
    handleInterruptions: false,
    handleAudioSessionActivation: false,
    androidApplyAudioAttributes: false,
    useProxyForRequestHeaders: false,
    useLazyPreparation: false,
    maxSkipsOnError: 0,
  );

  final audio.AudioPlayer Function() _createPlayer;
  audio.AudioPlayer? _native;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _queueMode = false, _playRequested = false;
  int _generation = 0, _requestGeneration = 0;
  bool _editing = false;
  Object? _active;
  bool _single = false;
  Object? _singleTag;
  String? _singleUrl;
  final _completed = Set<Object>.identity();
  Future<void> _mutations = Future.value();
  void Function(Object)? _started, _ended, _failed;
  void Function(Duration, Duration, Object)? _progress;
  final _diagnostics = ReadAloudDiagnostics.instance;
  Object? _lastDiagnosticTag;
  int _lastDiagnosticPosition = 0, _lastDiagnosticSample = 0;
  int _lastDiagnosticSession = 0;
  String? _diagnosticUrl, _diagnosticFile;

  Map<String, Object?> _diagnosticSnapshot() {
    final player = _native;
    final source = _currentSource;
    final url = source?.uri.toString();
    if (url != _diagnosticUrl) {
      _diagnosticUrl = url;
      _diagnosticFile = url == null ? null : ReadAloudDiagnostics.fileKey(url);
    }
    return {
      'player': identityHashCode(this),
      'generation': _generation,
      'tag': source?.tag == null ? null : identityHashCode(source!.tag!),
      'file': _diagnosticFile,
      'index': player?.currentIndex,
      'items': player?.sequence.length,
      'positionMs': player?.position.inMilliseconds,
      'durationMs': player?.duration?.inMilliseconds,
      'state': player?.processingState.name,
      'playing': player?.playing,
      'playRequested': _playRequested,
      'editing': _editing,
    };
  }

  void _trace(String event, [Map<String, Object?> extra = const {}]) {
    if (_diagnostics.enabled) {
      _diagnostics.event(event, {..._diagnosticSnapshot(), ...extra});
    }
  }

  @override
  Object? get currentPlaylistTag => _queueMode ? _active : null;
  bool get _itemFinished {
    final player = _native;
    return _queueMode &&
        player != null &&
        player.processingState == audio.ProcessingState.completed &&
        (player.duration ?? Duration.zero) > Duration.zero &&
        player.position >= player.duration!;
  }

  @override
  bool get playlistFinished =>
      _itemFinished && _native!.currentIndex == _native!.sequence.length - 1;

  @override
  Object? get currentTag =>
      _queueMode ? (_single ? _singleTag : _active) : null;
  @override
  bool get isInitialized => _queueMode
      ? _native != null &&
            _native!.processingState != audio.ProcessingState.idle &&
            _native!.processingState != audio.ProcessingState.loading
      : false;
  @override
  bool get isPlaying => _queueMode
      ? _playRequested && (_native?.playing ?? false) && !playlistFinished
      : false;
  @override
  Duration get position =>
      _queueMode ? _native?.position ?? Duration.zero : Duration.zero;
  @override
  Duration get duration =>
      _queueMode ? _native?.duration ?? Duration.zero : Duration.zero;
  @override
  String? get currentUrl => _queueMode
      ? (_single ? _singleUrl : _currentSource?.uri.toString())
      : null;

  audio.UriAudioSource? get _currentSource {
    final source = _native?.sequenceState.currentSource;
    return source is audio.UriAudioSource ? source : null;
  }

  Uri _fileUri(String path) {
    final value = path.trim();
    if (value.isEmpty) throw ArgumentError('队列音频路径为空');
    final uri = Uri.tryParse(value);
    return uri?.scheme == 'file' ? uri! : Uri.file(value);
  }

  Future<void> _mutate(int generation, Future<void> Function() action) {
    final next = _mutations.then((_) async {
      if (generation != _generation || !_queueMode) return;
      // 插件先更新来源列表，再异步校正原生索引；中间态不能当成真实换项。
      _editing = true;
      try {
        await action();
      } finally {
        _editing = false;
      }
      _sync(generation);
    });
    // 已返回的操作仍向调用方报错，后续清理不被旧失败阻断。
    _mutations = next.catchError((Object _) {});
    return next;
  }

  void _play(int generation) {
    final player = _native!;
    _trace('player.play');
    unawaited(
      player.play().catchError((Object error) {
        if (generation == _generation && _queueMode) _failed?.call(error);
      }),
    );
  }

  void _sync(int generation) {
    _diagnostics.count('player.sync');
    if (generation != _generation || !_queueMode || _editing) return;
    final player = _native!;
    final tag = player.sequenceState.currentSource?.tag;
    if (tag == null) return;
    if (_diagnostics.enabled) {
      if (_lastDiagnosticSession != _diagnostics.session) {
        _lastDiagnosticSession = _diagnostics.session;
        _lastDiagnosticTag = null;
        _lastDiagnosticSample = 0;
      }
      final positionMs = player.position.inMilliseconds;
      if (identical(_lastDiagnosticTag, tag) &&
          positionMs + 200 < _lastDiagnosticPosition) {
        _trace('player.position_backwards', {
          'previousMs': _lastDiagnosticPosition,
        });
      }
      _lastDiagnosticTag = tag;
      _lastDiagnosticPosition = positionMs;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastDiagnosticSample >= 1000) {
        _lastDiagnosticSample = now;
        _trace('player.sample');
      }
    }
    if (!identical(_active, tag)) {
      _trace('player.item_changed', {
        'previousTag': _active == null ? null : identityHashCode(_active!),
      });
      final previous = _active;
      _active = tag;
      if (previous != null && _completed.add(previous)) _ended?.call(previous);
      if (generation != _generation || !_queueMode) return;
      _started?.call(tag);
    }
    if (generation != _generation || !_queueMode) return;
    _progress?.call(player.position, player.duration ?? Duration.zero, tag);
    if (playlistFinished && _completed.add(tag)) {
      _ended?.call(tag);
    }
  }

  @override
  Future<void> startPlaylist(
    AudioPlaylistItem first, {
    required double speed,
    required void Function(Object) onStarted,
    required void Function(Object) onCompleted,
    required void Function(Duration, Duration, Object) onProgress,
    required void Function(Object) onError,
  }) => _startSource(
    audio.AudioSource.uri(_fileUri(first.path), tag: first.tag),
    speed: speed,
    onStarted: onStarted,
    onCompleted: onCompleted,
    onProgress: onProgress,
    onError: onError,
  );

  Future<void> _startSource(
    audio.UriAudioSource source, {
    required double speed,
    required void Function(Object) onStarted,
    required void Function(Object) onCompleted,
    required void Function(Duration, Duration, Object) onProgress,
    required void Function(Object) onError,
    bool single = false,
    Object? publicTag,
    String? publicUrl,
  }) async {
    final request = ++_requestGeneration;
    await _stopPlaylist();
    if (request != _requestGeneration) return;
    final generation = ++_generation;
    _queueMode = true;
    _single = single;
    _singleTag = publicTag;
    _singleUrl = publicUrl;
    _playRequested = true;
    _started = onStarted;
    _ended = onCompleted;
    _progress = onProgress;
    _failed = onError;
    final player = _native ??= _createPlayer();
    _trace('player.load.request', {
      'file': ReadAloudDiagnostics.fileKey(source.uri.toString()),
    });
    _subscriptions.addAll([
      player.playbackEventStream.listen((_) {
        _diagnostics.count('player.playback_event');
        _sync(generation);
      }),
      player.positionStream.listen((_) {
        _diagnostics.count('player.position_event');
        _sync(generation);
      }),
      player.errorStream.listen((error) {
        if (generation == _generation && _queueMode) _failed?.call(error);
      }),
    ]);
    try {
      await _mutate(generation, () async {
        await player.setAudioSources([source]);
        _trace('player.load.done');
        if (generation != _generation || !_queueMode) return;
        await player.setSpeed(speed <= 0 ? 1 : speed);
        if (generation != _generation || !_queueMode) return;
        if (_playRequested) _play(generation);
      });
    } catch (_) {
      // 装载失败也要先停掉原生引用；迟到旧失败不得清掉新会话。
      if (generation == _generation) await _stopPlaylist();
      rethrow;
    }
  }

  @override
  Future<void> appendPlaylist(AudioPlaylistItem item) {
    final generation = _generation;
    return _mutate(generation, () async {
      final player = _native!;
      _trace('player.append.begin', {
        'addedTag': identityHashCode(item.tag),
        'addedFile': ReadAloudDiagnostics.fileKey(item.path),
      });
      final endedTag = playlistFinished
          ? player.sequenceState.currentSource?.tag
          : null;
      await player.addAudioSource(
        audio.AudioSource.uri(_fileUri(item.path), tag: item.tag),
      );
      _trace('player.append.end');
      if (generation != _generation || !_queueMode || !_playRequested) return;
      // 追加期间原生可能已经换项，旧的队尾状态不能用来重置新音频。
      if (endedTag == null ||
          !identical(player.sequenceState.currentSource?.tag, endedTag) ||
          !_itemFinished) {
        return;
      }
      final endedIndex = player.sequence.indexWhere(
        (source) => identical(source.tag, endedTag),
      );
      final nextIndex = endedIndex + 1;
      if (endedIndex < 0 || nextIndex >= player.sequence.length) return;
      // 仍停在原音频末尾时才恢复相邻项，不跳到队尾而漏播中间内容。
      _trace('player.seek', {
        'reason': 'append_finished',
        'targetIndex': nextIndex,
        'targetMs': 0,
      });
      await player.seek(Duration.zero, index: nextIndex);
      if (generation == _generation && _queueMode && _playRequested) {
        _play(generation);
      }
    });
  }

  @override
  Future<void> discardPlayedItems() {
    final generation = _generation;
    return _mutate(generation, () async {
      final player = _native!;
      final before = player.currentIndex ?? 0;
      if (before <= 0) return;
      final removed = player.sequence.take(before).map((e) => e.tag).toList();
      final position = player.position;
      _trace('player.discard.begin', {'removeBefore': before});
      await player.removeAudioSourceRange(0, before);
      _trace('player.discard.end');
      if (generation != _generation || !_queueMode) return;
      if (defaultTargetPlatform == TargetPlatform.windows) {
        // WinRT 删除前项不发布新的索引；显式保留当前片位置并同步索引，避免误认下一片。
        _trace('player.seek', {
          'reason': 'windows_remove',
          'targetIndex': 0,
          'targetMs': position.inMilliseconds,
        });
        await player.seek(position, index: 0);
      }
      for (final tag in removed) {
        _completed.remove(tag);
      }
    });
  }

  @override
  Future<void> pause() async {
    if (!_queueMode) return;
    _trace('player.pause');
    _playRequested = false;
    await _native?.pause();
  }

  @override
  Future<void> resume() async {
    if (!_queueMode) return;
    final generation = _generation;
    _playRequested = true;
    final player = _native!;
    _trace('player.resume');
    if (_itemFinished &&
        (player.currentIndex ?? 0) + 1 < player.sequence.length) {
      _trace('player.seek', {
        'reason': 'resume_next',
        'targetIndex': (player.currentIndex ?? 0) + 1,
        'targetMs': 0,
      });
      await player.seekToNext();
    }
    if (generation == _generation && _queueMode && _playRequested) {
      _play(generation);
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    _trace('player.speed', {'speed': speed});
    if (_queueMode) await _native!.setSpeed(speed <= 0 ? 1 : speed);
  }

  @override
  Future<void> seek(Duration position) async {
    _trace('player.seek', {
      'reason': 'explicit',
      'targetMs': position.inMilliseconds,
    });
    if (_queueMode) await _native!.seek(position);
  }

  Future<void> _playSingle(Uri uri, String url, double speed, Object? tag) =>
      _startSource(
        audio.AudioSource.uri(uri, tag: Object()),
        speed: speed,
        single: true,
        publicTag: tag,
        publicUrl: url,
        onStarted: (_) {},
        onCompleted: (_) => onCompleted?.call(_singleTag),
        onProgress: (position, duration, _) =>
            onProgress?.call(position, duration, _singleTag),
        onError: (error) => onError?.call(error, _singleTag),
      );

  @override
  Future<void> playUrl(String url, {double speed = 1, Object? tag}) {
    final value = url.trim();
    if (value.isEmpty) throw ArgumentError('播放地址为空');
    return _playSingle(Uri.parse(value), value, speed, tag);
  }

  @override
  Future<void> playLocalFile(String path, {double speed = 1, Object? tag}) =>
      _playSingle(_fileUri(path), path.trim(), speed, tag);

  @override
  Future<bool> resumeWithTag({
    required Object previousTag,
    required Object tag,
  }) async {
    if (!_single || !isInitialized || !identical(_singleTag, previousTag)) {
      return false;
    }
    final generation = _generation;
    _singleTag = tag;
    if (_itemFinished) _completed.remove(_active);
    await resume();
    _sync(generation);
    return generation == _generation && identical(_singleTag, tag);
  }

  @override
  Future<void> stop() {
    ++_requestGeneration;
    return _stopPlaylist();
  }

  Future<void> _stopPlaylist() async {
    _trace('player.stop');
    final generation = ++_generation;
    _playRequested = false;
    _queueMode = false;
    _active = null;
    _single = false;
    _singleTag = null;
    _singleUrl = null;
    _completed.clear();
    _started = _ended = _failed = null;
    _progress = null;
    final subscriptions = List.of(_subscriptions);
    _subscriptions.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await _native?.stop();
    await _mutations;
    if (_native != null && generation == _generation) {
      await _native!.clearAudioSources();
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _native?.dispose();
    _native = null;
  }
}
