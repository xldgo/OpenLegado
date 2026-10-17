import 'dart:async';

import '../../../domain/contracts/http_tts_synthesizer.dart';
import '../../../services/audio_playlist_player.dart';
import '../../../services/stream_audio_player.dart';
import '../../../services/read_aloud_diagnostics.dart';
import 'read_aloud_engine.dart';

/// 前方至多准备两项；本章历史来源及租约随原生停止统一释放。— Codex + UI
final class FileReadAloudPlaylist {
  FileReadAloudPlaylist({required this.player, required this.synthesize});
  final StreamAudioPlayer player;
  final Future<HttpTtsSynthesisResult> Function(
    ReadAloudRequest,
    HttpTtsCancellation,
  )
  synthesize;
  AudioPlaylistPlayer get _native => player as AudioPlaylistPlayer;
  List<ReadAloudPlaylistCue> _cues = [];
  final _audio = <int, HttpTtsAudio>{};
  final _ready = <int>[];
  ReadAloudSession? _session;
  void Function(ReadAloudPlaylistCue)? _onCue;
  HttpTtsCancellation? _pending;
  int _generation = 0,
      _current = 0,
      _next = 0,
      _queuedNext = 0,
      _progressBase = 0;
  bool _loaded = false, _paused = false;
  Object? _fillOwner;
  Object? _appendOwner;
  Timer? _appendTimer, _pumpTimer;
  Object? _failure;
  Future<void> _pauseBarrier = Future.value();

  bool get active => _session != null;
  bool get canResume => _paused && _loaded && player.isInitialized;
  bool _valid(int generation) =>
      generation == _generation && (_session?.isCurrent ?? false) && !_paused;

  Future<HttpTtsAudio?> _synthesize(int index, int generation) async {
    final cancellation = HttpTtsCancellation();
    _pending = cancellation;
    final result = await synthesize(_cues[index].request, cancellation);
    if (!_valid(generation) || cancellation.isCancelled) {
      if (result is HttpTtsAudio) await result.lease?.release();
      return null;
    }
    _pending = null;
    if (result is HttpTtsAudio && result.audioPath.trim().isNotEmpty) {
      return result;
    }
    if (result is HttpTtsAudio) await result.lease?.release();
    if (result is HttpTtsCancelled) return null;
    throw result is HttpTtsNoAudio && result.synthesisError != null
        ? result.synthesisError!
        : StateError('朗读合成未返回音频');
  }

  Future<ReadAloudStart> speak(
    List<ReadAloudPlaylistCue> cues,
    ReadAloudSession session, {
    required void Function(ReadAloudPlaylistCue) onCueStarted,
  }) async {
    if (!session.isCurrent || cues.isEmpty) return ReadAloudStart.cancelled;
    _session = session;
    _cues = List.unmodifiable(cues);
    _onCue = onCueStarted;
    _current = 0;
    _next = 0;
    _queuedNext = 0;
    _progressBase = cues.first.sourceOffset;
    _failure = null;
    _paused = false;
    _loaded = false;
    final generation = ++_generation;
    final first = await _synthesize(0, generation);
    if (first == null || !_valid(generation)) return ReadAloudStart.cancelled;
    _audio[0] = first;
    try {
      await _native.startPlaylist(
        AudioPlaylistItem(path: first.audioPath, tag: cues.first),
        speed: cues.first.request.speed,
        onStarted: (tag) => _started(tag, generation),
        onCompleted: (tag) => _ended(tag, generation),
        onProgress: (position, duration, tag) {
          if (!_valid(generation) ||
              duration.inMilliseconds <= 0 ||
              !identical(_native.currentPlaylistTag, tag)) {
            return;
          }
          final cue = tag as ReadAloudPlaylistCue;
          final offset =
              (cue.request.text.length *
                      position.inMilliseconds /
                      duration.inMilliseconds)
                  .floor()
                  .clamp(0, cue.request.text.length);
          _session?.reportProgress(cue.sourceOffset - _progressBase + offset);
        },
        onError: (error) {
          if (_valid(generation)) {
            _loaded = false;
            _session?.fail(error);
          }
        },
      );
    } catch (_) {
      if (generation == _generation) await player.stop();
      if (identical(_audio[0], first)) {
        _audio.remove(0);
        await first.lease?.release();
      }
      rethrow;
    }
    if (!_valid(generation)) return ReadAloudStart.cancelled;
    _next = 1;
    _queuedNext = 1;
    _loaded = true;
    _schedulePump();
    return ReadAloudStart.started;
  }

