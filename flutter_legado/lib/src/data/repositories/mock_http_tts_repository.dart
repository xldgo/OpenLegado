import 'dart:convert';

import '../../domain/contracts/http_tts_repository.dart';
import '../../models/models.dart';

/// 每个 Mock 会话只拥有一份引擎列表，ID 沿用应用装配。— Codex + Bridge
final class MockHttpTtsRepository implements HttpTtsRepository {
  MockHttpTtsRepository({
    required this.nextId,
    bool withDefaultEngines = false,
  }) {
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
  final List<HttpTts> _httpTtsList = [];

  // ========== HTTP TTS ==========

  @override
  Future<List<HttpTts>> getHttpTts() async => List.from(_httpTtsList);

  @override
  Future<HttpTts> addHttpTts(HttpTts tts) async {
    final t = tts.copyWith(id: nextId());
    _httpTtsList.add(t);
    return t;
  }

  @override
  Future<void> updateHttpTts(HttpTts tts) async {
    final idx = _httpTtsList.indexWhere((t) => t.id == tts.id);
    if (idx >= 0) _httpTtsList[idx] = tts;
  }

  @override
  Future<void> deleteHttpTts(int id) async {
    _httpTtsList.removeWhere((t) => t.id == id);
  }

  @override
  Future<int> importHttpTts(String json) async {
    final list = jsonDecode(json) as List<dynamic>;
    return list.length;
  }

  @override
  Future<String> exportHttpTts() async =>
      jsonEncode(_httpTtsList.map((t) => t.toJson()).toList());

  @override
  Future<bool> httpTtsSetEnabled(int id, bool enabled) async => true;
}
