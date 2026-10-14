import 'http_tts_synthesizer.dart';

/// 共用文件产物/取消协议，云端配置与网络不属于 HTTP 源仓库。— Codex + Bridge
abstract interface class CloudTtsSynthesizer {
  Future<HttpTtsSynthesisResult> synthesize({
    required String engineId,
    required String text,
    String? voiceId,
    Map<String, dynamic>? voiceOptions,
    HttpTtsCancellation? cancellation,
  });
}
