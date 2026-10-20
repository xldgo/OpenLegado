import 'dart:async';

import 'package:flutter_legado/src/bridge/media_dto.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' as controls;
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/services/rust_http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

class _Request extends Fake implements controls.TtsRequest {
  int cancellations = 0;
  int disposals = 0;
  @override
  void cancel() => cancellations++;
  @override
  void dispose() => disposals++;
}

void main() {
  const service = RustHttpTtsSynthesizer();
  late _Bridge bridge;
  late _Request request;
  setUpAll(() => registerFallbackValue(_Request()));
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
    request = _Request();
    when(() => bridge.crateFfiTtsRequestNew()).thenReturn(request);
  });
  tearDown(RustLib.dispose);
  void reply(Future<TtsSpeakDto> value) {
    when(
      () => bridge.crateFfiFfiTtsSpeak(
        request: any(named: 'request'),
        engineId: any(named: 'engineId'),
        text: any(named: 'text'),
        toneId: any(named: 'toneId'),
        speakerName: any(named: 'speakerName'),
        emotionTag: any(named: 'emotionTag'),
      ),
    ).thenAnswer((_) => value);
  }

  test('完整参数和类型化结果保持，音频租约移交且幂等释放', () async {
    when(
      () => bridge.crateFfiFfiTtsSpeak(
        request: request,
        engineId: 42,
        text: '正文😀',
        toneId: 't',
        speakerName: 'sp',
        emotionTag: 'happy',
      ),
    ).thenAnswer(
      (_) async => const TtsSpeakDto(
        audioPath: ' /cache/a.wav ',
        fromCache: true,
        contentType: 'audio/wav',
      ),
    );
    final audio = await service.synthesize(
      engineId: 42,
      text: '正文😀',
      toneId: 't',
      speakerName: 'sp',
      emotionTag: 'happy',
    ) as HttpTtsAudio;
    expect(audio.audioPath, '/cache/a.wav');
    expect(audio.fromCache, true);
    expect(audio.contentType, 'audio/wav');
    expect(request.disposals, 0);
    await audio.lease!.release();
    await audio.lease!.release();
    expect(request.disposals, 1);
  });
  test('voiceName回退保持', () async {
    when(
      () => bridge.crateFfiFfiTtsSpeak(
        request: request,
        engineId: 10,
        text: '正文',
        toneId: null,
        speakerName: '中文音色',
        emotionTag: null,
      ),
    ).thenAnswer(
      (_) async => const TtsSpeakDto(
        audioPath: '/cache/a.mp3',
        fromCache: false,
        contentType: 'audio/mpeg',
      ),
    );
    final audio = await service.synthesize(
      engineId: 10,
      text: '正文',
      voiceName: '中文音色',
    ) as HttpTtsAudio;
    expect(audio.audioPath, '/cache/a.mp3');
    await audio.lease!.release();
  });
  for (final path in ['', '  ']) {
    test('空路径$path返回无音频并释放请求', () async {
      reply(
        Future.value(
          TtsSpeakDto(audioPath: path, fromCache: false, contentType: ''),
        ),
      );
      final result =
          await service.synthesize(engineId: 1, text: '正文') as HttpTtsNoAudio;
      expect(result.reason, HttpTtsNoAudioReason.emptyResult);
      expect(result.synthesisError, isNull);
      expect(request.disposals, 1);
    });
  }
  test('合成失败保持原错误并释放请求', () async {
    final failure = StateError('数据库查询失败');
    reply(Future.error(failure));
    final result =
        await service.synthesize(engineId: 1, text: '正文') as HttpTtsNoAudio;
    expect(result.reason, HttpTtsNoAudioReason.synthesisFailed);
    expect(result.synthesisError, same(failure));
    expect(request.disposals, 1);
  });
  test('取消后迟到结果不移交文件租约', () async {
    final pending = Completer<TtsSpeakDto>();
    reply(pending.future);
    final cancellation = HttpTtsCancellation();
    final operation = service.synthesize(
      engineId: 1,
      text: '正文',
      cancellation: cancellation,
    );
    cancellation.cancel();
    pending.complete(
      const TtsSpeakDto(
        audioPath: '/late.wav',
        fromCache: false,
        contentType: 'audio/wav',
      ),
    );
    expect(await operation, isA<HttpTtsCancelled>());
    expect(request.cancellations, 1);
    expect(request.disposals, 1);
  });
  test('预先取消不创建原生请求', () async {
    final cancellation = HttpTtsCancellation()..cancel();
    expect(
      await service.synthesize(
        engineId: 1,
        text: '正文',
        cancellation: cancellation,
      ),
      isA<HttpTtsCancelled>(),
    );
    verifyZeroInteractions(bridge);
  });
}
