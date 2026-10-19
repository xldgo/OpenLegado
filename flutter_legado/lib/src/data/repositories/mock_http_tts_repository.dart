import 'mock_read_aloud_voice_repository.dart';

import 'dart:convert';

import '../../domain/contracts/http_tts_repository.dart';
import '../../models/models.dart';
import '../services/http_tts_export_document.dart';

/// 每个 Mock 会话只拥有一份引擎列表，ID 沿用应用装配。— Codex + Bridge
final class MockHttpTtsRepository implements HttpTtsRepository {
  MockHttpTtsRepository({
    required this.nextId,
    MockReadAloudVoiceRepository? voiceCatalog,
    bool withDefaultEngines = false,
  }) : voiceCatalog = voiceCatalog ?? MockReadAloudVoiceRepository() {
    if (withDefaultEngines) {
      // ── HTTP TTS 引擎（来源：app/src/main/assets/defaultData/httpTTS.json）──
      _httpTtsList.addAll([
        HttpTts(
          id: -100,
          name: '1.百度',
          url: 'http://tts.baidu.com/text2audio,{"method": "POST","body": "tex={{java.encodeURI(java.encodeURI(speakText))}}&spd={{(speakSpeed + 5) / 10 + 4}}&per=3&cuid=baidu_speech_demo&idx=1&cod=2&lan=zh&ctp=1&pdt=160&vol=5&aue=6&pit=5&_res_tag_=audio"}',
          contentType: 'audio/wav',
        ),
        HttpTts(
          id: -29,
          name: '2.阿里云语音',
          url: 'https://nls-gateway.cn-shanghai.aliyuncs.com/stream/v1/tts,{"method": "POST","body": {"appkey":"{{source.getLoginInfoMap().get(\'AppKey\')}}","text":"{{speakText}}","format":"mp3","volume":100,"speech_rate":{{String((speakSpeed) * 20 - 400)}} }}',
          contentType: 'audio/mpeg',
        ),
      ]);
    }
  }

  final int Function() nextId;
  final MockReadAloudVoiceRepository voiceCatalog;
  final List<HttpTts> _httpTtsList = [];

  int _allocateNewId() {
    var candidate = nextId();
    while (_httpTtsList.any((e) => e.id == candidate)) {
      candidate = nextId();
    }
    return candidate;
  }

  // ========== HTTP TTS ==========

  @override
  Future<List<HttpTts>> getHttpTts() async => List.from(_httpTtsList);

  @override
  Future<HttpTts> addHttpTts(HttpTts tts) async {
    final isAutoId = tts.id == 0;
    final t = tts.copyWith(
      id: isAutoId ? _allocateNewId() : tts.id,
      synthesisThreadCount: tts.synthesisThreadCount.clamp(
        1,
        kMaxHttpTtsSynthesisThreadCount,
      ),
    );
    if (isAutoId) {
      _httpTtsList.add(t);
    } else {
      final existingIdx = _httpTtsList.indexWhere((e) => e.id == t.id);
      if (existingIdx >= 0) {
        _httpTtsList[existingIdx] = t;
      } else {
        _httpTtsList.add(t);
      }
    }
    return t;
  }

  @override
  Future<void> updateHttpTts(HttpTts tts) async {
    final idx = _httpTtsList.indexWhere((t) => t.id == tts.id);
    if (idx < 0) {
      throw StateError('HTTP TTS 引擎不存在: id=${tts.id}');
    }
    _httpTtsList[idx] = tts.copyWith(
      synthesisThreadCount: tts.synthesisThreadCount.clamp(
        1,
        kMaxHttpTtsSynthesisThreadCount,
      ),
    );
  }

  @override
  Future<void> deleteHttpTts(int id) async {
    _httpTtsList.removeWhere((t) => t.id == id);
    voiceCatalog.clearHttp(id);
  }

  @override
  Future<int> importHttpTts(String json) async {
    final list = jsonDecode(json) as List<dynamic>;
    // 整批预检后再写入；Mock 不允许解析失败留下半批配置。
    final prepared = <({HttpTts tts, Map<String, dynamic> raw})>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('HTTP TTS 导入条目不是 JSON 对象');
      }
      final parsed = HttpTts.fromJson(item);
      if (parsed.name.isEmpty || parsed.url.isEmpty) continue;
      prepared.add((tts: parsed, raw: item));
    }
    var count = 0;
    for (final item in [
      ...prepared.where((e) => e.tts.id != 0),
      ...prepared.where((e) => e.tts.id == 0),
    ]) {
      final saved = await addHttpTts(item.tts);
      voiceCatalog.importHttp(saved.id, item.raw);
      count++;
    }
    return count;
  }

  @override
  Future<String> exportHttpTts() async =>
      httpTtsExportDocument(_httpTtsList, await voiceCatalog.list());

  @override
  Future<bool> httpTtsSetEnabled(int id, bool enabled) async {
    final idx = _httpTtsList.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      _httpTtsList[idx] = _httpTtsList[idx].copyWith(isEnabled: enabled);
    }
    return true;
  }
}
