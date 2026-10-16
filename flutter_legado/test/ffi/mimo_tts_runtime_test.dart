library;

/// 当前 DLL、本机 SSE 与安全存储替身；不调用真实 MiMo 账号。— Codex + Bridge
@Timeout(Duration(minutes: 3))
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/data/repositories/rust_cloud_tts_repository.dart';
import 'package:flutter_legado/src/data/services/rust_cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_settings.dart';
import 'package:flutter_legado/src/platform/tts/cloud_tts_credential_store.dart';

void main() {
  if (!Platform.isWindows) {
    test('MiMo 真实 FFI 需要 Windows DLL', () {}, skip: true);
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  test('MiMo 元数据到 FRB/鉴权/SSE/WAV/缓存，坏流不落盘', () async {
    final dir = Directory(
      '.dart_tool/mimo-tts-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    const runtime = NativeRustRuntime();
    await runtime.initialize();
    await bridge.dbOpen(path: '${dir.absolute.path}/db.sqlite');
    await runtime.setTtsCacheDirectory('${dir.absolute.path}/audio');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var count = 0, bad = false;
    final requests = <Map<String, dynamic>>[];
    server.listen((request) async {
      count++;
      expect(request.uri.path, '/v1/chat/completions');
      expect(request.headers.value('api-key'), 'mimo-fixture-key');
      expect(request.headers.value('authorization'), isNull);
      expect(request.headers.value('cookie'), isNull);
      requests.add(
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      );
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      request.response.write(
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {
                'audio': {
                  'data': base64Encode([1, 2]),
                },
              },
            },
          ],
        })}\n\n',
      );
      request.response.write(
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {
                'audio': {
                  'data': base64Encode([3, 4]),
                },
              },
            },
          ],
        })}\n\n',
      );
      if (bad) {
        request.response.write(
          'data: ${jsonEncode({
            'error': {'message': 'fixture-private'},
          })}\n\n',
        );
      } else {
        request.response.write('data: [DONE]\n\n');
      }
      await request.response.close();
    });
    const repo = RustCloudTtsRepository();
    final credentials = MemoryCloudTtsCredentialStore();
    final settings = CloudTtsSettings(repo, credentials);
    final engine = CloudTtsEngine(
      id: 'mimo-fixture',
      name: 'MiMo fixture',
      provider: 'mimo',
      model: 'mimo-v2.5-tts',
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      optionsJson: jsonEncode({
        'voiceId': '冰糖',
        'style': '平静',
        'instructions': '用中文朗读',
        'format': 'wav',
      }),
    );
    await settings.save(engine, apiKey: 'mimo-fixture-key');
    expect(await repo.voices('mimo'), [
      'mimo_default',
      '冰糖',
      '茉莉',
      '苏打',
      '白桦',
      'Mia',
      'Chloe',
      'Milo',
      'Dean',
    ]);
    final synth = RustCloudTtsSynthesizer(repo, credentials);
    final result = await synth.synthesize(
      engineId: engine.id,
      text: '中文😀',
    ) as HttpTtsAudio;
    final bytes = await File(result.audioPath).readAsBytes();
    expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
    expect(bytes.sublist(44), [1, 2, 3, 4]);
    expect(result.contentType, 'audio/wav');
    expect(requests.single, {
      'model': 'mimo-v2.5-tts',
      'messages': [
        {'role': 'user', 'content': '用中文朗读'},
        {'role': 'assistant', 'content': '(平静)中文😀'},
      ],
      'audio': {'format': 'pcm16', 'voice': '冰糖'},
      'stream': true,
    });
    final hit = await synth.synthesize(
      engineId: engine.id,
      text: '中文😀',
    ) as HttpTtsAudio;
    expect(hit.fromCache, true);
    expect(count, 1);
    bad = true;
    await expectLater(
      synth.synthesize(engineId: engine.id, text: '坏流'),
      throwsA(predicate((e) => !e.toString().contains('fixture-private'))),
    );
    expect(
      Directory('${dir.absolute.path}/audio')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.wav')),
      hasLength(1),
    );
    await result.lease?.release();
    await hit.lease?.release();
    await settings.delete(engine);
  });
}
