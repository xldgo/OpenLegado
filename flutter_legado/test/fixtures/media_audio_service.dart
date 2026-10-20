import 'dart:async';
import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/services/audio_service.dart';
import 'package:flutter_legado/src/services/media_session_models.dart';

typedef MediaMetadataCall = ({
  String title,
  String artist,
  String album,
  String mediaId,
  int sessionToken,
  String timerText,
});

/// 只记录平台交互，不创建原生媒体会话。— Codex + UI
class TestMediaAudioService extends Fake implements AudioService {
  final buttons = StreamController<MediaButtonEvent>.broadcast();
  final focus = StreamController<AudioFocusEvent>.broadcast();
  final seeks = StreamController<MediaSeekRequest>.broadcast();
  final metadata = <MediaMetadataCall>[];
  final progress = <MediaPlaybackProgress>[];
  final artwork = <({String mediaId, int token, Uint8List? bytes})>[];
  int initCount = 0, releaseCount = 0;
  int playingCount = 0, pausedCount = 0, stoppedCount = 0;
  int focusRequests = 0, focusAbandons = 0;
  bool? wakeLock;
  Future<void>? initBarrier;
  @override
  bool isInitialized = false;
  @override
  Stream<MediaButtonEvent> get mediaButtonStream => buttons.stream;
  @override
  Stream<AudioFocusEvent> get audioFocusStream => focus.stream;
  @override
  Stream<MediaSeekRequest> get seekStream => seeks.stream;
  @override
  Future<void> init() async {
    initCount++;
    await initBarrier;
    isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    releaseCount++;
    isInitialized = false;
  }

  @override
  Future<bool> requestAudioFocus() async {
    focusRequests++;
    return true;
  }

  @override
  Future<void> abandonAudioFocus() async => focusAbandons++;
  @override
  Future<void> setWakeLock(bool enabled) async => wakeLock = enabled;
  @override
  Future<void> notifyPlaying({int position = 0}) async => playingCount++;
  @override
  Future<void> notifyPaused({int position = 0}) async => pausedCount++;
  @override
  Future<void> notifyStopped() async => stoppedCount++;
  @override
  Future<void> updateProgress(MediaPlaybackProgress value) async =>
      progress.add(value);
  @override
  Future<void> updateMetadata({
    required String title,
    String artist = '',
    String album = '',
    String mediaId = '',
    int sessionToken = 0,
    String timerText = '',
  }) async {
    metadata.add((
      title: title,
      artist: artist,
      album: album,
      mediaId: mediaId,
      sessionToken: sessionToken,
      timerText: timerText,
    ));
  }

  @override
  Future<void> updateArtwork({
    required String mediaId,
    required int sessionToken,
    Uint8List? artworkBytes,
  }) async =>
      artwork.add((mediaId: mediaId, token: sessionToken, bytes: artworkBytes));

  Future<void> closeStreams() async {
    await buttons.close();
    await focus.close();
    await seeks.close();
  }
}

/// 独立宿主拥有唯一播放状态，不使用ProviderContainer或AudioNotifier。
