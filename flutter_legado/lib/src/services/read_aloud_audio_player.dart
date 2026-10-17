import 'dart:async';
import 'dart:collection';

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
  }) : _createPlayer = createPlayer ?? _defaultPlayer {
    _diagnostics.markSnapshot = _markProvider;
  }

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
  final _timeline = <audio.UriAudioSource>[];
  final _transitions = Queue<_PlaybackTransition>();
  int _confirmedIndex = -1, _control = 0;
  int? _seekTarget;
  bool _loaded = false, _delivering = false;
  Object? _pendingStarted;
  audio.PlaybackEvent? _terminal;
  DateTime? _initialTime, _committedTime;
  Timer? _reconcileTimer;
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

  /// 最近换项序列（含文件、位置和时间），供用户标记时回看是第几段。
  final List<Map<String, Object?>> _recentItems = [];

  Map<String, Object?> _markSnapshot() => {
    ..._diagnosticSnapshot(),
    'recentItems': List<Map<String, Object?>>.of(_recentItems),
  };
  late final Map<String, Object?> Function() _markProvider = _markSnapshot;

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
      'confirmedIndex': _confirmedIndex,
      'confirmedTag': _active == null ? null : identityHashCode(_active!),
      'pendingTransitions': _transitions.length,
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
        player.processingState == audio.ProcessingState.completed &&
        event.currentIndex == _confirmedIndex &&
        event.currentIndex == player.currentIndex &&
        identical(_currentSource?.tag, _active) &&
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
      _drainTransitions(generation);
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

  bool _owns(int generation) => generation == _generation && _queueMode;

  Object? _tagAt(int? index) =>
      index != null && index >= 0 && index < _timeline.length
      ? _timeline[index].tag
      : null;

  bool _eventOwns(audio.PlaybackEvent event, int index, Object tag) =>
      event.currentIndex == index &&
      identical(_tagAt(index), tag) &&
      !event.updateTime.isBefore(_committedTime ?? event.updateTime);

  void _recordStarted(Object? previous) {
    final source = _timeline[_confirmedIndex];
    final fields = <String, Object?>{
      'previousTag': previous == null ? null : identityHashCode(previous),
      'tag': identityHashCode(_active!),
      'index': _confirmedIndex,
      'file': ReadAloudDiagnostics.fileKey(source.uri.toString()),
      'positionMs': 0,
    };
    _trace('player.item_changed', fields);
    if (_diagnostics.enabled) {
      _recentItems.add({
        ...fields,
        'wallMs': DateTime.now().millisecondsSinceEpoch,
      });
      if (_recentItems.length > 12) _recentItems.removeAt(0);
    }
    _pendingStarted = _active;
  }

  void _drainTransitions(int generation) {
    if (!_owns(generation) ||
        !_loaded ||
        _editing ||
        _delivering ||
        _seekTarget != null ||
        !_playRequested) {
      return;
    }
    _delivering = true;
    try {
      if (_active == null && _timeline.isNotEmpty) {
        _confirmedIndex = 0;
        _active = _tagAt(0);
        _committedTime = _positionBaseline = _initialTime;
        _recordStarted(null);
      }
      while (_owns(generation) && _playRequested && !_editing) {
        final pending = _pendingStarted;
        if (pending != null) {
          _pendingStarted = null;
          final control = _control;
          _started?.call(pending);
          if (!_owns(generation) || !_playRequested || control != _control) {
            return;
          }
        }
        if (_transitions.isEmpty) break;
        final step = _transitions.removeFirst();
        if (step.control != _control ||
            !identical(_tagAt(step.to), step.toTag) ||
            !_eventOwns(step.event, step.to, step.toTag)) {
          continue;
        }
        if (!step.seek &&
            (step.from != _confirmedIndex ||
                step.to != step.from + 1 ||
                !identical(step.fromTag, _active))) {
          _trace('player.transition_ignored', {
            'fromIndex': step.from,
            'toIndex': step.to,
          });
          continue;
        }
        final previous = _active;
        final changed = !identical(previous, step.toTag);
        // 先提交事实与去重，再交给可能暂停、停止或更换会话的外部回调。
        _confirmedIndex = step.to;
        _active = step.toTag;
        _committedTime = _positionBaseline = step.event.updateTime;
        if (changed) _recordStarted(previous);
        if (!step.seek && previous != null && _completed.add(previous)) {
          final control = _control;
          _ended?.call(previous);
          if (!_owns(generation) || control != _control) return;
        }
      }
      final end = _terminal;
      if (!_owns(generation) ||
          !_playRequested ||
          end == null ||
          _active == null ||
          !_eventOwns(end, _confirmedIndex, _active!) ||
          !playlistFinished) {
        return;
      }
      _terminal = null;
      if (_completed.add(_active!)) _ended?.call(_active!);
    } finally {
      _delivering = false;
    }
  }

  void _onDiscontinuity(audio.PositionDiscontinuity change, int generation) {
    if (!_owns(generation)) return;
    final from = change.previousEvent.currentIndex,
        to = change.event.currentIndex;
    final fromTag = _tagAt(from), toTag = _tagAt(to);
    final seek = change.reason == audio.PositionDiscontinuityReason.seek;
    if (from == null ||
        to == null ||
        fromTag == null ||
        toTag == null ||
        change.event.updateTime.isBefore(change.previousEvent.updateTime) ||
        (seek
            ? _seekTarget != to
            : (_seekTarget != null ||
                  to != from + 1 ||
                  to <= _confirmedIndex))) {
      _trace('player.transition_ignored', {
        'fromIndex': from,
        'toIndex': to,
        'reason': change.reason.name,
      });
      return;
    }
    if (!_transitions.any(
      (s) =>
          s.control == _control &&
          s.from == from &&
          s.to == to &&
          s.seek == seek,
    )) {
      _trace('player.transition_candidate', {
        'fromIndex': from,
        'toIndex': to,
        'reason': change.reason.name,
        'eventTimeMs': change.event.updateTime.millisecondsSinceEpoch,
        'control': _control,
      });
      _transitions.add(
        _PlaybackTransition(
          from,
          to,
          fromTag,
          toTag,
          change.event,
          _control,
          seek,
        ),
      );
    }
    _drainTransitions(generation);
  }

  void _onPlaybackEvent(audio.PlaybackEvent event, int generation) {
    if (!_owns(generation)) return;
    _diagnostics.count('player.playback_event');
    if (_seekTarget == null &&
        event.processingState == audio.ProcessingState.completed &&
        event.currentIndex == _timeline.length - 1 &&
        (event.duration ?? Duration.zero) > Duration.zero) {
      _terminal = event;
    }
    _drainTransitions(generation);
    _scheduleReconcile(generation);
    _publishProgress(generation);
  }

  void _scheduleReconcile(int generation) {
    if (!_owns(generation) ||
        _reconcileTimer != null ||
        (_terminal == null && _transitions.isEmpty)) {
      return;
    }
    // 派生索引可能晚于PlaybackEvent到达；只复核既有证据，不从快照创造转换。
    _reconcileTimer = Timer(Duration.zero, () {
      _reconcileTimer = null;
      _drainTransitions(generation);
    });
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
    List<AudioPlaylistItem> initialFollowing = const [],
    required double speed,
    required void Function(Object) onStarted,
    required void Function(Object) onCompleted,
    required void Function(Duration, Duration, Object) onProgress,
    required void Function(Object) onError,
  }) => _startSource(
    audio.AudioSource.uri(_fileUri(first.path), tag: first.tag),
    initialFollowing: [
      for (final item in initialFollowing)
        audio.AudioSource.uri(_fileUri(item.path), tag: item.tag),
    ],
    speed: speed,
    onStarted: onStarted,
    onCompleted: onCompleted,
    onProgress: onProgress,
    onError: onError,
  );

  Future<void> _startSource(
    audio.UriAudioSource source, {
    List<audio.UriAudioSource> initialFollowing = const [],
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
    _timeline.addAll([source, ...initialFollowing]);
    _started = onStarted;
    _ended = onCompleted;
    _progress = onProgress;
    _failed = onError;
    final player = _native ??= _createPlayer();
    _trace('player.load.request', {
      'file': ReadAloudDiagnostics.fileKey(source.uri.toString()),
    });
    _subscriptions.addAll([
      player.sequenceStateStream.listen((_) => _scheduleReconcile(generation)),
      player.positionDiscontinuityStream.listen(
        (change) => _onDiscontinuity(change, generation),
      ),
      player.playbackEventStream.listen(
        (event) => _onPlaybackEvent(event, generation),
      ),
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
        await player.setAudioSources([source, ...initialFollowing]);
        if (!_owns(generation)) return;
        _initialTime = player.playbackEvent.updateTime;
        _loaded = true;
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
      _timeline.addAll(sources);
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
      await _seekTo(Duration.zero, nextIndex, generation);
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
      await _seekTo(Duration.zero, _confirmedIndex + 1, generation);
    }
    if (generation == _generation && _queueMode && _playRequested) {
      _play(generation);
      _drainTransitions(generation);
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
    if (_queueMode) await _seekTo(position, _confirmedIndex, _generation);
  }

  Future<void> _seekTo(Duration position, int index, int generation) async {
    if (!_owns(generation) || _tagAt(index) == null) return;
    final control = ++_control;
    _seekTarget = index;
    _terminal = null;
    _transitions.clear();
    _pendingStarted = null;
    _completed.remove(_tagAt(index));
    final previous = _native!.playbackEvent;
    try {
      await _native!.seek(position, index: index);
      if (!_owns(generation) || control != _control) return;
      // 平台可能只发位置事件；应用操作归属与实际目标一致时补确认，不猜自然完成。
      final current = _native!.playbackEvent;
      if (current.currentIndex == index &&
          identical(_currentSource?.tag, _tagAt(index))) {
        _onDiscontinuity(
          audio.PositionDiscontinuity(
            audio.PositionDiscontinuityReason.seek,
            previous,
            current,
          ),
          generation,
        );
      }
    } finally {
      if (_owns(generation) && control == _control) _seekTarget = null;
    }
    _onPlaybackEvent(_native!.playbackEvent, generation);
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
    _drainTransitions(generation);
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
    _confirmedIndex = -1;
    _loaded = false;
    _pendingStarted = null;
    _terminal = null;
    _seekTarget = null;
    _initialTime = _committedTime = null;
    ++_control;
    _timeline.clear();
    _transitions.clear();
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
    _positionBaseline = null;
    _lastProgressPublishMs = -1 << 30;
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
    if (identical(_diagnostics.markSnapshot, _markProvider)) {
      _diagnostics.markSnapshot = null;
    }
    _recentItems.clear();
    await _native?.dispose();
    _native = null;
  }
}

/// 保存转换的有序证据，不提前把来源变化归结为某个标签已完成。
final class _PlaybackTransition {
  const _PlaybackTransition(
    this.from,
    this.to,
    this.fromTag,
    this.toTag,
    this.event,
    this.control,
    this.seek,
  );
  final int from, to, control;
  final Object fromTag, toTag;
  final audio.PlaybackEvent event;
  final bool seek;
}
