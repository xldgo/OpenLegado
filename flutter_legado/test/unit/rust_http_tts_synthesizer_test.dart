import 'dart:async';
import 'dart:convert';

import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/services/rust_http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  const service = RustHttpTtsSynthesizer();
  late _Bridge bridge;
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  void synthesizeReturns(String raw) {
    when(
      () => bridge.crateFfiFfiTtsSpeak(
        text: '正文。',
        engineUrl: 'http://tts/{{text}}',
        speed: 1,
      ),
    ).thenAnswer((_) async => raw);
  }

  test('模板与正文原样交给 Rust，路径和缓存信息返回，不自行缓存', () async {
    const template = 'http://tts/{{text}}, {"method":"POST"}';
    when(
      () => bridge.crateFfiFfiTtsSpeak(
        text: '正文 😀',
        engineUrl: template,
        speed: 1.75,
      ),
    ).thenAnswer(
      (_) async => '{"audioPath":"  /cache/a.wav  ","fromCache":true,"contentType":"audio/wav"}',
    );
    for (var i = 0; i < 2; i++) {
      final audio = await service.synthesize(
        text: '正文 😀',
        engineUrl: template,
        speed: 1.75,
        pitch: 0.8,
        volume: 0.4,
        voiceName: '中文',
      ) as HttpTtsAudio;
      expect(audio.audioPath, '/cache/a.wav');
      expect(audio.fromCache, isTrue);
      expect(audio.contentType, 'audio/wav');
    }
    verify(
      () => bridge.crateFfiFfiTtsSpeak(
        text: '正文 😀',
        engineUrl: template,
        speed: 1.75,
      ),
    ).called(2);
    verifyNoMoreInteractions(bridge);
  });

  test('诊断字段非法不改变旧路径判定', () async {
    synthesizeReturns(
      '{"audioPath":"/cache/a.mp3","fromCache":"true","contentType":42}',
    );
    final audio = await service.synthesize(
      text: '正文。',
      engineUrl: 'http://tts/{{text}}',
    ) as HttpTtsAudio;
    expect(audio.audioPath, '/cache/a.mp3');
    expect(audio.fromCache, isNull);
    expect(audio.contentType, isNull);
    verifyNever(() => bridge.crateFfiFfiHttpGet(url: any(named: 'url')));
  });

  for (final raw in ['{}', '{"audioPath":null}', '{"audioPath":"  "}']) {
    test('无路径结果不探活：$raw', () async {
      synthesizeReturns(raw);
      final result = await service.synthesize(
        text: '正文。',
        engineUrl: 'http://tts/{{text}}',
      ) as HttpTtsNoAudio;
      expect(result.reason, HttpTtsNoAudioReason.emptyResult);
      expect(result.synthesisError, isNull);
      verifyNever(() => bridge.crateFfiFfiHttpGet(url: any(named: 'url')));
    });
  }

  test('合成失败探活只判断原状态码，成功仍明确没有音频', () async {
    final failure = StateError('缓存不可用');
    const text = '甲 😀/乙';
    const voice = '中文 女声';
    const template =
        'http://tts?a={{speakText}}&b={{text}}&s={{speakSpeed}}&s2={{speed}}&p={{pitch}}&v={{volume}}&voice={{voice}}';
    when(
      () => bridge.crateFfiFfiTtsSpeak(
        text: text,
        engineUrl: template,
        speed: 1.5,
      ),
    ).thenThrow(failure);
    final url =
        'http://tts?a=${Uri.encodeComponent(text)}&b=${Uri.encodeComponent(text)}&s=1.5&s2=1.5&p=0.8&v=0.4&voice=${Uri.encodeComponent(voice)}';
    when(() => bridge.crateFfiFfiHttpGet(url: url))
        .thenAnswer((_) async => '{"status":204,"body":"没有音频"}');
    final result = await service.synthesize(
      text: text,
      engineUrl: template,
      speed: 1.5,
      pitch: 0.8,
      volume: 0.4,
      voiceName: voice,
    ) as HttpTtsNoAudio;
    expect(result.reason, HttpTtsNoAudioReason.probeOnly);
    expect(result.synthesisError, same(failure));
    verify(
      () => bridge.crateFfiFfiTtsSpeak(
        text: text,
        engineUrl: template,
        speed: 1.5,
      ),
    ).called(1);
    verify(() => bridge.crateFfiFfiHttpGet(url: url)).called(1);
    verifyNoMoreInteractions(bridge);
  });

  for (final raw in ['not json', '[]', '{"audioPath":42}']) {
    test('合成响应解码失败仍沿用探活：$raw', () async {
      synthesizeReturns(raw);
      when(
        () => bridge.crateFfiFfiHttpGet(
          url: 'http://tts/${Uri.encodeComponent('正文。')}',
        ),
      ).thenAnswer((_) async => '{"status":200}');
      final result = await service.synthesize(
        text: '正文。',
        engineUrl: 'http://tts/{{text}}',
      ) as HttpTtsNoAudio;
      expect(result.reason, HttpTtsNoAudioReason.probeOnly);
      expect(result.synthesisError, isNotNull);
    });
  }

  for (final status in [0, 199, 300, 503]) {
    test('探活状态 $status 向播放会话抛错', () async {
      synthesizeReturns('bad');
      when(() => bridge.crateFfiFfiHttpGet(url: any(named: 'url')))
          .thenAnswer((_) async => jsonEncode({'status': status}));
      await expectLater(
        service.synthesize(text: '正文。', engineUrl: 'http://tts/{{text}}'),
        throwsA(
          isA<StateError>().having((e) => e.message, '状态', 'HTTP $status'),
        ),
      );
    });
  }

  test('探活请求异常原样传出', () async {
    final failure = StateError('网络中断');
    synthesizeReturns('bad');
    when(() => bridge.crateFfiFfiHttpGet(url: any(named: 'url')))
        .thenThrow(failure);
    await expectLater(
      service.synthesize(text: '正文。', engineUrl: 'http://tts/{{text}}'),
      throwsA(same(failure)),
    );
  });

  test('探活响应类型错误不能误报成功', () async {
    synthesizeReturns('bad');
    when(() => bridge.crateFfiFfiHttpGet(url: any(named: 'url')))
        .thenAnswer((_) async => '{"status":"200"}');
    await expectLater(
      service.synthesize(text: '正文。', engineUrl: 'http://tts/{{text}}'),
      throwsA(isA<TypeError>()),
    );
  });

  testWidgets('探活保留 30 秒超时，不无限等待', (tester) async {
    synthesizeReturns('bad');
    final request = Completer<String>();
    when(() => bridge.crateFfiFfiHttpGet(url: any(named: 'url')))
        .thenAnswer((_) => request.future);
    final result = expectLater(
      service.synthesize(text: '正文。', engineUrl: 'http://tts/{{text}}'),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    await result;
    request.complete('{"status":200}');
    await tester.pump();
  });
}