  void _started(Object tag, int generation) {
    if (!_valid(generation) || !identical(_native.currentPlaylistTag, tag)) {
      return;
    }
    final index = _cues.indexWhere((cue) => identical(cue, tag));
    if (index < 0) return;
    _current = index;
    final cue = _cues[index];
    ReadAloudDiagnostics.instance.event('playlist.cue_started', {
      'playlist': identityHashCode(this),
      'generation': generation,
      'cue': index,
      'paragraph': cue.paragraphIndex,
      'tag': identityHashCode(tag),
      'retained': _audio.length,
      'preparedNext': _next,
      'queuedNext': _queuedNext,
      'ready': _ready.length,
      'totalCues': _cues.length,
      // 字数用于和 item.ended 的时长比对，识别同一份音频内重复朗读。
      'textLength': cue.request.text.length,
    });
    ReadAloudDiagnostics.instance.markFields
      ..['cue'] = index
      ..['paragraph'] = cue.paragraphIndex
      ..['textLength'] = cue.request.text.length
      ..['sourceOffset'] = cue.sourceOffset;
    _onCue?.call(cue);
    if (!_valid(generation)) return;
    _session?.reportProgress(_cues[index].sourceOffset - _progressBase);
    _schedulePump();
  }

  void _ended(Object tag, int generation) {
    if (!_valid(generation)) return;
    final index = _cues.indexWhere((cue) => identical(cue, tag));
    if (index < 0) return;
    if (index == _cues.length - 1) {
      if (!_native.playlistFinished ||
          !identical(_native.currentPlaylistTag, tag)) {
        return;
      }
      _session?.reportProgress(
        _cues[index].sourceOffset -
            _progressBase +
            _cues[index].request.text.length,
      );
      _session?.complete();
    } else {
      _maybeFail(generation);
    }
  }

  void _maybeFail(int generation) {
    if (_valid(generation) &&
        _failure != null &&
        _native.playlistFinished &&
        _ready.isEmpty &&
        _appendOwner == null) {
      _failAtNext(generation);
    }
  }

  void _failAtNext(int generation) {
    if (!_valid(generation) || _failure == null) return;
    // 已播完的片不重播，失败位置是下一份尚未入队的正文。
    final next = _queuedNext.clamp(0, _cues.length - 1);
    _current = next;
    _onCue?.call(_cues[next]);
    _session?.reportProgress(_cues[next].sourceOffset - _progressBase);
    _loaded = false;
    _session?.fail(_failure!);
  }

  void _schedulePump() {
    if (!_loaded || !_valid(_generation) || _pumpTimer != null) return;
    final generation = _generation;
    _pumpTimer = Timer(Duration.zero, () {
      _pumpTimer = null;
      if (!_valid(generation)) return;
      final confirmed = _native.currentPlaylistTag;
      final index = _cues.indexWhere((cue) => identical(cue, confirmed));
      if (index < _current) return;
      _current = index;
      _pump();
      _scheduleAppend();
    });
  }

