import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';

import 'dart:async';

import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/http_read_aloud_engine.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/read_aloud_engine.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/system_read_aloud_engine.dart';
import 'package:flutter_legado/src/platform/tts/system_tts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

class _Lease implements TtsAudioLease {
  int releases = 0;
  @override
  Future<void> release() async {
    releases++;
  }
}

class _Callbacks {
  bool current = true;
  int completions = 0;
  final offsets = <int>[];
  final errors = <Object>[];
  late final session = ReadAloudSession(
    isCurrent: () => current,
    onCompleted: () => completions++,
    onProgress: offsets.add,
    onError: errors.add,
  );
}

class _System extends Fake implements SystemTts {
  @override
  void Function(int start, int end)? onProgress;
  @override
  bool isPaused = false;
  int pauses = 0, stops = 0, resumes = 0, disposals = 0;
  Object? controlError;
  Object? startError;
  final requests =
      <({String text, double speed, double pitch, double volume})>[];
  final speeches = <Completer<SystemTtsOutcome>>[];

  @override
  Future<SystemTtsOutcome> speak(
    String text, {
    double speed = 1,
    double pitch = 1,
    double volume = 1,
    String? voiceKey,
  }) {
    if (startError != null) throw startError!;
    requests.add((text: text, speed: speed, pitch: pitch, volume: volume));
    final speech = Completer<SystemTtsOutcome>();
    speeches.add(speech);
    isPaused = false;
    return speech.future;
  }

  @override
  Future<void> pause() async {
    pauses++;
    if (controlError != null) throw controlError!;
    isPaused = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (controlError != null) throw controlError!;
    isPaused = false;
  }

  @override
  Future<SystemTtsOutcome> resume() {
    resumes++;
    if (startError != null) throw startError!;
    final speech = Completer<SystemTtsOutcome>();
    speeches.add(speech);
    isPaused = false;
    return speech.future;
  }

  @override
  Future<void> dispose() async => disposals++;
}

