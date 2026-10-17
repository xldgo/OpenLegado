import '../../domain/contracts/tts_cache_repository.dart';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../bridge/rust_lib.dart' as bridge;
import '../../bridge/ffi.dart' as controls;
import '../../domain/contracts/http_tts_synthesizer.dart';

/// Rust 拥有音频下载与缓存；通过 engineId 查库执行完整合成与校验管线。— Codex + Bridge
class RustHttpTtsSynthesizer implements HttpTtsSynthesizer {
  const RustHttpTtsSynthesizer();

  @override
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
  }) async {
    if (cancellation?.isCancelled == true) return const HttpTtsCancelled();
    final request = controls.ttsRequestNew();
    var transferred = false;
    void cancel() => request.cancel();
    cancellation?.addListener(cancel);
    try {
      if (cancellation?.isCancelled == true) return const HttpTtsCancelled();
      final result = await bridge.ttsSpeak(
        engineId: engineId,
        request: request,
        text: text,
        toneId: toneId,
        speakerName: speakerName ?? voiceName,
        emotionTag: emotionTag,
      );
      if (cancellation?.isCancelled == true) return const HttpTtsCancelled();
      final path = result.audioPath.trim();
      debugPrint(
        'ttsSpeak 合成完成: audioPath=$path '
        'fromCache=${result.fromCache} contentType=${result.contentType}',
      );
      if (path.isEmpty) {
        return const HttpTtsNoAudio(HttpTtsNoAudioReason.emptyResult);
      }
      // 播放判定仍以有效路径为准，诊断信息由类型化结果承载。
      transferred = true;
      return HttpTtsAudio(
        lease: _RustAudioLease(request),
        audioPath: path,
        fromCache: result.fromCache,
        contentType: result.contentType,
      );
    } catch (error) {
      if (cancellation?.isCancelled == true) return const HttpTtsCancelled();
      debugPrint('ttsSpeak 真实管线失败: $error');
      return HttpTtsNoAudio(
        HttpTtsNoAudioReason.synthesisFailed,
        synthesisError: error,
      );
    } finally {
      cancellation?.removeListener(cancel);
      if (!transferred) request.dispose();
    }
  }
}

/// 句柄在 Rust 中持有文件租约，停止播放器之后再释放。
final class _RustAudioLease implements TtsAudioLease {
  _RustAudioLease(this._request);
  controls.TtsRequest? _request;
  @override
  Future<void> release() async {
    final request = _request;
    _request = null;
    request?.dispose();
  }
}
