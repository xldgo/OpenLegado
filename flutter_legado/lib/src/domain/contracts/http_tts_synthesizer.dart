import 'tts_cache_repository.dart';

/// 单次合成的取消状态，由播放会话拥有，原生适配器注册取消回调。— Codex + Bridge
final class HttpTtsCancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>{};
  bool get isCancelled => _cancelled;
  void addListener(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(void Function() listener) => _listeners.remove(listener);
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}

/// HTTP 合成产物与无产物结果分开，播放会话自行决定如何处理。— Codex + Bridge
sealed class HttpTtsSynthesisResult {
  const HttpTtsSynthesisResult();
}

final class HttpTtsCancelled extends HttpTtsSynthesisResult {
  const HttpTtsCancelled();
}

final class HttpTtsAudio extends HttpTtsSynthesisResult {
  const HttpTtsAudio({
    required this.audioPath,
    this.fromCache,
    this.contentType,
    this.lease,
  });

  final String audioPath;
  final bool? fromCache;
  final String? contentType;
  final TtsAudioLease? lease;
}

enum HttpTtsNoAudioReason { emptyResult, synthesisFailed, mock }

final class HttpTtsNoAudio extends HttpTtsSynthesisResult {
  const HttpTtsNoAudio(this.reason, {this.synthesisError});

  final HttpTtsNoAudioReason reason;
  final Object? synthesisError;
}

/// 只负责 HTTP 合成；配置持久化、系统语音及音频播放各自独立。
abstract interface class HttpTtsSynthesizer {
  Future<HttpTtsSynthesisResult> synthesize({
    required int engineId,
    required String text,
    String? engineUrl,
    double speed = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
    String? voiceName,
    String? toneId,
    String? speakerName,
    String? emotionTag,
    HttpTtsCancellation? cancellation,
  });
}
