import 'dart:async';

import 'package:flutter/widgets.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// 使用真实VideoPlayerController，只替换原生平台事件与异步操作。— Codex + UI
class FakeVideoPlatform extends VideoPlayerPlatform {
  final playCalls = <int>[], pauseCalls = <int>[], disposed = <int>[];
  final created = <int, VideoCreationOptions>{};
  final _events = <int, StreamController<VideoEvent>>{};
  final _positions = <int, Duration>{};
  Future<void> Function(int, Duration)? onSeek;
  int _nextId = 1;

  @override
  Future<void> init() async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    created[id] = options;
    _events[id] = StreamController<VideoEvent>()
      ..add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 60),
          size: const Size(16, 9),
        ),
      );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async => playCalls.add(playerId);
  @override
  Future<void> pause(int playerId) async => pauseCalls.add(playerId);
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    await onSeek?.call(playerId, position);
    _positions[playerId] = position;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async =>
      _positions[playerId] ?? Duration.zero;
  @override
  Widget buildView(int playerId) => const ColoredBox(color: Color(0xFF000000));
}
