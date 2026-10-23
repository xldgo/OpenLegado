import 'package:flutter_legado/src/domain/models/read_aloud_content.dart';

import '../fixtures/read_aloud_planner.dart';

import 'package:flutter_legado/src/domain/contracts/cloud_tts_provider.dart';

import 'dart:convert';
import 'dart:async';

import 'package:flutter_legado/src/data/repositories/mock_cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/data/repositories/mock_tts_cache_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/cloud_read_aloud_engine.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/read_aloud_engine.dart';

import '../mocks/mocks.dart';

class _Synth implements CloudTtsSynthesizer {
  final texts = <String>[];
  final cancellations = <HttpTtsCancellation>[];
  Completer<HttpTtsSynthesisResult>? pending;
  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required String engineId,
    required String text,
    String? voiceId,
    Map<String, dynamic>? voiceOptions,
    HttpTtsCancellation? cancellation,
  }) async {
    texts.add(text);
    cancellations.add(cancellation!);
    return pending?.future ??
        Future.value(HttpTtsAudio(audioPath: '/cache/${texts.length}.wav'));
  }
}

class _OpenAiRepository extends Fake implements CloudTtsRepository {
  @override
  Future<CloudTtsEngine?> get(String id) async =>
      CloudTtsEngine(id: id, name: '夹具引擎', provider: 'openai_speech');
}

class _DelayedRepository implements CloudTtsRepository {
  @override
  Future<Map<String, CloudTtsCapabilities>> providerCapabilities() =>
      MockCloudTtsRepository().providerCapabilities();

  @override
  Future<CloudTtsSpeechLimits> speechLimits(String provider) =>
      MockCloudTtsRepository().speechLimits(provider);

  @override
  Future<CloudTtsEngine?> get(String id) async =>
      (await pending.future).where((e) => e.id == id).firstOrNull;
  @override
  Future<void> save(CloudTtsEngine engine) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<List<String>> voices(String provider) async => [];
  final pending = Completer<List<CloudTtsEngine>>();
  @override
  Future<List<CloudTtsEngine>> list() => pending.future;
}

class _DelayedPlanner extends FixtureReadAloudPlanner {
  Completer<List<List<SpeechRequestPart>>>? pending;
  @override
  Future<List<List<SpeechRequestPart>>> partition(
    String provider,
    List<String> texts,
  ) => pending?.future ?? super.partition(provider, texts);
}

