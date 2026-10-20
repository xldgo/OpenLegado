@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

/// 本机 HTTP 验证真实 FRB、结构化正文、音频、缓存和取消，不调用云账号。— Codex + Bridge
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/repositories/rust_cloud_tts_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/data/services/rust_cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_settings.dart';
import 'package:flutter_legado/src/platform/tts/cloud_tts_credential_store.dart';

import '../helpers/native_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Gemini 真实请求、音色 CRUD、PCM/WAV、缓存、失败重试与取消贯通', () async {
    final directory = Directory(
      '.dart_tool/gemini-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final runtime = nativeTestRuntime();
    await runtime.initialize();
    await runtime.openDatabase('${directory.absolute.path}/db.sqlite');
    await runtime.setTtsCacheDirectory('${directory.absolute.path}/audio');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var calls = 0;
    var mode = 'pcm';
    var transcript = ' 原文😀\n"甲" ';
    final entered = Completer<void>(), release = Completer<void>();
    server.listen((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(
        request.uri.path,
        '/v1beta/models/gemini-3.8-flash-tts:generateContent',
      );
      expect(request.uri.query, isEmpty);
      expect(request.headers.value('x-goog-api-key'), 'private-key');
      expect(request.headers.value('authorization'), isNull);
      expect(request.headers.value('cookie'), isNull);
      expect(request.headers.contentType!.mimeType, 'application/json');
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'text': transcript,
              'speech_metadata': {'style': '平静\n保持停顿'},
            },
          ],
        },
      ]);
      expect(body['generationConfig'], {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {'voice': 'Kore'},
        },
        'responseFormat': {
          'audio': {'mimeType': 'AUDIO_WAV'},
        },
      });
      if (mode == 'cancel') {
        entered.complete();
        await release.future;
      }
      request.response.headers.contentType = mode == 'mime'
          ? ContentType('audio', 'wav')
          : ContentType.json;
      final pcm = [1, 0, 2, 0];
      final bytes = mode == 'wav' ? _wave() : pcm;
      final audio = {
        'inlineData': {
          'mimeType': mode == 'wav'
              ? 'audio/wav'
              : 'audio/L16;codec=pcm;rate=24000',
          'data': base64Encode(bytes),
        },
      };
      request.response.write(
        jsonEncode({
          if (mode == 'blocked') 'promptFeedback': {'blockReason': 'SAFETY'},
          'candidates': [
            {
              'finishReason': mode == 'partial' ? 'MAX_TOKENS' : 'STOP',
              'content': {
                'parts': [audio],
              },
            },
          ],
        }),
      );
      try {
        await request.response.close();
      } on SocketException {
        /* 取消可先关闭连接。 */
      } on HttpException {
        /* 同上。 */
      }
    });
    const repo = RustCloudTtsRepository();
    final credentials = MemoryCloudTtsCredentialStore();
    final settings = CloudTtsSettings(
      repo,
      credentials,
      newId: () => 'fixture',
    );
    final engine = CloudTtsEngine(
      id: 'gemini',
      name: 'Gemini',
      provider: 'gemini_tts',
      model: 'models/gemini-3.8-flash-tts',
      baseUrl: 'http://127.0.0.1:${server.port}/v1beta/openai/',
    );
    await settings.save(engine, apiKey: 'private-key');
    expect((await repo.list()).single.provider, 'gemini_tts');
    expect(
      jsonEncode((await repo.list()).single.toJson()),
      isNot(contains('private-key')),
    );
    final catalog = await repo.voices('gemini_tts');
    expect(catalog, hasLength(30));
    expect(catalog.first, 'Kore');
    expect(catalog.last, 'Zephyr');
    const voices = RustReadAloudVoiceRepository();
    final id = readAloudVoiceId('cloud_tts', 'gemini', 'Kore');
    const options = {'style': '平静', 'instructions': '保持停顿', 'format': 'wav'};
    await voices.save(
      ReadAloudVoice(
        id: id,
        engineType: 'cloud_tts',
        engineId: 'gemini',
        speakerId: 'Kore',
        displayName: '自选音色',
        managedBy: 'user',
        traitsJson: jsonEncode(options),
      ),
    );
    expect((await voices.list()).single.speakerId, 'Kore');
    final synth = RustCloudTtsSynthesizer(repo, credentials);
    Future<HttpTtsSynthesisResult> speak({HttpTtsCancellation? cancellation}) =>
        synth.synthesize(
          engineId: 'gemini',
          text: transcript,
          voiceId: id,
          cancellation: cancellation,
        );
    final first = await speak() as HttpTtsAudio;
    final wave = await File(first.audioPath).readAsBytes();
    expect(wave, _wave());
    expect(first.contentType, 'audio/wav');
    expect(first.fromCache, isFalse);
    await first.lease!.release();
    final cached = await synth.synthesize(
      engineId: 'gemini',
      text: ' 原文😀\n"甲" ',
      voiceOptions: {...options, 'voiceId': 'Kore'},
    ) as HttpTtsAudio;
    expect(cached.fromCache, isTrue);
    expect(calls, 1);
    await cached.lease!.release();
    for (final failure in ['blocked', 'partial', 'mime']) {
      mode = failure;
      transcript = '失败-$failure';
      final before = calls;
      await expectLater(speak(), throwsA(anything));
      expect(calls, before + 1);
    }
    mode = 'wav';
    // 复用最后一次失败的文本；失败不能占用成功缓存。
    final retry = await speak() as HttpTtsAudio;
    expect(retry.fromCache, isFalse);
    expect(await File(retry.audioPath).readAsBytes(), wave);
    await retry.lease!.release();
    mode = 'cancel';
    transcript = '取消';
    final cancel = HttpTtsCancellation();
    final pending = speak(cancellation: cancel);
    await entered.future.timeout(const Duration(seconds: 5));
    cancel.cancel();
    expect(
      await pending.timeout(const Duration(seconds: 5)),
      isA<HttpTtsCancelled>(),
    );
    release.complete();
  });
}

List<int> _wave() {
  const pcm = [1, 0, 2, 0];
  final header = base64Decode(
    'UklGRigAAABXQVZFZm10IBAAAAABAAEAwF0AAIC7AAACABAAZGF0YQQAAAA=',
  );
  return [...header, ...pcm];
}