const _request = ReadAloudRequest(
  text: '甲😀乙丁',
  engineId: 1,
  engineUrl: 'https://tts/{text}',
  speed: 1.25,
  pitch: 1.1,
  volume: 0.8,
  voiceName: '中文',
);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  group('段落会话', () {
    test('自然完成只消费一次，完成后的进度和错误不会写回', () {
      final callbacks = _Callbacks();
      callbacks.session.reportProgress(2);
      callbacks.session.complete();
      callbacks.session.complete();
      callbacks.session.reportProgress(3);
      callbacks.session.fail(StateError('迟到错误'));
      expect(callbacks.completions, 1);
      expect(callbacks.offsets, [2]);
      expect(callbacks.errors, isEmpty);
    });

    test('代数失效与显式取消都丢弃完成、进度和错误', () {
      for (final cancel in [false, true]) {
        final callbacks = _Callbacks();
        if (cancel) {
          callbacks.session.cancel();
        } else {
          callbacks.current = false;
        }
        callbacks.session.reportProgress(1);
        callbacks.session.complete();
        callbacks.session.fail(StateError('旧段'));
        expect(callbacks.completions, 0);
        expect(callbacks.offsets, isEmpty);
        expect(callbacks.errors, isEmpty);
      }
    });

    test('异步错误只消费一次，不能随后自然完成', () {
      final callbacks = _Callbacks();
      final error = StateError('引擎失败');
      callbacks.session.fail(error);
      callbacks.session.fail(error);
      callbacks.session.complete();
      expect(callbacks.errors, [same(error)]);
      expect(callbacks.completions, 0);
    });
  });

  group('HTTP 播放适配', () {
    late MockHttpTtsSynthesizer synthesis;
    late FakeStreamAudioPlayer player;
    late HttpReadAloudEngine engine;
    late _Callbacks callbacks;
    late HttpTtsSynthesizer currentSynthesizer;

    Future<HttpTtsSynthesisResult> synthesisCall(
      MockHttpTtsSynthesizer service,
    ) => service.synthesize(
      cancellation: any(named: 'cancellation'),
      engineId: any(named: 'engineId'),
      text: any(named: 'text'),
      engineUrl: any(named: 'engineUrl'),
      speed: any(named: 'speed'),
      pitch: any(named: 'pitch'),
      volume: any(named: 'volume'),
      voiceName: any(named: 'voiceName'),
    );

    setUp(() {
      synthesis = MockHttpTtsSynthesizer();
      currentSynthesizer = synthesis;
      player = FakeStreamAudioPlayer();
      callbacks = _Callbacks();
      engine = HttpReadAloudEngine(
        synthesizer: () => currentSynthesizer,
        player: player,
      );
      when(() => synthesisCall(synthesis)).thenAnswer(
        (_) async =>
            const HttpTtsAudio(audioPath: ' /cache/a.wav ', fromCache: true),
      );
    });

    test('参数完整交给合成，音频播放使用全局倍速，回调由共享播放器分发', () async {
      void completed(Object? tag) {}
      player.onCompleted = completed;
      expect(
        await engine.speak(_request, callbacks.session),
        ReadAloudStart.started,
      );
      verify(
        () => synthesis.synthesize(
          cancellation: any(named: 'cancellation'),
          engineId: _request.engineId,
          text: _request.text,
          engineUrl: _request.engineUrl,
          speed: 1.25,
          pitch: 1.1,
          volume: 0.8,
          voiceName: '中文',
        ),
      ).called(1);
      expect(player.playedLocalFiles.single, (
        path: '/cache/a.wav',
        speed: 1.25,
      ));
      expect(player.onCompleted, same(completed));
      expect(callbacks.completions, 0);
      engine.handleCompleted(player.currentTag);
      engine.handleCompleted(player.currentTag);
      expect(callbacks.completions, 1);
    });

    for (final reason in HttpTtsNoAudioReason.values) {
      test('$reason 不伪装成播放成功，不加载文件', () async {
        when(() => synthesisCall(synthesis))
            .thenAnswer((_) async => HttpTtsNoAudio(reason));
        expect(
          await engine.speak(_request, callbacks.session),
          ReadAloudStart.noAudio,
        );
        expect(player.playedLocalFiles, isEmpty);
        expect(callbacks.completions, 0);
      });
    }

    test('服务器或规则失败保留原错误，不转换为空音频', () async {
      final error = StateError('服务端配额已用完');
      when(() => synthesisCall(synthesis)).thenAnswer(
        (_) async => HttpTtsNoAudio(
          HttpTtsNoAudioReason.synthesisFailed,
          synthesisError: error,
        ),
      );
      await expectLater(
        engine.speak(_request, callbacks.session),
        throwsA(same(error)),
      );
      expect(player.playedLocalFiles, isEmpty);
      expect(callbacks.completions, 0);
    });

    test('空白产物路径也返回无音频', () async {
      when(() => synthesisCall(synthesis))
          .thenAnswer((_) async => const HttpTtsAudio(audioPath: '  '));
      expect(
        await engine.speak(_request, callbacks.session),
        ReadAloudStart.noAudio,
      );
      expect(player.playedLocalFiles, isEmpty);
    });

    test('合成或本地播放失败原样交给协调层，不自行估算推进', () async {
      final error = StateError('失败');
      when(() => synthesisCall(synthesis)).thenThrow(error);
      await expectLater(
        engine.speak(_request, callbacks.session),
        throwsA(same(error)),
      );
      when(
        () => synthesisCall(synthesis),
      ).thenAnswer((_) async => const HttpTtsAudio(audioPath: '/cache/a.wav'));
      player.playLocalError = error;
      await expectLater(
        engine.speak(_request, _Callbacks().session),
        throwsA(same(error)),
      );
      expect(callbacks.completions, 0);
    });

    for (final stop in [false, true]) {
      test('${stop ? '停止' : '代数失效'}后迟到的合成不能装载播放器', () async {
        final pending = Completer<HttpTtsSynthesisResult>();
        HttpTtsCancellation? cancellation;
        when(() => synthesisCall(synthesis)).thenAnswer((call) {
          cancellation =
              call.namedArguments[#cancellation] as HttpTtsCancellation;
          return pending.future;
        });
        final started = engine.speak(_request, callbacks.session);
        if (stop) {
          await engine.stop();
          expect(
            cancellation?.isCancelled,
            isTrue,
            reason: '停止必须取消实际合成，不只丢弃回调',
          );
        } else {
          callbacks.current = false;
        }
        pending.complete(const HttpTtsAudio(audioPath: '/cache/old.wav'));
        expect(await started, ReadAloudStart.cancelled);
        expect(player.playedLocalFiles, isEmpty);
      });
    }

    test('进度换算使用 UTF-16，忽略零时长、旧段和音频书标签', () async {
      await engine.speak(_request, callbacks.session);
      final oldTag = player.currentTag;
      engine.handleProgress(
        const Duration(seconds: 4),
        const Duration(seconds: 10),
        oldTag,
      );
      expect(callbacks.offsets, [2]);
      engine.handleProgress(
        const Duration(seconds: 20),
        const Duration(seconds: 10),
        oldTag,
      );
      engine.handleProgress(
        const Duration(seconds: -1),
        const Duration(seconds: 10),
        oldTag,
      );
      engine.handleProgress(Duration.zero, Duration.zero, oldTag);
      expect(callbacks.offsets, [2, 4, 0]);
      final next = _Callbacks();
      await engine.speak(_request, next.session);
      engine.handleCompleted(oldTag);
      engine.handleProgress(Duration.zero, const Duration(seconds: 1), oldTag);
      engine.handleCompleted((bookUrl: 'book', chapterIndex: 1));
      expect(callbacks.completions, 0);
      expect(next.completions, 0);
      expect(next.offsets, isEmpty);
    });

    test('HTTP 原位暂停续播，不重新合成或加载；旧回调无效', () async {
      await engine.speak(_request, callbacks.session);
      final tag = player.currentTag;
      player.position = const Duration(seconds: 4);
      await engine.pause();
      expect(engine.canResume, isTrue);
      expect(player.pauseCount, 1);
      expect(player.stopCount, 0);
      engine.handleCompleted(tag);
      expect(callbacks.completions, 0);
      final resumed = _Callbacks();
      expect(await engine.resume(resumed.session), ReadAloudStart.started);
      expect(player.position, const Duration(seconds: 4));
      expect(player.resumeCount, 1);
      expect(player.playedLocalFiles, hasLength(1));
      verify(() => synthesisCall(synthesis)).called(1);
      engine.handleProgress(
        const Duration(seconds: 5),
        const Duration(seconds: 10),
        tag,
      );
      engine.handleCompleted(tag);
      engine.handleProgress(
        const Duration(seconds: 5),
        const Duration(seconds: 10),
        player.currentTag,
      );
      engine.handleCompleted(player.currentTag);
      engine.handleCompleted(player.currentTag);
      expect(callbacks.offsets, isEmpty);
      expect(resumed.offsets, [2]);
      expect(resumed.completions, 1);
    });

    test('快速恢复等待平台暂停确认，等待中停止则不续播', () async {
      for (final stopWhilePausing in [false, true]) {
        await engine.speak(_request, _Callbacks().session);
        final barrier = Completer<void>();
        player.pauseBarrier = barrier.future;
        final pause = engine.pause();
        final resumes = player.resumeCount;
        final resume = engine.resume(_Callbacks().session);
        await _flush();
        expect(player.resumeCount, resumes);
        if (stopWhilePausing) await engine.stop();
        barrier.complete();
        await pause;
        expect(
          await resume,
          stopWhilePausing ? ReadAloudStart.cancelled : ReadAloudStart.started,
        );
        expect(player.resumeCount, resumes + (stopWhilePausing ? 0 : 1));
      }
    });

    test('合成未完成时暂停取消请求，旧产物不进入播放器', () async {
      final result = Completer<HttpTtsSynthesisResult>();
      late HttpTtsCancellation cancellation;
      when(() => synthesisCall(synthesis)).thenAnswer((call) {
        cancellation =
            call.namedArguments[#cancellation] as HttpTtsCancellation;
        return result.future;
      });
      final speech = engine.speak(_request, callbacks.session);
      await engine.pause();
      expect(cancellation.isCancelled, isTrue);
      expect(engine.canResume, isFalse);
      result.complete(const HttpTtsAudio(audioPath: '/cache/late.wav'));
      expect(await speech, ReadAloudStart.cancelled);
      expect(player.playedLocalFiles, isEmpty);
      expect(
        await engine.resume(_Callbacks().session),
        ReadAloudStart.cancelled,
      );
    });

    test('共享播放器被音频书替换后不恢复或消费旧会话', () async {
      await engine.speak(_request, callbacks.session);
      await engine.pause();
      await player.playUrl('https://cdn.example.com/book.mp3', tag: Object());
      expect(engine.canResume, isFalse);
      expect(
        await engine.resume(_Callbacks().session),
        ReadAloudStart.cancelled,
      );
      expect(player.resumeCount, 0);
    });

    test('原位恢复失败保留异常，不会推进正文', () async {
      await engine.speak(_request, callbacks.session);
      await engine.pause();
      final resumed = _Callbacks();
      final error = StateError('设备恢复失败');
      player.resumeError = error;
      await expectLater(engine.resume(resumed.session), throwsA(same(error)));
      expect(callbacks.completions, 0);
      expect(resumed.completions, 0);
    });

    test('音频租约在原位暂停时保留，停止和加载失败各释放一次', () async {
      final lease = _Lease();
      when(() => synthesisCall(synthesis)).thenAnswer(
        (_) async => HttpTtsAudio(audioPath: '/cache/a.wav', lease: lease),
      );
      await engine.speak(_request, callbacks.session);
      await engine.pause();
      expect(lease.releases, 0);
      await engine.resume(_Callbacks().session);
      expect(lease.releases, 0);
      await engine.stop();
      expect(lease.releases, 1);
      await engine.stop();
      expect(lease.releases, 1);
      final failed = _Lease();
      when(() => synthesisCall(synthesis)).thenAnswer(
        (_) async => HttpTtsAudio(audioPath: '/cache/fail.wav', lease: failed),
      );
      player.playLocalError = StateError('加载失败');
      await expectLater(
        engine.speak(_request, _Callbacks().session),
        throwsStateError,
      );
      expect(failed.releases, 1);
      await engine.stop();
      expect(failed.releases, 1);
    });

    test('后续段落读取新的合成注入，不冻结根装配', () async {
      await engine.speak(_request, callbacks.session);
      final replacement = MockHttpTtsSynthesizer();
      when(() => synthesisCall(replacement)).thenAnswer(
        (_) async => const HttpTtsAudio(audioPath: '/cache/new.wav'),
      );
      currentSynthesizer = replacement;
      await engine.speak(_request, _Callbacks().session);
      expect(player.playedLocalFiles.last.path, '/cache/new.wav');
      verify(() => synthesisCall(synthesis)).called(1);
      verify(() => synthesisCall(replacement)).called(1);
    });
  });

  group('系统播放适配', () {
    late _System system;
    late SystemReadAloudEngine engine;
    late _Callbacks callbacks;
    setUp(() {
      system = _System();
      engine = SystemReadAloudEngine(system);
      callbacks = _Callbacks();
    });

    test('起播不等待整段完成，系统参数和真实进度直接转发', () async {
      expect(
        await engine.speak(_request, callbacks.session),
        ReadAloudStart.started,
      );
      expect(system.requests.single, (
        text: _request.text,
        speed: 1.25,
        pitch: 1.1,
        volume: 0.8,
      ));
      system.onProgress!(3, 4);
      expect(callbacks.offsets, [3]);
      expect(callbacks.completions, 0);
      system.speeches.single.complete(SystemTtsOutcome.completed);
      await _flush();
      expect(callbacks.completions, 1);
      system.onProgress!(4, 5);
      expect(callbacks.offsets, [3]);
    });

    test('暂停恢复重新绑定会话，旧完成和进度不能推进', () async {
      await engine.speak(_request, callbacks.session);
      final oldProgress = system.onProgress!;
      await engine.pause();
      expect(engine.canResume, isTrue);
      final resumed = _Callbacks();
      expect(await engine.resume(resumed.session), ReadAloudStart.started);
      expect(system.resumes, 1);
      expect(system.requests.length, 1);
      oldProgress(3, 4);
      system.speeches.first.complete(SystemTtsOutcome.completed);
      system.onProgress!(4, 5);
      await _flush();
      expect(callbacks.offsets, isEmpty);
      expect(callbacks.completions, 0);
      expect(resumed.offsets, [4]);
      system.speeches.last.complete(SystemTtsOutcome.completed);
      await _flush();
      expect(resumed.completions, 1);
    });

    for (final outcome in [
      SystemTtsOutcome.paused,
      SystemTtsOutcome.cancelled,
    ]) {
      test('$outcome 不当成自然完成', () async {
        await engine.speak(_request, callbacks.session);
        system.speeches.single.complete(outcome);
        await _flush();
        expect(callbacks.completions, 0);
        expect(callbacks.session.isCurrent, isFalse);
      });
    }

    test('切换会话和销毁后迟到的完成与错误被丢弃', () async {
      await engine.speak(_request, callbacks.session);
      final next = _Callbacks();
      await engine.speak(_request, next.session);
      system.speeches.first.completeError(StateError('旧段错误'));
      await engine.dispose();
      system.speeches.last.complete(SystemTtsOutcome.completed);
      await _flush();
      expect(system.disposals, 1);
      expect(callbacks.errors, isEmpty);
      expect(next.completions, 0);
    });

    test('当前异步失败携带原异常，同步起播或恢复失败也由会话接收', () async {
      final error = StateError('系统失败');
      await engine.speak(_request, callbacks.session);
      system.speeches.single.completeError(error);
      await _flush();
      expect(callbacks.errors, [same(error)]);
      system.startError = error;
      final starting = _Callbacks();
      await engine.speak(_request, starting.session);
      final resuming = _Callbacks();
      await engine.resume(resuming.session);
      await _flush();
      expect(starting.errors, [same(error)]);
      expect(resuming.errors, [same(error)]);
    });

    test('过期请求不调用系统，停止后不再接受原回调', () async {
      callbacks.current = false;
      expect(
        await engine.speak(_request, callbacks.session),
        ReadAloudStart.cancelled,
      );
      expect(await engine.resume(callbacks.session), ReadAloudStart.cancelled);
      expect(system.requests, isEmpty);
      expect(system.resumes, 0);
      callbacks.current = true;
      await engine.speak(_request, callbacks.session);
      final progress = system.onProgress!;
      await engine.stop();
      progress(1, 2);
      system.speeches.single.complete(SystemTtsOutcome.completed);
      await _flush();
      expect(callbacks.completions, 0);
      expect(callbacks.offsets, isEmpty);
    });

    test('控制失败向上抛出，会话先失效，不能残留完成回调', () async {
      await engine.speak(_request, callbacks.session);
      final error = StateError('停止失败');
      system.controlError = error;
      await expectLater(engine.stop(), throwsA(same(error)));
      system.speeches.single.complete(SystemTtsOutcome.completed);
      await _flush();
      expect(callbacks.completions, 0);
      await expectLater(engine.pause(), throwsA(same(error)));
    });
  });
}
