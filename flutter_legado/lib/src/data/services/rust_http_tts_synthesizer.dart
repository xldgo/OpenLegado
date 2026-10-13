import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/http_tts_synthesizer.dart';
import '../bridge/bridge_http_response.dart';

/// Rust 拥有音频下载与缓存；此处保留原合成及失败探活的判定。— Codex + Bridge
class RustHttpTtsSynthesizer implements HttpTtsSynthesizer {
  const RustHttpTtsSynthesizer();

  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required String text,
    required String engineUrl,
    double speed = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
    String? voiceName,
  }) async {
    try {
      final raw = await bridge.ttsSpeak(
        text: text,
        engineUrl: engineUrl,
        speed: speed,
      );
      final result = (jsonDecode(raw) as Map<String, dynamic>)
          .cast<String, dynamic>();
      final path = (result['audioPath'] as String?)?.trim() ?? '';
      debugPrint(
        'ttsSpeak 合成完成: audioPath=$path '
        'fromCache=${result['fromCache']} contentType=${result['contentType']}',
      );
      if (path.isEmpty) {
        return const HttpTtsNoAudio(HttpTtsNoAudioReason.emptyResult);
      }
      // 旧流程只要求路径合法，诊断字段缺失或类型异常不改变播放判定。
      return HttpTtsAudio(
        audioPath: path,
        fromCache: result['fromCache'] is bool ? result['fromCache'] : null,
        contentType: result['contentType'] is String
            ? result['contentType']
            : null,
      );
    } catch (error) {
      debugPrint('ttsSpeak 真实管线失败，降级探活: $error');
      var url = engineUrl
          .replaceAll('{{speakText}}', Uri.encodeComponent(text))
          .replaceAll('{{text}}', Uri.encodeComponent(text))
          .replaceAll('{{speakSpeed}}', speed.toString())
          .replaceAll('{{speed}}', speed.toString())
          .replaceAll('{{pitch}}', pitch.toString())
          .replaceAll('{{volume}}', volume.toString());
      if (voiceName != null) {
        url = url.replaceAll('{{voice}}', Uri.encodeComponent(voiceName));
      }
      final raw = await bridge
          .httpGet(url: url)
          .timeout(const Duration(seconds: 30));
      final probe = BridgeHttpResponse.fromJson(raw, fallbackUrl: url);
      if (!probe.isSuccess) throw StateError('HTTP ${probe.statusCode}');
      return HttpTtsNoAudio(
        HttpTtsNoAudioReason.probeOnly,
        synthesisError: error,
      );
    }
  }
}
