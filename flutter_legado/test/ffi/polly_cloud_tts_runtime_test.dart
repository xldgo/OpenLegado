@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

/// 真实 FRB/数据库/传输；本机端点独立验证每次请求签名。— Codex + Bridge
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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
  test('Polly 分页签名、音色保存、采样率、缓存、错误重试及取消贯通', () async {
    final directory = Directory(
      '.dart_tool/polly-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final runtime = nativeTestRuntime();
    await runtime.initialize();
    await runtime.openDatabase('${directory.absolute.path}/db.sqlite');
    await runtime.setTtsCacheDirectory('${directory.absolute.path}/audio');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var gets = 0,
        posts = 0,
        badAudio = false,
        repeatToken = false,
        blockSecond = false;
    final entered = Completer<void>(), release = Completer<void>();
    final formats = <String>[];
    server.listen((request) async {
      try {
        final body = await request.fold<List<int>>(
          [],
          (bytes, part) => bytes..addAll(part),
        );
        _verifySignature(request, body);
        expect(request.headers.value('cookie'), isNull);
        if (request.method == 'GET') {
          gets++;
          expect(request.uri.path, '/proxy/v1/voices');
          expect(request.uri.queryParameters['Engine'], 'neural');
          expect(
            request.uri.queryParameters['IncludeAdditionalLanguageCodes'],
            'yes',
          );
          final second = request.uri.queryParameters['NextToken'] != null;
          if (second) {
            expect(request.uri.queryParameters['NextToken'], '+/= token');
            if (blockSecond) {
              entered.complete();
              await release.future;
            }
          }
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'Voices': [
                {
                  'Id': 'Zhiyu',
                  'Name': '智语',
                  'LanguageCode': 'cmn-CN',
                  'SupportedEngines': ['standard', 'neural'],
                },
                if (second)
                  {
                    'Id': 'Joanna',
                    'Name': 'Joanna',
                    'LanguageCode': 'en-US',
                    'SupportedEngines': ['neural'],
                  },
              ],
              if (!second || repeatToken) 'NextToken': '+/= token',
            }),
          );
        } else {
          posts++;
          expect(request.uri.path, '/proxy/v1/speech');
          expect(request.headers.contentType!.mimeType, 'application/json');
          final json = jsonDecode(utf8.decode(body)) as Map;
          expect(json['Engine'], 'neural');
          expect(json['TextType'], 'text');
          expect(json['VoiceId'], 'Zhiyu');
          expect(json['LanguageCode'], 'cmn-CN');
          expect(json['Text'], startsWith('甲😀'));
          final format = json['OutputFormat'] as String;
          formats.add(format);
          if (badAudio) {
            request.response.statusCode = 403;
            request.response.headers.contentType = ContentType.json;
            request.response.write('{"message":"fixture error"}');
          } else {
            request.response.headers.contentType = ContentType(
              'audio',
              format == 'pcm'
                  ? 'pcm'
                  : format == 'mp3'
                  ? 'mpeg'
                  : 'ogg',
            );
            request.response.add(
              format == 'pcm'
                  ? [0, 1, 0, 2]
                  : utf8.encode(format == 'mp3' ? 'ID3fixture' : 'OggSfixture'),
            );
          }
        }
        await request.response.close();
      } on SocketException {
        // 取消可先断开连接。
      } on HttpException {
        // 同上。
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
      id: 'polly',
      name: 'Polly fixture',
      provider: 'aws_polly',
      region: 'us-east-1',
      model: 'neural',
      baseUrl: 'http://127.0.0.1:${server.port}/proxy',
    );
    await settings.save(
      engine,
      apiKey: 'AKIDEXAMPLE',
      secretKey: 'fixture-private',
    );
    final saved = (await repo.list()).single;
    expect(jsonEncode(saved.toJson()), isNot(contains('fixture-private')));
    final catalog = RustCloudTtsVoiceCatalog(repo, credentials);
    final candidates = await catalog.discover(engine, HttpTtsCancellation());
    expect(gets, 2);
    expect(candidates.map((v) => v.id), ['Zhiyu', 'Joanna']);
    expect(candidates.first.supportedModels, ['standard', 'neural']);
    const voices = RustReadAloudVoiceRepository();
    final id = readAloudVoiceId('cloud_tts', 'polly', 'Zhiyu');
    const options = {'locale': 'cmn-CN', 'format': 'wav'};
    await voices.save(
      ReadAloudVoice(
        id: id,
        engineType: 'cloud_tts',
        engineId: 'polly',
        speakerId: 'Zhiyu',
        displayName: '智语',
        managedBy: 'user',
        traitsJson: jsonEncode(options),
      ),
    );
    final synth = RustCloudTtsSynthesizer(repo, credentials);
    final first = await synth.synthesize(
      engineId: 'polly',
      text: '甲😀',
      voiceId: id,
    ) as HttpTtsAudio;
    final bytes = await File(first.audioPath).readAsBytes();
    expect(
      ByteData.sublistView(Uint8List.fromList(bytes))
          .getUint32(24, Endian.little),
      16000,
    );
    expect(first.contentType, 'audio/wav');
    await first.lease!.release();
    final cached = await synth.synthesize(
      engineId: 'polly',
      text: '甲😀',
      voiceOptions: {...options, 'voiceId': 'Zhiyu'},
    ) as HttpTtsAudio;
    expect(cached.fromCache, isTrue);
    expect(posts, 1);
    await cached.lease!.release();
    for (final format in ['mp3', 'ogg_vorbis', 'pcm']) {
      final audio = await synth.synthesize(
        engineId: 'polly',
        text: '甲😀',
        voiceOptions: {
          'voiceId': 'Zhiyu',
          'locale': 'cmn-CN',
          'format': format,
          if (format == 'pcm') 'sampleRate': 8000,
        },
      ) as HttpTtsAudio;
      expect(audio.fromCache, isFalse);
      if (format == 'pcm') {
        final bytes = await File(audio.audioPath).readAsBytes();
        expect(
          ByteData.sublistView(Uint8List.fromList(bytes))
              .getUint32(24, Endian.little),
          8000,
        );
      }
      await audio.lease!.release();
    }
    expect(formats, ['pcm', 'mp3', 'ogg_vorbis', 'pcm']);
    await expectLater(
      synth.synthesize(
        engineId: 'polly',
        text: '甲😀 invalid',
        voiceOptions: {
          'voiceId': 'Zhiyu',
          'format': 'wav',
          'sampleRate': 24000,
        },
      ),
      throwsA(anything),
    );
    expect(posts, 4);
    badAudio = true;
    await expectLater(
      synth.synthesize(engineId: 'polly', text: '甲😀 retry', voiceId: id),
      throwsA(predicate((e) => !e.toString().contains('fixture-private'))),
    );
    badAudio = false;
    final retry = await synth.synthesize(
      engineId: 'polly',
      text: '甲😀 retry',
      voiceId: id,
    ) as HttpTtsAudio;
    expect(retry.fromCache, isFalse);
    await retry.lease!.release();
    repeatToken = true;
    await expectLater(
      catalog.discover(engine, HttpTtsCancellation()),
      throwsA(anything),
    );
    repeatToken = false;
    blockSecond = true;
    final cancellation = HttpTtsCancellation();
    final pending = catalog.discover(engine, cancellation);
    final failed = expectLater(pending, throwsA(anything));
    await entered.future.timeout(const Duration(seconds: 5));
    cancellation.cancel();
    await failed.timeout(const Duration(seconds: 5));
    release.complete();
    expect(gets, 6);
    expect((await voices.list()).single.id, id);
  });
}

