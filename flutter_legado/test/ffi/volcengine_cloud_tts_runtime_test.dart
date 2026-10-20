@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

/// 本机 HTTP 复核真实 FRB、App ID/Token、JSON 音频与缓存，不调用云账号。— Codex + Bridge
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  test('火山真实请求、内置音色、JSON 音频格式、缓存、错误重试与取消贯通', () async {
    final directory = Directory(
      '.dart_tool/volc-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final runtime = nativeTestRuntime();
    await runtime.initialize();
    await runtime.openDatabase('${directory.absolute.path}/db.sqlite');
    await runtime.setTtsCacheDirectory('${directory.absolute.path}/audio');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var calls = 0, badCode = false, badMime = false, blocking = false;
    final ids = <String>{}, formats = <String>[];
    final entered = Completer<void>(), release = Completer<void>();
    server.listen((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.uri.path, '/tts');
      expect(request.headers.value('authorization'), 'Bearer;token-private');
      expect(request.headers.value('cookie'), isNull);
      expect(request.headers.contentType!.mimeType, 'application/json');
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['app'], {
        'appid': 'app-fixture',
        'token': 'token-private',
        'cluster': 'volcano_tts',
      });
      expect(body['user'], {'uid': 'legado'});
      final input = body['request'] as Map;
      expect(input['operation'], 'query');
      expect(input['text_type'], 'plain');
      expect(
        utf8.encode(input['text'] as String).length,
        lessThanOrEqualTo(1024),
      );
      final id = input['reqid'] as String;
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(ids.add(id), isTrue);
      final audio = body['audio'] as Map;
      final format = audio['encoding'] as String;
      expect(audio['voice_type'], 'BV001_streaming');
      expect(audio['emotion'], 'happy');
      expect(audio['speed_ratio'], 0.2);
      expect(audio['pitch_ratio'], 0.1);
      expect(audio['volume_ratio'], 3.0);
      formats.add(format);
      if (blocking) {
        entered.complete();
        await release.future;
      }
      request.response.headers.contentType = badMime
          ? ContentType('audio', 'mpeg')
          : ContentType.json;
      final bytes = switch (format) {
        'pcm' => [0, 1, 0, 2],
        'wav' => _wave(),
        'mp3' => utf8.encode('ID3fixture'),
        'ogg_opus' => utf8.encode('OggSfixture'),
        _ => throw StateError('格式错误'),
      };
      request.response.write(
        jsonEncode({
          'code': badCode ? 3001 : 3000,
          'sequence': -1,
          'reqid': id,
          'message': badCode ? 'token-private' : 'ok',
          'data': base64Encode(bytes),
        }),
      );
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
      id: 'volc',
      name: '火山 fixture',
      provider: 'volcengine',
      appId: 'app-fixture',
      model: 'volcano_tts',
      baseUrl: 'http://127.0.0.1:${server.port}/tts',
    );
    await settings.save(engine, apiKey: 'token-private');
    final saved = (await repo.list()).single;
    expect(saved.appId, 'app-fixture');
    expect(jsonEncode(saved.toJson()), isNot(contains('token-private')));
    expect(await repo.voices('volcengine'), [
      'BV001_streaming',
      'BV002_streaming',
      'BV700_streaming',
      'BV701_streaming',
    ]);
    final candidates = await RustCloudTtsVoiceCatalog(
      repo,
      credentials,
    ).discover(engine, HttpTtsCancellation());
    expect(candidates.map((v) => v.name), ['通用女声', '通用男声', '灿灿', '擎苍']);
    expect(candidates.first.id, 'BV001_streaming');
    const voices = RustReadAloudVoiceRepository();
    final voiceId = readAloudVoiceId('cloud_tts', 'volc', 'BV001_streaming');
    const options = {
      'style': 'happy',
      'speed': 0.2,
      'pitch': 0.1,
      'volume': 3.0,
      'format': 'pcm',
    };
    await voices.save(
      ReadAloudVoice(
        id: voiceId,
        engineType: 'cloud_tts',
        engineId: 'volc',
        speakerId: 'BV001_streaming',
        displayName: '通用女声',
        managedBy: 'user',
        traitsJson: jsonEncode(options),
      ),
    );
    final synth = RustCloudTtsSynthesizer(repo, credentials);
    final first = await synth.synthesize(
      engineId: 'volc',
      text: '甲😀',
      voiceId: voiceId,
    ) as HttpTtsAudio;
    final bytes = await File(first.audioPath).readAsBytes();
    expect(
      ByteData.sublistView(Uint8List.fromList(bytes))
          .getUint32(24, Endian.little),
      24000,
    );
    expect(first.contentType, 'audio/wav');
    await first.lease!.release();
    final cached = await synth.synthesize(
      engineId: 'volc',
      text: '甲😀',
      voiceOptions: {...options, 'voiceId': 'BV001_streaming'},
    ) as HttpTtsAudio;
    expect(cached.fromCache, isTrue);
    expect(calls, 1);
    await cached.lease!.release();
    for (final format in ['mp3', 'wav', 'ogg_opus']) {
      final audio = await synth.synthesize(
        engineId: 'volc',
        text: '甲😀',
        voiceOptions: {
          ...options,
          'voiceId': 'BV001_streaming',
          'format': format,
        },
      ) as HttpTtsAudio;
      expect(audio.fromCache, isFalse);
      expect(
        audio.audioPath,
        endsWith(format == 'ogg_opus' ? '.ogg' : '.$format'),
      );
      await audio.lease!.release();
    }
    expect(formats, ['pcm', 'mp3', 'wav', 'ogg_opus']);
    await expectLater(
      synth.synthesize(engineId: 'volc', text: '甲' * 342, voiceId: voiceId),
      throwsA(anything),
    );
    expect(calls, 4);
    badCode = true;
    await expectLater(
      synth.synthesize(engineId: 'volc', text: '失败', voiceId: voiceId),
      throwsA(predicate((e) => !e.toString().contains('token-private'))),
    );
    badCode = false;
    final retry = await synth.synthesize(
      engineId: 'volc',
      text: '失败',
      voiceId: voiceId,
    ) as HttpTtsAudio;
    expect(retry.fromCache, isFalse);
    await retry.lease!.release();
    badMime = true;
    await expectLater(
      synth.synthesize(engineId: 'volc', text: 'MIME错误', voiceId: voiceId),
      throwsA(anything),
    );
    badMime = false;
    blocking = true;
    final cancellation = HttpTtsCancellation();
    final pending = synth.synthesize(
      engineId: 'volc',
      text: '取消',
      voiceId: voiceId,
      cancellation: cancellation,
    );
    await entered.future.timeout(const Duration(seconds: 5));
    cancellation.cancel();
    expect(
      await pending.timeout(const Duration(seconds: 5)),
      isA<HttpTtsCancelled>(),
    );
    release.complete();
    expect(calls, 8);
    expect(ids, hasLength(8));
  });
}

Uint8List _wave() {
  final bytes = Uint8List(48), data = ByteData(48);
  for (final entry in {0: 'RIFF', 8: 'WAVEfmt ', 36: 'data'}.entries) {
    bytes.setRange(
      entry.key,
      entry.key + entry.value.length,
      entry.value.codeUnits,
    );
  }
  data.setUint32(4, 40, Endian.little);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 24000, Endian.little);
  data.setUint32(28, 48000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  data.setUint32(40, 4, Endian.little);
  for (final span in [(4, 8), (16, 36), (40, 44)]) {
    bytes.setRange(
      span.$1,
      span.$2,
      data.buffer.asUint8List().sublist(span.$1, span.$2),
    );
  }
  return bytes;
}
