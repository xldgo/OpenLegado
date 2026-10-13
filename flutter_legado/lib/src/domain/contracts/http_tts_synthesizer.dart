/// HTTP 合成产物与无产物结果分开，播放会话自行决定如何处理。— Codex + Bridge
sealed class HttpTtsSynthesisResult {
  const HttpTtsSynthesisResult();
}

final class HttpTtsAudio extends HttpTtsSynthesisResult {
  const HttpTtsAudio({
    required this.audioPath,
    this.fromCache,
    this.contentType,
  });

  final String audioPath;
  final bool? fromCache;
  final String? contentType;
}

enum HttpTtsNoAudioReason { emptyResult, probeOnly, mock }

final class HttpTtsNoAudio extends HttpTtsSynthesisResult {
  const HttpTtsNoAudio(this.reason, {this.synthesisError});

  final HttpTtsNoAudioReason reason;
  final Object? synthesisError;
}

/// 只负责 HTTP 合成；配置持久化、系统语音及音频播放各自独立。
abstract interface class HttpTtsSynthesizer {
  Future<HttpTtsSynthesisResult> synthesize({
    required String text,
    required String engineUrl,
    double speed = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
    String? voiceName,
  });
}
