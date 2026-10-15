import 'dart:async';

import 'package:flutter_legado/src/services/audio_playlist_player.dart';

import '../mocks/mocks.dart';

/// 原生队列的确定性夹具：换项由播放器自动完成，不调用下一次playLocalFile。
class FakePlaylistAudioPlayer extends FakeStreamAudioPlayer
    implements AudioPlaylistPlayer {
  final items = <AudioPlaylistItem>[];
  final startedTags = <Object>[];
  int current = 0, starts = 0, peakItems = 0, nativeResumes = 0;
  bool _finished = false, _paused = false;
  Object? appendError, startError;
  Completer<void>? appendGate;
  final discardGates = <Completer<void>>[];
  void Function(Object)? started, completed, error;
  void Function(Duration, Duration, Object)? progress;

  @override
  Object? get currentPlaylistTag => items.isEmpty ? null : items[current].tag;
  @override
  bool get playlistFinished => _finished;

  @override
  Future<void> startPlaylist(
    AudioPlaylistItem first, {
    required double speed,
    required void Function(Object) onStarted,
    required void Function(Object) onCompleted,
    required void Function(Duration, Duration, Object) onProgress,
    required void Function(Object) onError,
  }) async {
    if (startError != null) throw startError!;
    starts++;
    items
      ..clear()
      ..add(first);
    peakItems = peakItems < items.length ? items.length : peakItems;
    current = 0;
    _finished = _paused = false;
    started = onStarted;
    completed = onCompleted;
    progress = onProgress;
    error = onError;
    await super.playLocalFile(first.path, speed: speed, tag: first.tag);
    startedTags.add(first.tag);
    started?.call(first.tag);
  }

  void advance() {
    if (items.isEmpty || _paused || _finished) return;
    final previous = items[current];
    if (current + 1 < items.length) {
      current++;
      currentTag = items[current].tag;
      currentUrl = items[current].path;
      position = Duration.zero;
      completed?.call(previous.tag);
      startedTags.add(items[current].tag);
      started?.call(items[current].tag);
    } else {
      _finished = true;
      isPlaying = false;
      completed?.call(previous.tag);
    }
  }

  @override
  Future<void> appendPlaylist(AudioPlaylistItem item) async {
    await appendGate?.future;
    if (appendError != null) throw appendError!;
    items.add(item);
    if (items.length > peakItems) peakItems = items.length;
    if (_finished && !_paused) {
      current++;
      _finished = false;
      isPlaying = true;
      currentTag = item.tag;
      startedTags.add(item.tag);
      started?.call(item.tag);
    }
  }

  @override
  Future<void> discardPlayedItems() async {
    if (current <= 0) return;
    final retiring = items.take(current).toList();
    if (discardGates.isNotEmpty) await discardGates.removeAt(0).future;
    final playing = items[current];
    items.removeWhere(retiring.contains);
    current = items.indexOf(playing);
  }

  void report(int milliseconds, {int total = 1000}) => progress?.call(
    Duration(milliseconds: milliseconds),
    Duration(milliseconds: total),
    currentPlaylistTag!,
  );

  @override
  Future<void> pause() async {
    _paused = true;
    await super.pause();
  }

  @override
  Future<void> resume() async {
    nativeResumes++;
    _paused = false;
    await super.resume();
    if (_finished && current + 1 < items.length) {
      current++;
      _finished = false;
      currentTag = items[current].tag;
      startedTags.add(items[current].tag);
      started?.call(items[current].tag);
    }
  }

  @override
  Future<void> stop() async {
    items.clear();
    _finished = false;
    await super.stop();
  }
}
