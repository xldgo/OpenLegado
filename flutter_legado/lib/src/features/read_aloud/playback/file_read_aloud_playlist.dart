import 'dart:async';

import '../../../domain/contracts/http_tts_synthesizer.dart';
import '../../../services/audio_playlist_player.dart';
import '../../../services/stream_audio_player.dart';
import 'read_aloud_engine.dart';

/// 只编排当前文件及至多两个后续文件，章节、定时和选择仍归协调层。— Codex + UI
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
  ReadAloudSession? _session;
  void Function(ReadAloudPlaylistCue)? _onCue;
  HttpTtsCancellation? _pending;
  int _generation = 0, _current = 0, _next = 0, _progressBase = 0;
  bool _loaded = false, _paused = false;
  Object? _fillOwner;
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
          if (!_valid(generation) || duration.inMilliseconds <= 0) return;
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
    _loaded = true;
    _pump();
    return ReadAloudStart.started;
  }

  void _started(Object tag, int generation) {
    if (!_valid(generation)) return;
    final index = _cues.indexWhere((cue) => identical(cue, tag));
    if (index < 0) return;
    _current = index;
    _onCue?.call(_cues[index]);
    if (!_valid(generation)) return;
    _session?.reportProgress(_cues[index].sourceOffset - _progressBase);
    unawaited(_retire(generation));
  }

  Future<void> _retire(int generation) async {
    // 换项可能发生在出队确认期间，只释放本次请求前已经播完的文件。
    final before = _current;
    try {
      await _native.discardPlayedItems();
      if (generation != _generation) return;
      final indices = _audio.keys.where((i) => i < before).toList();
      final retiring = [for (final index in indices) _audio.remove(index)!];
      for (final audio in retiring) {
        await audio.lease?.release();
      }
      if (_valid(generation)) _pump();
    } catch (error) {
      if (_valid(generation)) _session?.fail(error);
    }
  }

  void _ended(Object tag, int generation) {
    if (!_valid(generation)) return;
    final index = _cues.indexWhere((cue) => identical(cue, tag));
    if (index < 0) return;
    if (index == _cues.length - 1) {
      _session?.reportProgress(
        _cues[index].sourceOffset -
            _progressBase +
            _cues[index].request.text.length,
      );
      _session?.complete();
    } else if (_failure != null && _native.playlistFinished) {
      _failAtNext(generation);
    }
  }

  void _failAtNext(int generation) {
    if (!_valid(generation) || _failure == null) return;
    // 已播完的片不重播，失败位置是下一份尚未入队的正文。
    final next = _next.clamp(0, _cues.length - 1);
    _current = next;
    _onCue?.call(_cues[next]);
    _session?.reportProgress(_cues[next].sourceOffset - _progressBase);
    _loaded = false;
    _session?.fail(_failure!);
  }

  void _pump() {
    if (!_loaded ||
        _fillOwner != null ||
        _failure != null ||
        !_valid(_generation) ||
        _next >= _cues.length ||
        _audio.length >= 3) {
      return;
    }
    final owner = Object();
    _fillOwner = owner;
    final generation = _generation;
    unawaited(() async {
      try {
        while (_valid(generation) &&
            _next < _cues.length &&
            _audio.length < 3) {
          final index = _next;
          final cue = _cues[index];
          final result = await _synthesize(index, generation);
          if (result == null || !_valid(generation)) return;
          _audio[index] = result;
          // 追加失败也可能已有原生引用，租约保留到队列停止后统一释放。
          await _native.appendPlaylist(
            AudioPlaylistItem(path: result.audioPath, tag: cue),
          );
          if (generation != _generation) return;
          // 原生追加已经提交：即使此刻暂停，续播也必须从后一个未排队项继续。
          _next = index + 1;
          if (!_valid(generation)) return;
        }
      } catch (error) {
        if (_valid(generation)) {
          _failure = error;
          if (_native.playlistFinished) _failAtNext(generation);
        }
      } finally {
        if (identical(_fillOwner, owner)) {
          _fillOwner = null;
          if (_valid(_generation)) _pump();
        }
      }
    }());
  }

  Future<void> pause() {
    _session?.cancel();
    _paused = true;
    _pending?.cancel();
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
    _pump();
    return ReadAloudStart.started;
  }

  Future<void> stop({Future<void>? playbackStopped}) async {
    ++_generation;
    _session?.cancel();
    _session = null;
    _pending?.cancel();
    _pending = null;
    _loaded = _paused = false;
    _failure = null;
    _pauseBarrier = Future.value();
    final retiring = List.of(_audio.values);
    _audio.clear();
    _fillOwner = null;
    _cues = [];
    await (playbackStopped ?? player.stop());
    for (final result in retiring) {
      await result.lease?.release();
    }
  }
}