void _verifySignature(HttpRequest request, List<int> body) {
  final hash = sha256.convert(body).toString();
  expect(request.headers.value('x-amz-content-sha256'), hash);
  final timestamp = request.headers.value('x-amz-date')!;
  final date = timestamp.substring(0, 8), host = request.headers.value('host')!;
  final keys = request.uri.queryParameters.keys.toList()..sort();
  final query = keys
      .map(
        (key) =>
            '${Uri.encodeComponent(key)}=${Uri.encodeComponent(request.uri.queryParameters[key]!)}',
      )
      .join('&');
  const signed = 'host;x-amz-content-sha256;x-amz-date';
  final canonical =
      '${request.method}\n${request.uri.path}\n$query\nhost:$host\nx-amz-content-sha256:$hash\nx-amz-date:$timestamp\n\n$signed\n$hash';
  final scope = '$date/us-east-1/polly/aws4_request';
  final text =
      'AWS4-HMAC-SHA256\n$timestamp\n$scope\n${sha256.convert(utf8.encode(canonical))}';
  List<int> key = utf8.encode('AWS4fixture-private');
  for (final part in [date, 'us-east-1', 'polly', 'aws4_request']) {
    key = Hmac(sha256, key).convert(utf8.encode(part)).bytes;
  }
  final signature = Hmac(sha256, key).convert(utf8.encode(text));
  expect(
    request.headers.value('authorization'),
    'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/$scope, SignedHeaders=$signed, Signature=$signature',
  );
}
