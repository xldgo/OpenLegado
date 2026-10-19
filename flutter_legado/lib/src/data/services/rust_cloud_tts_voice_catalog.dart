import '../../domain/contracts/cloud_tts_voice_catalog.dart';
import '../../domain/contracts/cloud_tts_repository.dart';
import '../../domain/contracts/cloud_tts_credential_store.dart';
import '../../domain/contracts/http_tts_synthesizer.dart';
import '../../bridge/ffi.dart' as controls;
import '../../bridge/ffi/ffi.dart' as bridge;
import '../bridge/rust_errors.dart';

/// 配置仓库只读元数据；发现服务临时读取凭据并拥有取消句柄。— Codex + Bridge
final class RustCloudTtsVoiceCatalog implements CloudTtsVoiceCatalog {
  const RustCloudTtsVoiceCatalog(this.repository, this.credentials);
  final CloudTtsRepository repository;
  final CloudTtsCredentialStore credentials;
  @override
  Future<List<CloudTtsVoiceDescriptor>> discover(
    CloudTtsEngine engine,
    HttpTtsCancellation cancellation,
  ) async {
    if (cancellation.isCancelled) throw StateError('音色发现已取消');
    final current = (await repository.list())
        .where((e) => e.id == engine.id)
        .firstOrNull;
    if (current == null ||
        !current.enabled ||
        current.provider != engine.provider) {
      throw StateError('云端引擎不存在、已停用或已变更');
    }
    final key = await credentials.read(current.credentialKey);
    if (cancellation.isCancelled) throw StateError('音色发现已取消');
    if (key == null || key.trim().isEmpty) throw StateError('云端凭据不可用，请重新填写密钥');
    final request = rustCall(
      () => controls.ttsRequestNew(),
      operation: 'ttsRequestNew',
    );
    void cancel() => request.cancel();
    cancellation.addListener(cancel);
    try {
      final voices = await rustFuture(
        () => bridge.cloudTtsEngineVoices(
          engineId: current.id,
          apiKey: key,
          credentialKey: current.credentialKey,
          request: request,
        ),
        operation: 'cloudTtsEngineVoices',
      );
      if (cancellation.isCancelled) throw StateError('音色发现已取消');
      return List.unmodifiable(
        voices.map(
          (v) => CloudTtsVoiceDescriptor(
            id: v.id,
            name: v.displayName,
            locale: v.locale,
            gender: v.gender,
            styles: List.unmodifiable(v.styles),
            roles: List.unmodifiable(v.roles),
            sampleRate: v.sampleRate,
          ),
        ),
      );
    } finally {
      cancellation.removeListener(cancel);
      request.dispose();
    }
  }
}
