import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/data/services/chapter_content_service.dart';
import 'package:flutter_legado/src/data/repositories/config_read_aloud_selection_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_settings_repository.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/domain/models/read_aloud_settings.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/read_aloud_controller.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/read_aloud_host.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/platform/tts/system_tts.dart';
import 'package:flutter_legado/src/features/audio/application/audio_state.dart';

import '../mocks/mocks.dart';

class ControllerSettings extends Fake implements ReadAloudSettingsRepository {
  ReadAloudSettings value = const ReadAloudSettings(audioPreDownloadNum: 1);
  @override
  ReadAloudSettings get current => value;
  @override
  Future<ReadAloudSettings> load() async => value;
  @override
  Future<void> update(
    ReadAloudSettings Function(ReadAloudSettings) transform,
  ) async {
    value = transform(value);
  }
}

class ControllerSystem extends Fake implements SystemTts {
  final texts = <String>[];
  final requests = <Completer<SystemTtsOutcome>>[];
  int pauses = 0, stops = 0, disposals = 0;
  Future<void>? pauseBarrier;
  @override
  bool isPaused = false;
  @override
  bool get isSupported => true;
  @override
  void Function(int start, int end)? onProgress;
  @override
  Future<SystemTtsOutcome> speak(
    String text, {
    double speed = 1,
    double pitch = 1,
    double volume = 1,
    String? voiceKey,
  }) {
    isPaused = false;
    texts.add(text);
    final pending = Completer<SystemTtsOutcome>();
    requests.add(pending);
    return pending.future;
  }

  @override
  Future<SystemTtsOutcome> resume() => speak(texts.last);
  @override
  Future<void> pause() async {
    pauses++;
    isPaused = true;
    await pauseBarrier;
  }

  @override
  Future<void> stop() async {
    stops++;
    isPaused = false;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await stop();
  }
}

class ControllerSynth extends Fake implements HttpTtsSynthesizer {
  final inputs = <String>[];
  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required int engineId,
    required String text,
    String? engineUrl,
    double speed = 1,
    double pitch = 1,
    double volume = 1,
    String? voiceName,
    String? toneId,
    String? speakerName,
    String? emotionTag,
    HttpTtsCancellation? cancellation,
  }) async {
    inputs.add(text);
    return HttpTtsAudio(audioPath: '/cache/${inputs.length}.wav');
  }
}

class ControllerCloud extends Fake implements CloudTtsSynthesizer {}

class ControllerCache extends Fake implements TtsCacheRepository {
  final records = <TtsCacheContext>[];
  @override
  bool get supportsAudioFiles => true;
  @override
  Future<void> record(String path, TtsCacheContext context) async {
    records.add(context);
  }

  @override
  Future<TtsCacheClearResult> clear({
    String? name,
    int? beforeTimestampMs,
    String? keepBookUrl,
    int? keepChapterIndex,
  }) async => const TtsCacheClearResult();
}

/// 直接装配控制器，不创建ProviderContainer、Notifier或原生媒体服务。— Codex + UI
class ReadAloudControllerFixture {
  static const first = '第一段。\n\n第二段。';
  static const second = '新章。\n\n末段。';
  final api = MockRustApi();
  final settings = ControllerSettings();
  final system = ControllerSystem();
  final player = FakeStreamAudioPlayer();
  final synthesis = ControllerSynth();
  final cache = ControllerCache();
  late final ReadAloudController controller;
  late AudioState state;
  String engineUrl = systemTtsEngineUrl;
  int token = 0, changes = 0, mediaStarts = 0, mediaUpdates = 0;
  int nextCalls = 0, previousCalls = 0, stopCalls = 0;
  bool disposed = false, stopAtBoundary = false;

  ReadAloudControllerFixture({String bookUrl = 'controller-book'}) {
    state = AudioState(
      config: TtsConfig(),
      bookUrl: bookUrl,
      bookName: '测试小说',
      chapters: [
        AudioChapter(index: 0, title: '第一章', text: ''),
        AudioChapter(index: 1, title: '第二章', text: ''),
      ],
    );
    when(() => api.readingRepository.getChapterContentFull(any(), any()))
        .thenAnswer(
          (call) async => call.positionalArguments[1] == 0 ? first : second,
        );
    when(() => api.httpTtsRepository.getHttpTts()).thenAnswer(
      (_) async => const [
        HttpTts(
          id: 1,
          name: 'HTTP',
          url: 'https://tts.test',
          synthesisThreadCount: 2,
        ),
      ],
    );
    controller = ReadAloudController(
      host: ReadAloudHost(
        readState: () => state,
        writeState: (value) => state = value,
        currentToken: () => token,
        advanceToken: () => ++token,
        isDisposed: () => disposed,
        resolveEngineUrl: () => engineUrl,
        resolveEngineId: () async => 1,
        changed: () => changes++,
        activateMedia: () async {
          mediaStarts++;
        },
        publishProgress: ({bool force = false}) async {
          mediaUpdates++;
        },
        reviseTimeline: () {},
        consumeChapterStop: () => stopAtBoundary,
        nextChapter: nextChapter,
        previousChapter: previousChapter,
        pause: pause,
        stop: stop,
        notifyPaused: () async {},
      ),
      content: ChapterContentService(
        reading: api.readingRepository,
        cache: api.chapterCacheRepository,
      ),
      settings: settings,
      httpTts: api.httpTtsRepository,
      cloudTts: api.cloudTtsRepository,
      voices: api.readAloudVoiceRepository,
      selections: ConfigReadAloudSelectionRepository(api.configRepository),
      httpSynthesizer: synthesis,
      cloudSynthesizer: ControllerCloud(),
      cache: cache,
      player: player,
      systemTts: system,
    );
    player.onCompleted = controller.handleCompleted;
    player.onError = controller.handleError;
    player.onProgress = controller.handleProgress;
  }

  Future<void> nextChapter() async {
    nextCalls++;
    token++;
    controller.interrupt();
    state = state.copyWith(currentIndex: state.currentIndex + 1);
    await controller.play(paragraphIndex: 0);
  }

  Future<void> previousChapter() async {
    previousCalls++;
    token++;
    controller.interrupt();
    state = state.copyWith(currentIndex: state.currentIndex - 1);
    await controller.play(paragraphIndex: 0);
  }

  void pause() {
    controller.pause();
    state = state.copyWith(state: PlayerState.paused);
  }

  Future<void> resume() async {
    if (!await controller.resume()) await controller.play();
  }

  void stop() {
    stopCalls++;
    token++;
    controller.stop(state);
    state = state.copyWith(state: PlayerState.idle);
  }

  void dispose() {
    disposed = true;
    controller.dispose(snapshot: state);
  }
}

Future<void> flushReadAloud() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
