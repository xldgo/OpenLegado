@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

/// 本机 SSE 验证真实 FRB 与 V3 协议；不调用云账号或声称设备听感。— Codex + Bridge
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/repositories/rust_cloud_tts_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/data/services/rust_cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/data/services/rust_cloud_tts_voice_catalog.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_settings.dart';
import 'package:flutter_legado/src/platform/tts/cloud_tts_credential_store.dart';

import '../helpers/native_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('V3 API Key、资源、候选、格式、缓存、失败和取消经真实 FFI 贯通', () async {
    final directory = Directory(
      '.dart_tool/volc-v3-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final runtime = nativeTestRuntime();
    await runtime.initialize();
    await runtime.openDatabase('${directory.absolute.path}/db.sqlite');
    await runtime.setTtsCacheDirectory('${directory.absolute.path}/audio');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var calls = 0, mode = 'ok', text = ' 原文😀\n"甲" ';
    final ids = <String>{};
    final entered = Completer<void>(), release = Completer<void>();
    server.listen((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v3/sse');
      expect(request.headers.value('x-api-key'), 'private-key');
      expect(request.headers.value('authorization'), isNull);
      expect(request.headers.value('cookie'), isNull);
      expect(request.headers.value('x-api-resource-id'), 'seed-tts-2.0');
      final id = request.headers.value('x-api-request-id')!;
      expect(ids.add(id), isTrue);
      expect(id, matches(RegExp(r'^[0-9a-f-]{36}$')));
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body.keys, ['req_params']);
      final input = body['req_params'] as Map;
      expect(input['text'], text);
      expect(input['speaker'], 'zh_female_vv_uranus_bigtts');
      final audio = input['audio_params'] as Map;
      expect(audio['speech_rate'], -50);
      expect(audio['loudness_rate'], 100);
      final format = audio['format'] as String;
      expect(audio['sample_rate'], format == 'ogg_opus' ? 48000 : 24000);
      expect(jsonDecode(input['additions'] as String), {
        'context_texts': ['平静\n保持停顿'],
        'post_process': {'pitch': 12},
      });
      if (mode == 'cancel') {
        entered.complete();
        await release.future;
      }
      request.response.headers.contentType = mode == 'mime'
          ? ContentType.json
          : ContentType('text', 'event-stream', charset: 'utf-8');
      final bytes = switch (format) {
        'pcm' => [1, 0, 2, 0],
        'mp3' => utf8.encode('ID3fixture'),
        'ogg_opus' => utf8.encode('OggSfixture'),
        _ => throw StateError('格式错误'),
      };
      request.response.write(
        'event: 352\ndata: ${jsonEncode({'code': 0, 'data': base64Encode(bytes)})}\n\n',
      );
      if (mode != 'partial') {
        request.response.write(
          'event: ${mode == 'error' ? 153 : 152}\ndata: ${jsonEncode({'code': mode == 'error' ? 55000000 : 20000000, 'message': 'private-key'})}\n\n',
        );
      }
      try {
        await request.response.close();
      } on SocketException {
        /* 取消可先断开连接。 */
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
      id: 'v3',
      name: 'V3',
      provider: 'volcengine_v3',
      model: 'seed-tts-2.0',
      baseUrl: 'http://127.0.0.1:${server.port}/v3/sse',
    );
    await settings.save(engine, apiKey: 'private-key');
    expect((await repo.list()).single.appId, isEmpty);
    expect(
      jsonEncode((await repo.list()).single.toJson()),
      isNot(contains('private-key')),
    );
    final catalog = await RustCloudTtsVoiceCatalog(
      repo,
      credentials,
    ).discover(engine, HttpTtsCancellation());
    expect(catalog.map((v) => v.name), [
      'Vivi 2.0',
      '小何 2.0',
      '云舟 2.0',
      '小天 2.0',
    ]);
    expect((await repo.voices('volcengine_v3')).first, catalog.first.id);
    const voices = RustReadAloudVoiceRepository();
    final id = readAloudVoiceId(
      'cloud_tts',
      'v3',
      'zh_female_vv_uranus_bigtts',
    );
    const options = {
      'style': '平静',
      'instructions': '保持停顿',
      'speed': 0.5,
      'pitch': 2.0,
      'volume': 2.0,
      'format': 'wav',
    };
    await voices.save(
      ReadAloudVoice(
        id: id,
        engineType: 'cloud_tts',
        engineId: 'v3',
        speakerId: catalog.first.id,
        displayName: 'Vivi',
        managedBy: 'user',
        traitsJson: jsonEncode(options),
      ),
    );
    final synth = RustCloudTtsSynthesizer(repo, credentials);
    Future<HttpTtsSynthesisResult> speak({HttpTtsCancellation? cancellation}) =>
        synth.synthesize(
          engineId: 'v3',
          text: text,
          voiceId: id,
          cancellation: cancellation,
        );
    final first = await speak() as HttpTtsAudio;
    final wave = await File(first.audioPath).readAsBytes();
    expect(utf8.decode(wave.sublist(0, 4)), 'RIFF');
    expect(wave.sublist(44), [1, 0, 2, 0]);
    expect(first.contentType, 'audio/wav');
    await first.lease!.release();
    final cached = await synth.synthesize(
      engineId: 'v3',
      text: text,
      voiceOptions: {...options, 'voiceId': catalog.first.id},
    ) as HttpTtsAudio;
    expect(cached.fromCache, isTrue);
    expect(calls, 1);
    await cached.lease!.release();
    for (final format in ['pcm', 'mp3', 'ogg_opus']) {
      final result = await synth.synthesize(
        engineId: 'v3',
        text: text,
        voiceOptions: {
          ...options,
          'voiceId': catalog.first.id,
          'format': format,
        },
      ) as HttpTtsAudio;
      expect(result.fromCache, isFalse);
      expect(
        result.audioPath,
        endsWith(switch (format) {
          'pcm' => '.wav',
          'ogg_opus' => '.ogg',
          _ => '.mp3',
        }),
      );
      await result.lease!.release();
    }
    for (final failure in ['partial', 'error', 'mime']) {
      mode = failure;
      text = '失败-$failure';
      await expectLater(
        speak(),
        throwsA(predicate((e) => !e.toString().contains('private-key'))),
      );
    }
    mode = 'ok';
    final retry = await speak() as HttpTtsAudio;
    expect(retry.fromCache, isFalse);
    await retry.lease!.release();
    mode = 'cancel';
    text = '取消';
    final cancel = HttpTtsCancellation();
    final pending = speak(cancellation: cancel);
    await entered.future.timeout(const Duration(seconds: 5));
    cancel.cancel();
    expect(
      await pending.timeout(const Duration(seconds: 5)),
      isA<HttpTtsCancelled>(),
    );
    release.complete();
    expect(calls, 9);
    expect(ids, hasLength(9));
  });
}
