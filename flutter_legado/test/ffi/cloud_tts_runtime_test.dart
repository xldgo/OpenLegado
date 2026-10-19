@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

/// 真实 FRB/SQLite/HTTP；凭据存储使用内存 fixture，不证明平台密钥库有效。— Codex + Bridge
import '../helpers/native_ffi.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' as controls;
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/bridge/media_dto.dart';
import 'package:flutter_legado/src/data/repositories/rust_cloud_tts_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_tts_cache_repository.dart';
import 'package:flutter_legado/src/data/services/rust_cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_settings.dart';
import 'package:flutter_legado/src/platform/tts/cloud_tts_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('云端元数据/凭据分离、合成参数/缓存/租约、过期引用拒绝和禁用', () async {
    final directory = Directory(
      '.dart_tool/cloud-tts-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final runtime = nativeTestRuntime();
    await runtime.initialize();
    await bridge.dbOpen(path: '${directory.absolute.path}/db.sqlite');
    await runtime.setTtsCacheDirectory('${directory.absolute.path}/audio');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <Map<String, dynamic>>[];
    final headers = <String?>[];
    final wave = _wave();
    server.listen((request) async {
      headers.add(request.headers.value('authorization'));
      requests.add(
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      );
      request.response.headers.contentType = ContentType('audio', 'wav');
      request.response.add(wave);
      await request.response.close();
    });
    const repo = RustCloudTtsRepository();
    final credentials = MemoryCloudTtsCredentialStore();
    var next = 0;
    final settings = CloudTtsSettings(
      repo,
      credentials,
      newId: () => 'fixture${next++}',
    );
    final service = RustCloudTtsSynthesizer(repo, credentials);
    final engine = CloudTtsEngine(
      id: 'cloudfixture',
      name: '真实云端',
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      optionsJson: '{"voiceId":"coral","format":"wav","speed":1.25,"instructions":"中文朗读"}',
    );
    await settings.save(engine, apiKey: 'local-fixture-secret');
    var saved = (await repo.list()).single;
    expect(saved.id, engine.id);
    expect(jsonEncode(saved.toJson()), isNot(contains('local-fixture-secret')));
    expect(await repo.voices('openai_speech'), contains('coral'));
    final first = await service.synthesize(
      engineId: engine.id,
      text: '真实中文 😀',
    ) as HttpTtsAudio;
    expect(requests.single['input'], '真实中文 😀');
    expect(requests.single['voice'], 'coral');
    expect(requests.single['speed'], 1.25);
    expect(headers.single, 'Bearer local-fixture-secret');
    expect(await File(first.audioPath).readAsBytes(), wave);
    final cached = await service.synthesize(
      engineId: engine.id,
      text: '真实中文 😀',
    ) as HttpTtsAudio;
    expect(cached.fromCache, true);
    expect(requests, hasLength(1));
    const files = RustTtsCacheRepository();
    expect((await files.clear()).skippedFiles, 1);
    final oldKey = saved.credentialKey;
    await settings.save(engine, apiKey: 'new-local-secret');
    saved = (await repo.list()).single;
    expect(saved.credentialKey, isNot(oldKey));
    expect(await credentials.read(oldKey), isNull);
    final request = controls.ttsRequestNew();
    try {
      await expectLater(
        bridge.cloudTtsSpeak(
          engineId: engine.id,
          apiKey: 'local-fixture-secret',
          input: CloudSpeechInputDto(
            text: '旧凭据',
            credentialKey: oldKey,
            voiceId: null,
            voiceOptions: null,
          ),
          request: request,
        ),
        throwsA(anything),
      );
    } finally {
      request.dispose();
    }
    expect(requests, hasLength(1));
    final disabled = CloudTtsEngine.fromJson({
      ...saved.toJson(),
      'enabled': false,
    });
    await settings.save(disabled);
    await expectLater(
      service.synthesize(engineId: engine.id, text: '禁止朗读'),
      throwsStateError,
    );
    expect(requests, hasLength(1));
    await first.lease!.release();
    await cached.lease!.release();
    await settings.delete(disabled);
    expect(await repo.list(), isEmpty);
    expect(await credentials.read(saved.credentialKey), isNull);
    for (var i = 0; i < 50; i++) {
      if ((await files.list()).every((e) => !e.protected)) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect((await files.clear()).removedFiles, 1);
  });
}

Uint8List _wave() {
  final pcm = Uint8List(4);
  final bytes = Uint8List(48);
  final data = ByteData.sublistView(bytes);
  void label(int offset, String s) =>
      bytes.setRange(offset, offset + s.length, s.codeUnits);
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
  bytes.setRange(44, 48, pcm);
  return bytes;
}
