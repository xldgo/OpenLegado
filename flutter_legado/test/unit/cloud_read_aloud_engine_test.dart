import 'dart:async';

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
    HttpTtsCancellation? cancellation,
  }) async {
    texts.add(text);
    cancellations.add(cancellation!);
    return pending?.future ??
        Future.value(HttpTtsAudio(audioPath: '/cache/${texts.length}.wav'));
  }
}

Future<void> flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('分片不拆 emoji/组合字符，拼回完整原文且限宽正常退出', () {
    const text = '甲😀é👨‍👩‍👧‍👦乙';
    final parts = splitCloudSpeechText(text, limit: 12);
    expect(parts.join(), text);
    expect(parts.every((p) => p.length <= 12), true);
    expect(() => splitCloudSpeechText(text, limit: 0), throwsArgumentError);
    expect(() => splitCloudSpeechText('e\u0301', limit: 1), throwsStateError);
  });
  test('超长段逐片播放，原位暂停续播不重合成，整段只完成一次', () async {
    final synth = _Synth();
    final player = FakeStreamAudioPlayer()
      ..loadedDuration = const Duration(seconds: 10);
    final engine = CloudReadAloudEngine(
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
}
