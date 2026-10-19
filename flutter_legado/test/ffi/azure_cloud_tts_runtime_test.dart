@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

/// 真实数据库/FRB/本机 Azure 协议端点，不调用云账号。— Codex + Bridge
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/repositories/rust_cloud_tts_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/data/services/rust_cloud_tts_voice_catalog.dart';
import 'package:flutter_legado/src/data/services/rust_cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_settings.dart';
import 'package:flutter_legado/src/platform/tts/cloud_tts_credential_store.dart';

import '../helpers/native_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Azure 真实目录、SSML、格式缓存、音色保存、取消与失败重试', () async {
    final directory = Directory(
      '.dart_tool/azure-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final runtime = nativeTestRuntime();
    await runtime.initialize();
    await runtime.openDatabase('${directory.absolute.path}/db.sqlite');
    await runtime.setTtsCacheDirectory('${directory.absolute.path}/audio');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var gets = 0, posts = 0, badAudio = false, blockCatalog = false;
    final entered = Completer<void>(), release = Completer<void>();
    final outputs = <String>[];
    final ssml = <String>[];
    server.listen((request) async {
      expect(
        request.headers.value('ocp-apim-subscription-key'),
        'fixture-private',
      );
      expect(request.headers.value('authorization'), isNull);
      expect(request.headers.value('cookie'), isNull);
      if (request.method == 'GET') {
        gets++;
        expect(request.uri.path, '/tts/cognitiveservices/voices/list');
        if (blockCatalog) {
          entered.complete();
          await release.future;
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode([
            {
              'ShortName': 'zh-CN-XiaoxiaoNeural',
              'LocalName': '晓晓',
              'Locale': 'zh-CN',
              'Gender': 'Female',
              'StyleList': ['cheerful'],
              'RolePlayList': ['Girl'],
              'SampleRateHertz': '24000',
            },
          ]),
        );
      } else {
        posts++;
        expect(request.uri.path, '/tts/cognitiveservices/v1');
        expect(request.headers.contentType!.mimeType, 'application/ssml+xml');
        final text = await utf8.decoder.bind(request).join();
        ssml.add(text);
        expect(text, contains('甲&lt;&amp;😀'));
        expect(text, contains('style="cheerful" role="Girl"'));
        final output = request.headers.value('x-microsoft-outputformat')!;
        outputs.add(output);
        if (badAudio) {
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"error":"fixture"}');
        } else {
          request.response.headers.contentType = ContentType(
            'audio',
            output.startsWith('riff')
                ? 'wav'
                : output.startsWith('ogg')
                ? 'ogg'
                : 'mpeg',
          );
          request.response.add(
            output.startsWith('riff')
                ? _wave()
                : utf8.encode(
                    output.startsWith('ogg') ? 'OggSfixture' : 'ID3fixture',
                  ),
          );
        }
      }
      try {
        await request.response.close();
      } on SocketException {
        /* 取消后客户端可以先关闭。 */
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
      id: 'azure',
      name: 'Azure fixture',
      provider: 'azure_speech',
      model: '',
      baseUrl: 'http://127.0.0.1:${server.port}/tts',
    );
    await settings.save(engine, apiKey: 'fixture-private');
    final savedEngine = (await repo.list()).single;
    expect(
      jsonEncode(savedEngine.toJson()),
      isNot(contains('fixture-private')),
    );
    final catalog = RustCloudTtsVoiceCatalog(repo, credentials);
    final candidates = await catalog.discover(engine, HttpTtsCancellation());
    expect(gets, 1);
    expect(candidates.single.name, '晓晓');
    expect(candidates.single.locale, 'zh-CN');
    expect(candidates.single.roles, ['Girl']);
    expect(candidates.single.styles, ['cheerful']);
    expect(candidates.single.sampleRate, 24000);
    final id = readAloudVoiceId('cloud_tts', 'azure', candidates.single.id);
    const voices = RustReadAloudVoiceRepository();
    const options = {
      'locale': 'zh-CN',
      'style': 'cheerful',
      'role': 'Girl',
      'speed': 1.25,
      'pitch': 1.1,
      'volume': 0.8,
      'format': 'wav',
    };
    await voices.save(
      ReadAloudVoice(
        id: id,
        engineType: 'cloud_tts',
        engineId: 'azure',
        speakerId: candidates.single.id,
        displayName: '晓晓预设',
        traitsJson: jsonEncode(options),
        managedBy: 'user',
      ),
    );
    final synth = RustCloudTtsSynthesizer(repo, credentials);
    final first = await synth.synthesize(
      engineId: 'azure',
      text: '甲<&😀',
      voiceId: id,
    ) as HttpTtsAudio;
    final cached = await synth.synthesize(
      engineId: 'azure',
      text: '甲<&😀',
      voiceOptions: {...options, 'voiceId': candidates.single.id},
    ) as HttpTtsAudio;
    expect(first.fromCache, false);
    expect(cached.fromCache, true);
    expect(posts, 1);
    expect(await File(first.audioPath).readAsBytes(), _wave());
    await first.lease!.release();
    await cached.lease!.release();
    for (final format in ['mp3', 'ogg']) {
      final audio = await synth.synthesize(
        engineId: 'azure',
        text: '甲<&😀',
        voiceOptions: {
          ...options,
          'voiceId': candidates.single.id,
          'format': format,
        },
      ) as HttpTtsAudio;
      expect(audio.fromCache, false);
      expect(audio.audioPath, endsWith('.$format'));
      await audio.lease!.release();
    }
    expect(ssml.toSet(), hasLength(1));
    expect(outputs.toSet(), hasLength(3));
    badAudio = true;
    await expectLater(
      synth.synthesize(engineId: 'azure', text: '甲<&😀 失败', voiceId: id),
      throwsA(anything),
    );
    badAudio = false;
    final retry = await synth.synthesize(
      engineId: 'azure',
      text: '甲<&😀 失败',
      voiceId: id,
    ) as HttpTtsAudio;
    expect(retry.fromCache, false);
    expect(posts, 5);
    await retry.lease!.release();
    blockCatalog = true;
    final cancel = HttpTtsCancellation();
    final pending = catalog.discover(engine, cancel);
    final failed = expectLater(pending, throwsA(anything));
    await entered.future.timeout(const Duration(seconds: 5));
    cancel.cancel();
    await failed.timeout(const Duration(seconds: 5));
    release.complete();
    expect(gets, 2);
    expect((await voices.list()).single.id, id);
  });
}

Uint8List _wave() {
  final wave = Uint8List(48);
  final data = ByteData.sublistView(wave);
  for (final entry in {0: 'RIFF', 8: 'WAVEfmt ', 36: 'data'}.entries) {
    wave.setRange(
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
  return wave;
}
