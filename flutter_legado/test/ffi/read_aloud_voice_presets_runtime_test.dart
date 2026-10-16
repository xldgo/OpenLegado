library;

/// 真实音色 CRUD 与云端请求，不使用真实账号。— Codex + Bridge
@Timeout(Duration(minutes: 3))
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/data/repositories/rust_read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_cloud_tts_repository.dart';
import 'package:flutter_legado/src/data/services/rust_cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_settings.dart';
import 'package:flutter_legado/src/platform/tts/cloud_tts_credential_store.dart';

void main() {
  if (!Platform.isWindows) {
    test('需要 Windows 原生 DLL', () {}, skip: true);
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  test('同引擎多音色真实持久化与缓存隔离，试听草稿不写入，错绑和私有字段被拒绝', () async {
    final dir = Directory(
      '.dart_tool/tts-voice-presets-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    const runtime = NativeRustRuntime();
    await runtime.initialize();
    await runtime.openDatabase('${dir.absolute.path}/db.sqlite');
    await runtime.setTtsCacheDirectory('${dir.absolute.path}/audio');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <Map<String, dynamic>>[];
    server.listen((r) async {
      requests.add(
        jsonDecode(await utf8.decoder.bind(r).join()) as Map<String, dynamic>,
      );
      expect(r.headers.value('authorization'), 'Bearer fixture-key');
      r.response.headers.contentType = ContentType('audio', 'wav');
      r.response.add(_wave());
      await r.response.close();
    });
    const engines = RustCloudTtsRepository();
    const voices = RustReadAloudVoiceRepository();
    final credentials = MemoryCloudTtsCredentialStore();
    final settings = CloudTtsSettings(engines, credentials);
    final engine = CloudTtsEngine(
      id: 'engine',
      name: '引擎',
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
    );
    await settings.save(engine, apiKey: 'fixture-key');
    ReadAloudVoice voice(String speaker) => ReadAloudVoice(
      id: readAloudVoiceId('cloud_tts', 'engine', speaker),
      engineType: 'cloud_tts',
      engineId: 'engine',
      speakerId: speaker,
      displayName: '音色 $speaker',
      traitsJson: jsonEncode({
        'format': 'wav',
        'speed': 1.1,
        'instructions': '$speaker 指令',
      }),
      managedBy: 'user',
    );
    for (final speaker in ['alloy', 'nova']) {
      await voices.save(voice(speaker));
    }
    expect((await voices.list()).length, 2);
    final synth = RustCloudTtsSynthesizer(engines, credentials);
    final paths = <String>[];
    for (final speaker in ['alloy', 'nova']) {
      final audio = await synth.synthesize(
        engineId: 'engine',
        text: '同一文本',
        voiceId: voice(speaker).id,
      ) as HttpTtsAudio;
      paths.add(audio.audioPath);
      expect(audio.fromCache, false);
      await audio.lease!.release();
      final cached = await synth.synthesize(
        engineId: 'engine',
        text: '同一文本',
        voiceId: voice(speaker).id,
      ) as HttpTtsAudio;
      expect(cached.fromCache, true);
      await cached.lease!.release();
    }
    expect(paths[0], isNot(paths[1]));
    expect(requests.map((r) => r['voice']), ['alloy', 'nova']);
    expect(requests.map((r) => r['instructions']), ['alloy 指令', 'nova 指令']);
    final preview = await synth.synthesize(
      engineId: 'engine',
      text: '草稿',
      voiceOptions: {'voiceId': 'echo', 'format': 'wav', 'instructions': '不保存'},
    ) as HttpTtsAudio;
    await preview.lease!.release();
    expect(requests.last['voice'], 'echo');
    expect((await voices.list()).length, 2);
    expect((await engines.list()).single.optionsJson, '{}');
    await expectLater(
      synth.synthesize(engineId: 'engine', text: '拒绝', voiceId: 'missing'),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      synth.synthesize(
        engineId: 'engine',
        text: '拒绝',
        voiceOptions: {'voiceId': 'alloy', 'apiKey': 'forbidden'},
      ),
      throwsA(isA<Exception>()),
    );
    expect(requests.length, 3);
    await voices.save(voice('nova').copyWith(displayName: '改名'));
    expect(
      (await voices.list())
          .firstWhere((v) => v.speakerId == 'nova')
          .displayName,
      '改名',
    );
    await voices.delete(voice('alloy').id);
    expect((await voices.list()).single.speakerId, 'nova');
    await engines.delete('engine');
    expect(await voices.list(), isEmpty);
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
