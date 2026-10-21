import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/contracts/audio_book_service.dart';
import 'package:flutter_legado/src/domain/contracts/audio_playback_settings_repository.dart';
import 'package:flutter_legado/src/domain/models/audio_media.dart';
import 'package:flutter_legado/src/domain/models/audio_playback_settings.dart';
import 'package:flutter_legado/src/features/audio/playback/audio_book_controller.dart';
import 'package:flutter_legado/src/features/audio/playback/audio_book_host.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/features/audio/application/audio_state.dart';

import '../mocks/mocks.dart';

class AudioBookSettings extends Fake
    implements AudioPlaybackSettingsRepository {
  AudioPlaybackSettings value = const AudioPlaybackSettings();
  Object? loadError;
  @override
  AudioPlaybackSettings get current => value;
  @override
  Future<AudioPlaybackSettings> load() async {
    if (loadError != null) throw loadError!;
    return value;
  }
}

class ControllerAudioBookService extends Fake implements AudioBookService {
  final requests = <(String, int)>[];
  final progressReads = <(String, int)>[];
  final saves = <({String bookUrl, int chapterIndex, int position})>[];
  final progress = <(String, int), int>{};
  Future<AudioChapterMedia> Function(String, int)? resolveMedia;
  Object? progressError, saveError;

  @override
  Future<AudioChapterMedia> getAudioChapterMedia(String bookUrl, int index) {
    requests.add((bookUrl, index));
    return resolveMedia?.call(bookUrl, index) ??
        Future.value(AudioChapterMedia(mediaUrl: 'https://audio/$index.mp3'));
  }

  @override
  Future<int> getAudioProgress(String bookUrl, int index) async {
    progressReads.add((bookUrl, index));
    if (progressError != null) throw progressError!;
    return progress[(bookUrl, index)] ?? 0;
  }

  @override
  Future<void> saveAudioProgress(
    String bookUrl,
    int index,
    int position,
  ) async {
    if (saveError != null) throw saveError!;
    saves.add((bookUrl: bookUrl, chapterIndex: index, position: position));
    progress[(bookUrl, index)] = position;
  }
}

/// 只有明确端口与共享播放器替身，不创建Notifier或Riverpod容器。— Codex + UI
class AudioBookControllerFixture {
  AudioBookControllerFixture() {
    controller = AudioBookController(
      host: AudioBookHost(
        readState: () => state,
        writeState: (value) => state = value,
        currentToken: () => token,
        advanceToken: () => ++token,
        isDisposed: () => hostDisposed,
        boundBook: () => book,
        stopSystemTts: () async => systemStops++,
        activateMedia: ({bool userInitiated = false}) async =>
            mediaActivations++,
        consumeChapterStop: () {
          boundaries++;
          return stopAtBoundary;
        },
        nextChapter: next,
        replay: () async {
          actions.add('循环');
          await controller.play();
        },
        pause: pause,
        stop: stop,
      ),
      service: service,
      settings: settings,
      player: player,
      clock: () => clock,
    );
    player.loadedDuration = const Duration(minutes: 2);
    player.onCompleted = controller.handleCompleted;
    player.onError = controller.handleError;
    player.onProgress = controller.handleProgress;
  }

  final service = ControllerAudioBookService();
  final settings = AudioBookSettings();
  final player = FakeStreamAudioPlayer();
  late final AudioBookController controller;
  final actions = <String>[];
  final states = <AudioState>[];
  bool hostDisposed = false, stopAtBoundary = false;
  int token = 0,
      clock = 1000,
      systemStops = 0,
      mediaActivations = 0,
      boundaries = 0;
  Book? book;
  AudioState _state = AudioState(
    bookUrl: 'book',
    bookName: '测试书',
    config: TtsConfig(),
    isStreamMode: true,
    chapters: List.generate(
      3,
      (index) => AudioChapter(index: index, title: '第$index章', text: ''),
    ),
  );

  AudioState get state {
    if (hostDisposed) throw StateError('销毁后读取宿主状态');
    return _state;
  }

  set state(AudioState value) {
    if (hostDisposed) throw StateError('销毁后写入宿主状态');
    _state = value;
    states.add(value);
  }

  Future<void> next() async {
    actions.add('下一章');
    await controller.persistPosition(force: true);
    state = state.copyWith(currentIndex: state.currentIndex + 1);
    await controller.play();
  }

  void pause() {
    actions.add('暂停');
    controller.pause();
    state = state.copyWith(state: PlayerState.paused);
  }

  void stop() {
    actions.add('停止');
    unawaited(controller.persistPosition(force: true));
    token++;
    state = state.copyWith(state: PlayerState.idle, positionMs: 0);
    unawaited(player.stop());
  }

  Future<void> progress(
    int milliseconds, {
    int durationMs = 120000,
    int elapsedMs = 500,
  }) async {
    clock += elapsedMs;
    player.emitProgress(
      Duration(milliseconds: milliseconds),
      Duration(milliseconds: durationMs),
    );
    await flush();
  }

  /// 让实际回调、存储及跳过策略的微任务完成，不等待真实网络或媒体。
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  void close() {
    if (hostDisposed) return;
    controller.dispose(snapshot: _state);
    hostDisposed = true;
  }
}
