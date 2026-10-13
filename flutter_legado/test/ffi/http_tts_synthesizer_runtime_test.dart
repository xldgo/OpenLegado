/// 真实 Windows FFI 与本机 HTTP fixture，不依赖外部 TTS 网站。— Codex + Bridge
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/data/services/rust_http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  if (!Platform.isWindows) {
    test('HTTP 合成真实 FFI 需要 Windows DLL', () {}, skip: '未提供 Windows DLL');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  test('真实下载产物、Rust 缓存命中及失败探活使用新服务', () async {
    final cache = Directory(
      '.dart_tool/tts-synthesis-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    const runtime = NativeRustRuntime();
    await runtime.initialize();
    expect(await runtime.setTtsCacheDirectory(cache.absolute.path), isTrue);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final wave = _wave();
    var audioRequests = 0;
    var failedRequests = 0;
    final audioInputs = <Uri>[];
    server.listen((request) async {
      if (request.uri.path == '/audio') {
        audioRequests++;
        audioInputs.add(request.uri);
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
    final template = '$endpoint/audio?text={{text}}&speed={{speed}}';
    final first = await service.synthesize(
      text: '真实正文 😀',
      engineUrl: template,
      speed: 1.25,
    ) as HttpTtsAudio;
    expect(first.fromCache, isFalse);
    expect(first.contentType, 'audio/wav');
    expect(audioInputs.single.queryParameters['text'], '真实正文 😀');
    // Rust 的既有模板格式化保留一位小数，本批不改变语速协议。
    expect(audioInputs.single.queryParameters['speed'], '1.2');
    expect(File(first.audioPath).absolute.parent.path, cache.absolute.path);
    expect(await File(first.audioPath).readAsBytes(), wave);
    final second = await service.synthesize(
      text: '真实正文 😀',
      engineUrl: template,
      speed: 1.25,
    ) as HttpTtsAudio;
    expect(second.audioPath, first.audioPath);
    expect(second.fromCache, isTrue);
    expect(audioRequests, 1);
    final failure = await service.synthesize(
      text: '失败正文',
      engineUrl: '$endpoint/failure?text={{text}}',
    ) as HttpTtsNoAudio;
    expect(failure.reason, HttpTtsNoAudioReason.probeOnly);
    expect(failure.synthesisError, isNotNull);
    expect(failedRequests, 2);
    expect(cache.listSync().whereType<File>(), hasLength(1));
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