Future<void> flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('火山按字节分片，分片进度沿用原文偏移且只完成整段一次', () async {
    final repo = MockCloudTtsRepository();
    await repo.save(
      const CloudTtsEngine(
        id: 'volc',
        name: '火山',
        provider: 'volcengine',
        appId: 'app',
        model: 'volcano_tts',
        credentialKey: 'cloud-tts:volc:fixture',
      ),
    );
    final synth = _Synth();
    final player = FakeStreamAudioPlayer()
      ..loadedDuration = const Duration(seconds: 10);
    final engine = CloudReadAloudEngine(
      planner: FixtureReadAloudPlanner(),
      synthesizer: () => synth,
      player: player,
      cache: () => const MockTtsCacheRepository(),
      repository: () => repo,
    );
    player.onCompleted = engine.handleCompleted;
    final progress = <int>[];
    var finished = 0;
    final text = '${'甲' * 340}😀${'乙' * 400}';
    final session = ReadAloudSession(
      isCurrent: () => true,
      onCompleted: () => finished++,
      onProgress: progress.add,
      onError: (e) => fail('$e'),
    );
    await engine.speak(
      ReadAloudRequest(text: text, engineUrl: 'cloud://volc'),
      session,
    );
    expect(synth.texts.single, '${'甲' * 340}😀');
    for (var i = 0; i < 4 && finished == 0; i++) {
      player.completePlayback();
      await flush();
    }
    expect(synth.texts.join(), text);
    expect(
      synth.texts.every((text) => utf8.encode(text).length <= 1024),
      isTrue,
    );
    expect(progress, contains(342));
    expect(finished, 1);
    await engine.stop();
  });

  test('超长段逐片播放，原位暂停续播不重合成，整段只完成一次', () async {
    final synth = _Synth();
    final player = FakeStreamAudioPlayer()
      ..loadedDuration = const Duration(seconds: 10);
    final engine = CloudReadAloudEngine(
      repository: () => _OpenAiRepository(),
      planner: FixtureReadAloudPlanner(),
      synthesizer: () => synth,
      player: player,
      cache: () => const MockTtsCacheRepository(),
    );
    player.onCompleted = engine.handleCompleted;
    player.onProgress = engine.handleProgress;
    var completed = 0;
    final offsets = <int>[];
    ReadAloudSession session() => ReadAloudSession(
      isCurrent: () => true,
      onCompleted: () => completed++,
      onProgress: offsets.add,
      onError: (e) => fail('$e'),
    );
    final text = '甲' * 4100;
    expect(
      await engine.speak(
        ReadAloudRequest(text: text, engineUrl: 'cloud://cloud1', speed: 1.8),
        session(),
      ),
      ReadAloudStart.started,
    );
    expect(synth.texts.single.length, 4000);
    expect(player.playedLocalFiles.single.speed, 1.8);
    player.completePlayback();
    await flush();
    expect(synth.texts.map((t) => t.length), [4000, 100]);
    expect(completed, 0);
    final oldTag = player.currentTag;
    engine.handleProgress(
      const Duration(seconds: 5),
      const Duration(seconds: 10),
      oldTag,
    );
    expect(offsets.last, 4050);
    await engine.pause();
    expect(engine.canResume, true);
    expect(await engine.resume(session()), ReadAloudStart.started);
    expect(synth.texts, hasLength(2));
    engine.handleCompleted(oldTag);
    expect(completed, 0);
    player.completePlayback();
    await flush();
    expect(completed, 1);
    player.completePlayback();
    expect(completed, 1);
    await engine.stop();
  });
  test('在途停止取消旧请求，迟到成功不启动音频、不推进段落', () async {
    final synth = _Synth()..pending = Completer();
    final player = FakeStreamAudioPlayer();
    final engine = CloudReadAloudEngine(
      repository: () => _OpenAiRepository(),
      planner: FixtureReadAloudPlanner(),
      synthesizer: () => synth,
      player: player,
      cache: () => const MockTtsCacheRepository(),
    );
    var completed = 0;
    final speaking = engine.speak(
      const ReadAloudRequest(text: '旧段', engineUrl: 'cloud://cloud1'),
      ReadAloudSession(
        isCurrent: () => true,
        onCompleted: () => completed++,
        onProgress: (_) {},
        onError: (_) {},
      ),
    );
    await flush();
    await engine.stop();
    expect(synth.cancellations.single.isCancelled, true);
    synth.pending!.complete(const HttpTtsAudio(audioPath: '/cache/old.wav'));
    expect(await speaking, ReadAloudStart.cancelled);
    expect(player.playedLocalFiles, isEmpty);
    expect(completed, 0);
  });
  test('百炼按 600 UTF-16 分片，emoji 边界与段内进度保持原文，最后才推进段落', () async {
    final repo = MockCloudTtsRepository();
    await repo.save(
      const CloudTtsEngine(
        id: 'ali',
        name: '百炼',
        provider: 'alibaba_cloud',
        model: 'qwen3-tts-flash',
        credentialKey: 'cloud-tts:ali:fixture',
      ),
    );
    final synth = _Synth();
    final player = FakeStreamAudioPlayer()
      ..loadedDuration = const Duration(seconds: 10);
    final engine = CloudReadAloudEngine(
      planner: FixtureReadAloudPlanner(),
      synthesizer: () => synth,
      player: player,
      cache: () => const MockTtsCacheRepository(),
      repository: () => repo,
    );
    player.onCompleted = engine.handleCompleted;
    var finished = 0;
    final progress = <int>[];
    final text = '${'甲' * 599}😀${'乙' * 605}';
    final session = ReadAloudSession(
      isCurrent: () => true,
      onCompleted: () => finished++,
      onProgress: progress.add,
      onError: (e) => fail('$e'),
    );
    expect(
      await engine.speak(
        ReadAloudRequest(text: text, engineUrl: 'cloud://ali'),
        session,
      ),
      ReadAloudStart.started,
    );
    expect(synth.texts.single.length, 599);
    player.completePlayback();
    await flush();
    expect(synth.texts[1].startsWith('😀'), true);
    expect(synth.texts[1].length, 600);
    engine.handleProgress(
      const Duration(seconds: 5),
      const Duration(seconds: 10),
      player.currentTag,
    );
    expect(progress.last, 899);
    expect(finished, 0);
    player.completePlayback();
    await flush();
    player.completePlayback();
    await flush();
    expect(synth.texts.join(), text);
    expect(synth.texts.every((t) => t.length <= 600), true);
    expect(finished, 1);
    await engine.stop();
  });
  for (final waitForPartition in [false, true]) {
    test('等待${waitForPartition ? '请求分片' : '服务商配置'}时停止，迟到结果不启动播放', () async {
      final repo = _DelayedRepository();
      final planner = _DelayedPlanner();
      if (waitForPartition) {
        planner.pending = Completer<List<List<SpeechRequestPart>>>();
      }
      final synth = _Synth();
      final player = FakeStreamAudioPlayer();
      final engine = CloudReadAloudEngine(
        planner: planner,
        synthesizer: () => synth,
        player: player,
        cache: () => const MockTtsCacheRepository(),
        repository: () => repo,
      );
      final pending = engine.speak(
        const ReadAloudRequest(text: '原文', engineUrl: 'cloud://ali'),
        ReadAloudSession(
          isCurrent: () => true,
          onCompleted: () => fail('停止后不应完成'),
          onProgress: (_) {},
          onError: (e) => fail('$e'),
        ),
      );
      const engines = [
        CloudTtsEngine(id: 'ali', name: '百炼', provider: 'alibaba_cloud'),
      ];
      if (waitForPartition) {
        repo.pending.complete(engines);
        await flush();
      }
      await engine.stop();
      if (waitForPartition) {
        planner.pending!.complete([
          [(start: 0, text: '原文')],
        ]);
      } else {
        repo.pending.complete(engines);
      }
      expect(await pending, ReadAloudStart.cancelled);
      expect(synth.texts, isEmpty);
      expect(player.playedLocalFiles, isEmpty);
      expect(engine.canResume, false);
    });
  }
  test('请求分片失败上抛，不回退合成', () async {
    final repo = _DelayedRepository();
    final planner = _DelayedPlanner()
      ..pending = Completer<List<List<SpeechRequestPart>>>();
    repo.pending.complete([
      const CloudTtsEngine(id: 'ali', name: '百炼', provider: 'alibaba_cloud'),
    ]);
    final synth = _Synth();
    final player = FakeStreamAudioPlayer();
    final engine = CloudReadAloudEngine(
      planner: planner,
      synthesizer: () => synth,
      player: player,
      cache: () => const MockTtsCacheRepository(),
      repository: () => repo,
    );
    final result = engine.speak(
      const ReadAloudRequest(text: '原文', engineUrl: 'cloud://ali'),
      ReadAloudSession(
        isCurrent: () => true,
        onCompleted: () {},
        onProgress: (_) {},
        onError: (_) {},
      ),
    );
    final failed = expectLater(result, throwsStateError);
    planner.pending!.completeError(StateError('查询失败'));
    await failed;
    expect(synth.texts, isEmpty);
    expect(player.playedLocalFiles, isEmpty);
    await engine.stop();
  });
}
