library;

/// 真实 Windows FFI 与本机 HTTP fixture，不依赖外部 TTS 网站。— Codex + Bridge
@Timeout(Duration(minutes: 3))
import 'dart:async';
import 'dart:convert';

import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';

import 'package:flutter_legado/src/data/repositories/rust_read_aloud_voice_repository.dart';

import 'package:flutter_legado/src/data/repositories/rust_tts_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/data/repositories/rust_http_tts_repository.dart';
import 'package:flutter_legado/src/data/services/rust_http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  if (!Platform.isWindows) {
    test('HTTP 合成真实 FFI 需要 Windows DLL', () {}, skip: '未提供 Windows DLL');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  test('真实合成、目录选择、情感缓存隔离及系统目录生命周期', () async {
    final cache = Directory(
      '.dart_tool/tts-synthesis-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final dbDir = Directory(
      '.dart_tool/tts-db-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    const runtime = NativeRustRuntime();
    await runtime.initialize();
    await bridge.dbOpen(path: '${dbDir.absolute.path}/test.db');
    expect(await runtime.setTtsCacheDirectory(cache.absolute.path), isTrue);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final wave = _wave();
    var audioRequests = 0;
    var failedRequests = 0;
    final audioInputs = <Uri>[];
    final audioHeaders = <String?>[];
    final slowEntered = Completer<void>();
    server.listen((request) async {
      if (request.uri.path == '/slow') {
        slowEntered.complete();
        await Future<void>.delayed(const Duration(seconds: 2));
        request.response.add(wave);
      } else if (request.uri.path == '/audio') {
        audioRequests++;
        audioInputs.add(request.uri);
        audioHeaders.add(request.headers.value('x-auth'));
        request.response.headers.contentType = ContentType('audio', 'wav');
        request.response.add(wave);
      } else {
        failedRequests++;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"error":"没有音频"}');
      }
      await request.response.close();
    });
    final endpoint = 'http://127.0.0.1:${server.port}';
    const service = RustHttpTtsSynthesizer();
    const repo = RustHttpTtsRepository();
    final template = '$endpoint/audio?text={{text}}&speed={{speakSpeed}}';
    final savedEngine = await repo.addHttpTts(
      HttpTts(name: '测试引擎', url: template),
    );
    final first = await service.synthesize(
      engineId: savedEngine.id,
      text: '真实正文 😀',
      speed: 1.25,
    ) as HttpTtsAudio;
    expect(first.fromCache, isFalse);
    expect(first.contentType, 'audio/wav');
    expect(audioInputs.single.queryParameters['text'], '真实正文 😀');
    expect(audioInputs.single.queryParameters['speed'], '10');
    expect(File(first.audioPath).absolute.parent.path, cache.absolute.path);
    expect(await File(first.audioPath).readAsBytes(), wave);
    final second = await service.synthesize(
      engineId: savedEngine.id,
      text: '真实正文 😀',
      speed: 1.75,
    ) as HttpTtsAudio;
    expect(second.audioPath, first.audioPath);
    expect(second.fromCache, isTrue);
    expect(audioRequests, 1);
    final failedEngine = await repo.addHttpTts(
      HttpTts(name: '失败引擎', url: '$endpoint/failure?text={{text}}'),
    );
    final failure = await service.synthesize(
      engineId: failedEngine.id,
      text: '失败正文',
    ) as HttpTtsNoAudio;
    expect(failure.reason, HttpTtsNoAudioReason.synthesisFailed);
    expect(failure.synthesisError, isNotNull);
    expect(failedRequests, 1);
    expect(cache.listSync().whereType<File>(), hasLength(1));
    final slow = await repo.addHttpTts(
      HttpTts(name: '取消请求', url: '$endpoint/slow'),
    );
    final cancellation = HttpTtsCancellation();
    final pending = service.synthesize(
      engineId: slow.id,
      text: '停止后不得写缓存',
      cancellation: cancellation,
    );
    await slowEntered.future.timeout(const Duration(seconds: 5));
    cancellation.cancel();
    expect(
      await pending.timeout(const Duration(seconds: 2)),
      isA<HttpTtsCancelled>(),
    );
    expect(cache.listSync().whereType<File>(), hasLength(1));
    final loginEngine = await repo.addHttpTts(
      HttpTts(
        name: '真实登录引擎',
        url: template,
        loginUi: '[{"name":"account","type":"text"}]',
        loginUrl: "function login(){source.putLoginHeader(JSON.stringify({'X-Auth':source.getLoginInfoMap().account}));}",
      ),
    );
    expect(
      await bridge.httpTtsLogin(
        engineId: loginEngine.id,
        operation: 'ui',
        payload: '{}',
      ),
      contains('account'),
    );
    await bridge.httpTtsLogin(
      engineId: loginEngine.id,
      operation: 'putInfo',
      payload: '{"account":"local-token"}',
    );
    await bridge.httpTtsLogin(
      engineId: loginEngine.id,
      operation: 'eval',
      payload: 'login.apply(this)',
    );
    expect(
      await bridge.httpTtsLogin(
        engineId: loginEngine.id,
        operation: 'header',
        payload: '',
      ),
      contains('local-token'),
    );
    final authenticated = await service.synthesize(
      engineId: loginEngine.id,
      text: '登录后的真实正文',
    ) as HttpTtsAudio;
    expect(authenticated.fromCache, isFalse);
    expect(audioHeaders.last, 'local-token');
    expect(await File(authenticated.audioPath).readAsBytes(), wave);
    const files = RustTtsCacheRepository();
    const context = TtsCacheContext(
      bookUrl: 'book',
      bookName: '书名',
      chapterIndex: 0,
      chapterTitle: '第一章',
      paragraphIndex: 0,
      text: '真实正文 😀',
    );
    await files.record(first.audioPath, context);
    await files.record(
      first.audioPath,
      const TtsCacheContext(
        bookUrl: 'other',
        bookName: '另一本书',
        chapterIndex: 1,
        chapterTitle: '重复正文',
        paragraphIndex: 1,
        text: '真实正文 😀',
      ),
    );
    var entries = await files.list();
    expect(entries, hasLength(2));
    expect(entries.every((e) => e.protected), isTrue);
    expect(
      entries.singleWhere((e) => e.contexts.isNotEmpty).contexts,
      hasLength(2),
    );
    expect((await files.clear()).skippedFiles, 2);
    await first.lease!.release();
    await first.lease!.release(); // 重复释放不得减为负数。
    await second.lease!.release();
    await authenticated.lease!.release();
    // FRB opaque 的释放异步到达 Rust，等待可观测的租约退出。
    for (var i = 0; i < 50; i++) {
      entries = await files.list();
      if (entries.every((e) => !e.protected)) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(entries.every((e) => !e.protected), isTrue);
    final removed = await files.clear();
    expect(removed.removedFiles, 2);
    expect(removed.removedBytes, wave.length * 2);
    expect(await files.list(), isEmpty);
    const catalog = RustReadAloudVoiceRepository();
    await repo.importHttpTts(
      jsonEncode([
        {
          'id': 9004,
          'name': '音色源',
          'url':
              '$endpoint/audio?text={{speakText}}&tone={{currentToneID}}&speaker={{currentSpeakerName}}&emotion={{currentEmotionTag}}',
          'speakersJson': '[{"name":"中文女声","toneID":"zh-a"}]',
          'emotionsJson':
              '[{"name":"高兴","tag":"happy"},{"name":"平静","tag":"calm"}]',
        },
      ]),
    );
    final voice = (await catalog.list()).singleWhere(
      (v) => v.engineId == '9004',
    );
    final happy = await service.synthesize(
      engineId: 9004,
      text: '真实音色',
      toneId: voice.speakerId,
      speakerName: voice.displayName,
      emotionTag: 'happy',
    ) as HttpTtsAudio;
    expect(audioInputs.last.queryParameters['tone'], 'zh-a');
    expect(audioInputs.last.queryParameters['speaker'], '中文女声');
    expect(audioInputs.last.queryParameters['emotion'], 'happy');
    final cached = await service.synthesize(
      engineId: 9004,
      text: '真实音色',
      toneId: voice.speakerId,
      speakerName: voice.displayName,
      emotionTag: 'happy',
    ) as HttpTtsAudio;
    expect(cached.fromCache, true);
    final calm = await service.synthesize(
      engineId: 9004,
      text: '真实音色',
      toneId: voice.speakerId,
      speakerName: voice.displayName,
      emotionTag: 'calm',
    ) as HttpTtsAudio;
    expect(calm.fromCache, false);
    expect(calm.audioPath, isNot(happy.audioPath));
    await catalog.setFlags(voice.id, enabled: false, excluded: true);
    expect(
      (await catalog.list()).singleWhere((v) => v.id == voice.id).excluded,
      true,
    );
    await repo.deleteHttpTts(9004);
    expect((await catalog.list()).where((v) => v.engineId == '9004'), isEmpty);
    await happy.lease!.release();
    await cached.lease!.release();
    await calm.lease!.release();
    const systemEntries = [
      SystemVoiceCatalogEntry(
        speakerId: 'device.zh',
        displayName: '设备中文',
        traitsJson: '{"locale":"zh-CN","voiceKey":"native-key"}',
      ),
    ];
    await catalog.syncSystem('system:fixture', systemEntries);
    final deviceVoice = (await catalog.list()).singleWhere(
      (v) => v.engineType == 'system',
    );
    await catalog.setFlags(deviceVoice.id, enabled: true, excluded: true);
    await catalog.syncSystem('system:fixture', []);
    expect(
      (await catalog.list())
          .singleWhere((v) => v.id == deviceVoice.id)
          .available,
      false,
    );
    await catalog.syncSystem('system:fixture', systemEntries);
    final reappeared = (await catalog.list()).singleWhere(
      (v) => v.id == deviceVoice.id,
    );
    expect(reappeared.available, true);
    expect(reappeared.excluded, true);
    expect(reappeared.createdAt, deviceVoice.createdAt);
    await expectLater(
      files.clear(name: '../tts_invalid.mp3'),
      throwsA(anything),
    );
  });
}

Uint8List _wave() {
  final bytes = Uint8List(52);
  final data = ByteData.sublistView(bytes);
  void label(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  label(0, 'RIFF');
  data.setUint32(4, 44, Endian.little);
  label(8, 'WAVE');
  label(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  label(36, 'data');
  data.setUint32(40, 8, Endian.little);
  return bytes;
}
