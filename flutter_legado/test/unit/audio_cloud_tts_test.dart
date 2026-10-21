import '../fixtures/app_test_api.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_providers.dart';
import 'package:flutter_legado/src/features/audio/application/audio_notifier.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/platform/audio/app_audio_session.dart';
import 'package:flutter_legado/src/services/audio_service.dart';

import '../mocks/mocks.dart';
import '../fixtures/app_audio_session_backend.dart';

class _Synth implements CloudTtsSynthesizer {
  final inputs = <String>[];
  Object? failure;
  bool noAudio = false;
  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required String engineId,
    required String text,
    String? voiceId,
    Map<String, dynamic>? voiceOptions,
    HttpTtsCancellation? cancellation,
  }) async {
    inputs.add('$engineId:$text');
    if (failure != null) throw failure!;
    if (noAudio) {
      return const HttpTtsNoAudio(HttpTtsNoAudioReason.synthesisFailed);
    }
    return const HttpTtsAudio(audioPath: '/cache/cloud.wav');
  }
}

Future<void> flush() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUpAll(registerFallbacks);
  TestWidgetsFlutterBinding.ensureInitialized();
  test('云端选择清旧 HTTP ID，当前段/续播/切段共用原媒体会话', () async {
    SharedPreferences.setMockInitialValues({});
    final api = MockRustApi();
    await api.cloudTtsRepository.save(
      const CloudTtsEngine(
        id: 'cloud1',
        name: '测试云端',
        credentialKey: 'cloud-tts:cloud1:fixture',
      ),
    );
    final config = <String, String>{'appTtsEngineId': '99'};
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((c) async => config[c.positionalArguments[0]]);
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((c) async {
          config[c.positionalArguments[0] as String] =
              c.positionalArguments[1] as String;
        });
    when(() => api.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => null);
    when(() => api.readingRepository.getChapters(any()))
        .thenAnswer((_) async => const [BookChapter(title: '章节', index: 0)]);
    when(() => api.readingRepository.getChapterContentFull(any(), any()))
        .thenAnswer((_) async => '第一段。\n第二段。');
    final synth = _Synth();
    final player = FakeStreamAudioPlayer();
    final backend = TestAudioSessionBackend();
    final audio = AudioService.forTesting(
      AppAudioSession(backend),
      initializeMedia: (handler) async => handler,
    );
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        cloudTtsSynthesizerProvider.overrideWithValue(synth),
        streamAudioPlayerProvider.overrideWithValue(player),
        audioServiceProvider.overrideWithValue(audio),
      ]),
    );
    addTearDown(container.dispose);
    addTearDown(() async {
      await audio.dispose();
      await backend.source.close();
    });
    final notifier = container.read(audioNotifierProvider.notifier);
    await notifier.loadChapters('book');
    await notifier.setGlobalTtsEngine('cloud://cloud1');
    expect(config['appTtsEngineId'], '');
    expect(await notifier.resolveTtsEngineId(), isNull);
    await notifier.play();
    await flush();
    expect(synth.inputs, ['cloud1:第一段。']);
    expect(player.playedLocalFiles, hasLength(1));
    player.emitProgress(
      const Duration(seconds: 4),
      const Duration(seconds: 10),
    );
    backend.source.add(AppAudioEvent.pause);
    await flush();
    expect(container.read(audioNotifierProvider).state, PlayerState.paused);
    backend.granted = false;
    await notifier.resumeOrPlay();
    await flush();
    expect(player.resumeCount, 0);
    expect(container.read(audioNotifierProvider).state, PlayerState.paused);
    expect(
      container.read(audioNotifierProvider).errorMessage,
      contains('音频会话'),
    );
    backend.granted = true;
    await notifier.resumeOrPlay();
    await flush();
    expect(synth.inputs, hasLength(1));
    expect(player.resumeCount, 1);
    expect(player.position, const Duration(seconds: 4));
    expect(backend.activations.where((active) => active), hasLength(3));
    backend.source.add(AppAudioEvent.interruptionEnded);
    backend.source.add(AppAudioEvent.resume);
    await flush();
    expect(container.read(audioNotifierProvider).state, PlayerState.playing);
    expect(player.resumeCount, 1);
    player.completePlayback();
    await flush();
    expect(synth.inputs, ['cloud1:第一段。', 'cloud1:第二段。']);
    notifier.stop();
    await flush();
  });
  test('云端请求失败或空音频暂停保留当前段，重试成功后才允许推进', () async {
    SharedPreferences.setMockInitialValues({});
    final api = MockRustApi();
    await api.cloudTtsRepository.save(
      const CloudTtsEngine(
        id: 'cloud1',
        name: '测试云端',
        credentialKey: 'cloud-tts:cloud1:fixture',
      ),
    );
    final config = <String, String>{'appTtsEngineId': '99'};
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((c) async => config[c.positionalArguments[0]]);
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((c) async {
          config[c.positionalArguments[0] as String] =
              c.positionalArguments[1] as String;
        });
    when(() => api.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => null);
    when(() => api.readingRepository.getChapters(any()))
        .thenAnswer((_) async => const [BookChapter(title: '章节', index: 0)]);
    when(() => api.readingRepository.getChapterContentFull(any(), any()))
        .thenAnswer((_) async => '第一段。\n第二段。');
    final synth = _Synth();
    final player = FakeStreamAudioPlayer();
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        cloudTtsSynthesizerProvider.overrideWithValue(synth),
        streamAudioPlayerProvider.overrideWithValue(player),
      ]),
    );
    addTearDown(container.dispose);
    final notifier = container.read(audioNotifierProvider.notifier);
    await notifier.loadChapters('book');
    await notifier.setGlobalTtsEngine('cloud://cloud1');
    synth.failure = StateError('云端请求失败');
    await notifier.play();
    await flush();
    expect(container.read(audioNotifierProvider).state, PlayerState.paused);
    expect(notifier.currentParagraphIndex, 0);
    expect(
      container.read(audioNotifierProvider).errorMessage,
      contains('云端请求失败'),
    );
    expect(player.playedLocalFiles, isEmpty);
    synth.failure = null;
    synth.noAudio = true;
    await notifier.resumeOrPlay();
    await flush();
    expect(container.read(audioNotifierProvider).state, PlayerState.paused);
    expect(notifier.currentParagraphIndex, 0);
    synth.noAudio = false;
    await notifier.resumeOrPlay();
    await flush();
    expect(container.read(audioNotifierProvider).state, PlayerState.playing);
    expect(player.playedLocalFiles, hasLength(1));
    player.completePlayback();
    await flush();
    expect(notifier.currentParagraphIndex, 1);
    notifier.stop();
    await flush();
  });
}
