import 'package:flutter_legado/src/bridge/ffi.dart' as controls;
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/services/rust_http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

class _Request extends Fake implements controls.TtsRequest {
  int cancellations = 0;
  @override
  void cancel() => cancellations++;
  @override
  void dispose() {}
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

  void synthesizeReturns(String raw) {
    when(
      () => bridge.crateFfiFfiTtsSpeak(
        request: any(named: 'request'),
        engineId: any(named: 'engineId'),
        text: any(named: 'text'),
        toneId: any(named: 'toneId'),
        speakerName: any(named: 'speakerName'),
        emotionTag: any(named: 'emotionTag'),
      ),
    ).thenAnswer((_) async => raw);
  }

  test('engineId 与参数传递给 Rust，路径和缓存信息返回', () async {
    when(
      () => bridge.crateFfiFfiTtsSpeak(
        request: any(named: 'request'),
        engineId: 42,
        text: '正文 😀',
        toneId: 't1',
        speakerName: 'spk1',
        emotionTag: 'emo1',
      ),
    ).thenAnswer(
      (_) async => '{"audioPath":"  /cache/a.wav  ","fromCache":true,"contentType":"audio/wav"}',
    );

    final audio = await service.synthesize(
      engineId: 42,
      text: '正文 😀',
      toneId: 't1',
      speakerName: 'spk1',
      emotionTag: 'emo1',
    ) as HttpTtsAudio;

    expect(audio.audioPath, '/cache/a.wav');
    expect(audio.fromCache, isTrue);
    expect(audio.contentType, 'audio/wav');

    verify(
      () => bridge.crateFfiFfiTtsSpeak(
        request: any(named: 'request'),
        engineId: 42,
        text: '正文 😀',
        toneId: 't1',
        speakerName: 'spk1',
        emotionTag: 'emo1',
      ),
    ).called(1);
    verify(() => bridge.crateFfiTtsRequestNew()).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('speakerName 缺省时使用 voiceName 回退', () async {
    when(
      () => bridge.crateFfiFfiTtsSpeak(
        request: any(named: 'request'),
        engineId: 10,
        text: '正文',
        toneId: any(named: 'toneId'),
        speakerName: '中文发音人',
        emotionTag: any(named: 'emotionTag'),
      ),
    ).thenAnswer((_) async => '{"audioPath":"/cache/b.mp3"}');

    final audio = await service.synthesize(
      engineId: 10,
      text: '正文',
      voiceName: '中文发音人',
    ) as HttpTtsAudio;

    expect(audio.audioPath, '/cache/b.mp3');
    verify(
      () => bridge.crateFfiFfiTtsSpeak(
        request: any(named: 'request'),
        engineId: 10,
        text: '正文',
        toneId: null,
        speakerName: '中文发音人',
        emotionTag: null,
      ),
    ).called(1);
  });

  test('诊断字段非法不改变路径判定', () async {
    synthesizeReturns(
      '{"audioPath":"/cache/a.mp3","fromCache":"true","contentType":42}',
    );
    final audio =
        await service.synthesize(engineId: 1, text: '正文。') as HttpTtsAudio;
    expect(audio.audioPath, '/cache/a.mp3');
    expect(audio.fromCache, isNull);
    expect(audio.contentType, isNull);
  });

  for (final raw in ['{}', '{"audioPath":null}', '{"audioPath":"  "}']) {
    test('无路径结果返回 emptyResult：$raw', () async {
      synthesizeReturns(raw);
      final result =
          await service.synthesize(engineId: 1, text: '正文。') as HttpTtsNoAudio;
      expect(result.reason, HttpTtsNoAudioReason.emptyResult);
      expect(result.synthesisError, isNull);
    });
  }

  test('合成管线异常时捕获并返回 synthesisFailed 与错误原因', () async {
    final failure = StateError('Rust 数据库查询失败');
    when(
      () => bridge.crateFfiFfiTtsSpeak(
        request: any(named: 'request'),
        engineId: any(named: 'engineId'),
        text: any(named: 'text'),
        toneId: any(named: 'toneId'),
        speakerName: any(named: 'speakerName'),
        emotionTag: any(named: 'emotionTag'),
      ),
    ).thenThrow(failure);

    final result =
        await service.synthesize(engineId: 1, text: '正文。') as HttpTtsNoAudio;

    expect(result.reason, HttpTtsNoAudioReason.synthesisFailed);
    expect(result.synthesisError, same(failure));
  });

  for (final raw in ['not json', '[]', '{"audioPath":42}']) {
    test('合成响应解码失败返回 synthesisFailed：$raw', () async {
      synthesizeReturns(raw);
      final result =
          await service.synthesize(engineId: 1, text: '正文。') as HttpTtsNoAudio;
      expect(result.reason, HttpTtsNoAudioReason.synthesisFailed);
      expect(result.synthesisError, isNotNull);
    });
  }
}
