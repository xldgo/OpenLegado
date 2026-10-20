import '../bridge/rust_errors.dart';
import '../../bridge/ffi.dart' as controls;
import '../../bridge/media_dto.dart';
import '../bridge/media_dto_mapping.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/cloud_tts_repository.dart';
import '../../domain/contracts/cloud_tts_credential_store.dart';
import '../../domain/contracts/cloud_tts_synthesizer.dart';
import '../../domain/contracts/http_tts_synthesizer.dart';
import '../../domain/contracts/tts_cache_repository.dart';

final class RustCloudTtsSynthesizer implements CloudTtsSynthesizer {
  RustCloudTtsSynthesizer(this.repository, this.credentials);
  final CloudTtsRepository repository;
  final CloudTtsCredentialStore credentials;
  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required String engineId,
    required String text,
    String? voiceId,
    Map<String, dynamic>? voiceOptions,
    HttpTtsCancellation? cancellation,
  }) async {
    if (cancellation?.isCancelled == true) return const HttpTtsCancelled();
    final engine = await repository.get(engineId);
    if (engine == null || !engine.enabled) throw StateError('云端引擎不存在或已停用');
    final apiKey = await credentials.read(engine.credentialKey);
    if (cancellation?.isCancelled == true) return const HttpTtsCancelled();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw StateError('云端凭据不可用，请重新填写 API Key');
    }
    final request = rustCall(
      () => controls.ttsRequestNew(),
      operation: 'ttsRequestNew',
    );
    var transferred = false;
    void cancel() => request.cancel();
    cancellation?.addListener(cancel);
    try {
      final result = await rustFuture(
        () => bridge.cloudTtsSpeak(
          engineId: engineId,
          apiKey: apiKey,
          input: CloudSpeechInputDto(
            text: text,
            credentialKey: engine.credentialKey,
            voiceId: voiceId,
            voiceOptions: voiceOptions == null
                ? null
                : cloudVoiceOptionsToDto(voiceOptions),
          ),
          request: request,
        ),
        operation: 'cloudTtsSpeak',
      );
      if (cancellation?.isCancelled == true) return const HttpTtsCancelled();
      final path = result.audioPath;
      if (path.isEmpty) throw StateError('云端合成没有返回音频');
      transferred = true;
      return HttpTtsAudio(
        audioPath: path,
        fromCache: result.fromCache,
        contentType: result.contentType,
        lease: _Lease(request),
      );
    } catch (_) {
      if (cancellation?.isCancelled == true) return const HttpTtsCancelled();
      rethrow;
    } finally {
      cancellation?.removeListener(cancel);
      if (!transferred) request.dispose();
    }
  }
}

class _Lease implements TtsAudioLease {
  _Lease(this._request);
  controls.TtsRequest? _request;
  @override
  Future<void> release() async {
    final request = _request;
    _request = null;
    request?.dispose();
  }
}
