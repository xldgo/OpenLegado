import 'dart:async';

import 'package:just_audio/just_audio.dart' as audio;

import 'audio_playlist_player.dart';
import 'stream_audio_player.dart';
import 'read_aloud_diagnostics.dart';

/// 统一纯音频后端：正文队列、音频书和独立试听都使用 just_audio。— Codex + UI
class ReadAloudAudioPlayer extends StreamAudioPlayer
    implements AudioPlaylistPlayer {
  ReadAloudAudioPlayer({
    audio.AudioPlayer Function()? createPlayer,
    this.progressInterval = const Duration(milliseconds: 250),
  }) : _createPlayer = createPlayer ?? _defaultPlayer;

  /// 位置流向上层发布的节流间隔
  ///
  /// 原生位置流默认约 16–200 ms 一次（短音频接近 60 Hz），逐次构造位置对象
  /// 并驱动阅读页/听书页重建会造成持续的 CPU 与帧唤醒。播放事件、换项、
  /// 完成判定与暂停恢复不经过本间隔，仍即时生效。
  final Duration progressInterval;

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
  final _pendingCompleted = Set<Object>.identity();
  DateTime? _positionBaseline;
  Future<void> _mutations = Future.value();
  void Function(Object)? _started, _ended, _failed;
  void Function(Duration, Duration, Object)? _progress;
  final _diagnostics = ReadAloudDiagnostics.instance;
  final Stopwatch _progressClock = Stopwatch()..start();
  int _lastProgressPublishMs = -1 << 30;
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
    final event = player?.playbackEvent;
    return _queueMode &&
        player != null &&
        event != null &&
        event.processingState == audio.ProcessingState.completed &&
        event.currentIndex == player.currentIndex &&
        (event.duration ?? Duration.zero) > Duration.zero;
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
      _syncStructure(generation);
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

  void _complete(Object tag, int generation) {
    if (generation == _generation && _queueMode && _completed.add(tag)) {
      _ended?.call(tag);
    }
  }

  void _syncStructure(int generation) {
    if (generation != _generation || !_queueMode || _editing) return;
    final player = _native!;
    final tag = player.sequenceState.currentSource?.tag;
    if (tag == null) return;
    final completed = List.of(_pendingCompleted);
    _pendingCompleted.clear();
    for (final previous in completed) {
      if (!identical(previous, tag)) _complete(previous, generation);
      if (generation != _generation || !_queueMode) return;
    }
    if (!identical(_active, tag)) {
      _trace('player.item_changed', {
        'previousTag': _active == null ? null : identityHashCode(_active!),
      });
      _active = tag;
      // 换项事件可能仍带上一项的位置和时长，先等待下一份原生位置基点。
      _positionBaseline = player.playbackEvent.updateTime;
      _started?.call(tag);
    }
    if (generation != _generation || !_queueMode) return;
    if (completed.any((item) => identical(item, tag)) || playlistFinished) {
      _complete(tag, generation);
    }
  }

  void _onDiscontinuity(audio.PositionDiscontinuity change, int generation) {
    if (generation != _generation || !_queueMode) return;
    if (change.reason == audio.PositionDiscontinuityReason.autoAdvance) {
      final sequence = _native!.sequence;
      final index = change.previousEvent.currentIndex;
      // 本章来源只追加，索引不会因删除历史项而指向另一份正文。
      if (index != null && index >= 0 && index < sequence.length) {
        final tag = sequence[index].tag;
        if (tag != null) _pendingCompleted.add(tag);
      }
    }
    _syncStructure(generation);
  }

  void _onProcessingState(int generation) {
    if (generation != _generation || !_queueMode) return;
    if (playlistFinished) {
      final tag = _native!.sequenceState.currentSource?.tag;
      if (tag != null) _pendingCompleted.add(tag);
    }
    _syncStructure(generation);
  }

  /// 位置发布节流：只有到点才向上层报告，返回 false 表示本帧跳过。
  bool _allowPositionPublish() {
    final now = _progressClock.elapsedMilliseconds;
    if (now - _lastProgressPublishMs < progressInterval.inMilliseconds) {
      return false;
    }
    _lastProgressPublishMs = now;
    return true;
  }

  void _publishProgress(int generation, {bool sampled = false}) {
    _diagnostics.count('player.sync');
    if (generation != _generation || !_queueMode || _editing) return;
    final player = _native!;
    final event = player.playbackEvent;
    final tag = player.sequenceState.currentSource?.tag;
    if (tag == null ||
        !identical(tag, _active) ||
        event.currentIndex != player.currentIndex) {
      return;
    }
    final baseline = _positionBaseline;
    var freshBaseline = false;
    if (baseline != null) {
      if (!event.updateTime.isAfter(baseline)) return;
      _positionBaseline = null;
      // 换项后的第一份位置基点必须立即发布，不从节流窗口里丢掉。
      freshBaseline = true;
    }
    // 位置采样按间隔合并；播放事件与换项不受影响。
    if (sampled && !freshBaseline && !_allowPositionPublish()) {
      return;
    }
    final position = player.position;
    if (_diagnostics.enabled) {
      if (_lastDiagnosticSession != _diagnostics.session) {
        _lastDiagnosticSession = _diagnostics.session;
        _lastDiagnosticTag = null;
        _lastDiagnosticSample = 0;
      }
      final positionMs = position.inMilliseconds;
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
    _diagnostics.count('player.progress_publish');
    _progress?.call(position, event.duration ?? Duration.zero, tag);
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
      player.sequenceStateStream.listen((_) => _syncStructure(generation)),
      player.positionDiscontinuityStream.listen(
        (change) => _onDiscontinuity(change, generation),
      ),
      player.processingStateStream.listen(
        (_) => _onProcessingState(generation),
      ),
      player.playbackEventStream.listen((_) {
        _diagnostics.count('player.playback_event');
        _publishProgress(generation);
      }),
      player.positionStream.listen((_) {
        _diagnostics.count('player.position_event');
        _publishProgress(generation, sampled: true);
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
  Future<void> appendPlaylist(List<AudioPlaylistItem> items) {
    if (items.isEmpty) return Future.value();
    final sources = [
      for (final item in items)
        audio.AudioSource.uri(_fileUri(item.path), tag: item.tag),
    ];
    final generation = _generation;
    return _mutate(generation, () async {
      final player = _native!;
      _trace('player.append.begin', {
        'addedCount': items.length,
        'addedTags': items.map((item) => identityHashCode(item.tag)).toList(),
        'addedFiles': items
            .map((item) => ReadAloudDiagnostics.fileKey(item.path))
            .toList(),
      });
      final endedTag = playlistFinished
          ? player.sequenceState.currentSource?.tag
          : null;
      if (endedTag != null) _pendingCompleted.add(endedTag);
      await player.addAudioSources(sources);
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
    _syncStructure(generation);
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
    _positionBaseline = null;
    _lastProgressPublishMs = -1 << 30;
    _single = false;
    _singleTag = null;
    _singleUrl = null;
    _completed.clear();
    _pendingCompleted.clear();
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
