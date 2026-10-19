library;

/// 真实 FRB、SQLite 与本机 SSE/音频下载，不调用百炼账号。— Codex + Bridge
@Timeout(Duration(minutes: 3))
import '../helpers/native_ffi.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/repositories/rust_cloud_tts_repository.dart';
import 'package:flutter_legado/src/data/services/rust_cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_settings.dart';
import 'package:flutter_legado/src/platform/tts/cloud_tts_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('百炼元数据/目录、SSE PCM 与无鉴权下载、缓存复用经真实 FFI 接通', () async {
    final directory = Directory(
      '.dart_tool/alibaba-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final runtime = nativeTestRuntime();
    await runtime.initialize();
    await runtime.openDatabase('${directory.absolute.path}/db.sqlite');
    await runtime.setTtsCacheDirectory('${directory.absolute.path}/audio');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final bodies = <Map<String, dynamic>>[];
    var downloads = 0;
    final wave = _wave();
    server.listen((request) async {
      if (request.method == 'GET') {
        downloads++;
        expect(request.uri.queryParameters['Signature'], 'fixture');
        expect(request.headers.value('authorization'), isNull);
        expect(request.headers.value('x-dashscope-sse'), isNull);
        request.response.headers.contentType = ContentType('audio', 'wav');
        request.response.add(wave);
      } else {
        expect(
          request.uri.path,
          '/api/v1/services/aigc/multimodal-generation/generation',
        );
        expect(
          request.headers.value('authorization'),
          'Bearer fixture-private',
        );
        expect(request.headers.value('x-dashscope-sse'), 'enable');
        final body = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        bodies.add(body);
        final input = body['input'] as Map<String, dynamic>;
        expect(input['language_type'], 'Auto');
        expect(input['voice'], 'Serena');
        expect(input['instructions'], '平静；用中文朗读');
        expect(input.containsKey('speed'), false);
        final audio = input['text'] == 'PCM 中文😀'
            ? {'data': base64Encode(wave.sublist(44))}
            : {
                'url':
                    'http://127.0.0.1:${server.port}/complete.wav?Signature=fixture',
              };
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: ${jsonEncode({
            'output': {'finish_reason': 'stop', 'audio': audio},
          })}\n\n',
        );
      }
      await request.response.close();
    });
    const repo = RustCloudTtsRepository();
    final credentials = MemoryCloudTtsCredentialStore();
    final settings = CloudTtsSettings(
      repo,
      credentials,
      newId: () => 'fixture',
    );
    final engine = CloudTtsEngine(
      id: 'alibaba',
      name: '百炼测试',
      provider: 'alibaba_cloud',
      model: 'qwen3-tts-instruct-flash',
      baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
      optionsJson: '{"voiceId":"Serena","style":"平静","instructions":"用中文朗读","format":"wav"}',
    );
    await settings.save(engine, apiKey: 'fixture-private');
    expect((await repo.list()).single.provider, 'alibaba_cloud');
    expect(await repo.voices('alibaba_cloud'), [
      'Cherry',
      'Serena',
      'Ethan',
      'Chelsie',
    ]);
    final synth = RustCloudTtsSynthesizer(repo, credentials);
    for (final text in ['PCM 中文😀', '下载 中文😀']) {
      final audio = await synth.synthesize(
        engineId: engine.id,
        text: text,
      ) as HttpTtsAudio;
      expect(await File(audio.audioPath).readAsBytes(), wave);
      expect(audio.fromCache, false);
      final cached = await synth.synthesize(
        engineId: engine.id,
        text: text,
      ) as HttpTtsAudio;
      expect(cached.fromCache, true);
      await audio.lease!.release();
      await cached.lease!.release();
    }
    expect(bodies, hasLength(2));
    expect(downloads, 1);
  });
}

Uint8List _wave() {
  final wave = Uint8List(48);
  final data = ByteData.sublistView(wave);
  void label(int offset, String value) =>
      wave.setRange(offset, offset + value.length, value.codeUnits);
  label(0, 'RIFF');
  data.setUint32(4, 40, Endian.little);
  label(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 24000, Endian.little);
  data.setUint32(28, 48000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  label(36, 'data');
  data.setUint32(40, 4, Endian.little);
  return wave;
}