  void _pump() {
    if (!_loaded ||
        _fillOwner != null ||
        _failure != null ||
        !_valid(_generation) ||
        _next >= _cues.length ||
        _next - _current - 1 >= 2) {
      return;
    }
    final owner = Object();
    _fillOwner = owner;
    final generation = _generation;
    unawaited(() async {
      try {
        while (_valid(generation) &&
            _next < _cues.length &&
            _next - _current - 1 < 2) {
          final index = _next;
          final result = await _synthesize(index, generation);
          if (result == null || !_valid(generation)) return;
          _audio[index] = result;
          _ready.add(index);
          _next = index + 1;
          _scheduleAppend();
        }
      } catch (error) {
        if (_valid(generation)) {
          _failure = error;
          _maybeFail(generation);
        }
      } finally {
        if (identical(_fillOwner, owner)) {
          _fillOwner = null;
          if (_valid(_generation)) _schedulePump();
        }
      }
    }());
  }

  void _scheduleAppend() {
    if (!_loaded ||
        !_valid(_generation) ||
        _ready.isEmpty ||
        _appendOwner != null ||
        _appendTimer != null) {
      return;
    }
    // 仅合并本轮已就绪的音频，不为凑批次等待后续合成，也不延迟首项。
    _appendTimer = Timer(Duration.zero, () {
      _appendTimer = null;
      unawaited(_appendReady(_generation));
    });
  }

  Future<void> _appendReady(int generation) async {
    if (!_valid(generation) || _appendOwner != null || _ready.isEmpty) return;
    final owner = Object();
    _appendOwner = owner;
    final indices = List.of(_ready);
    _ready.clear();
    try {
      // 追加失败也可能已有原生引用，全部租约保留到停止确认之后。
      await _native.appendPlaylist([
        for (final index in indices)
          AudioPlaylistItem(path: _audio[index]!.audioPath, tag: _cues[index]),
      ]);
      if (generation != _generation) return;
      // 暂停期间原生仍可能提交成功，续播不得再次追加同一批正文。
      _queuedNext = indices.last + 1;
    } catch (error) {
      if (generation == _generation) {
        _failure = error;
        _loaded = false;
        _pending?.cancel();
        _session?.fail(error);
      }
    } finally {
      if (identical(_appendOwner, owner)) {
        _appendOwner = null;
        if (_valid(generation)) {
          _scheduleAppend();
          _schedulePump();
          _maybeFail(generation);
        }
      }
    }
  }

  Future<void> pause() {
    _session?.cancel();
    _paused = true;
    _pending?.cancel();
    _pumpTimer?.cancel();
    _pumpTimer = null;
    return _pauseBarrier = player.pause();
  }

  Future<ReadAloudStart> resume(ReadAloudSession session) async {
    final generation = _generation;
    await _pauseBarrier;
    if (!session.isCurrent || generation != _generation || !canResume) {
      return ReadAloudStart.cancelled;
    }
    _session = session;
    _paused = false;
    _progressBase = _cues[_current].sourceOffset;
    _failure = null;
    await player.resume();
    if (!_valid(generation)) return ReadAloudStart.cancelled;
    // 暂停确认前原生可能已经换项，补齐其原文归属，不重播旧片。
    final tag = _native.currentPlaylistTag;
    if (tag != null && !identical(_cues[_current], tag)) {
      _started(tag, generation);
    }
    if (_native.playlistFinished && tag != null) _ended(tag, generation);
    _schedulePump();
    _scheduleAppend();
    return ReadAloudStart.started;
  }

  Future<void> stop({Future<void>? playbackStopped}) async {
    ++_generation;
    _session?.cancel();
    _session = null;
    _pending?.cancel();
    _pending = null;
    _appendTimer?.cancel();
    _appendTimer = null;
    _pumpTimer?.cancel();
    _pumpTimer = null;
    _loaded = _paused = false;
    _failure = null;
    _pauseBarrier = Future.value();
    final retiring = List.of(_audio.values);
    _audio.clear();
    _ready.clear();
    _fillOwner = null;
    _appendOwner = null;
    _cues = [];
    await (playbackStopped ?? player.stop());
    for (final result in retiring) {
      await result.lease?.release();
    }
  }
}
