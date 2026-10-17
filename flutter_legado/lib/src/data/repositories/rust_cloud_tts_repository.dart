import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/cloud_tts_repository.dart';
import '../bridge/media_dto_mapping.dart';

final class RustCloudTtsRepository implements CloudTtsRepository {
  const RustCloudTtsRepository();
  @override
  Future<List<CloudTtsEngine>> list() async =>
      (await bridge.cloudTtsList()).map(cloudEngineFromDto).toList();
  @override
  Future<void> save(CloudTtsEngine engine) =>
      bridge.cloudTtsSave(engine: cloudEngineToDto(engine));
  @override
  Future<void> delete(String id) async {
    if (!await bridge.cloudTtsDelete(id: id)) throw StateError('云端引擎不存在');
  }

  @override
  Future<List<String>> voices(String provider) async =>
      (await bridge.cloudTtsVoices(provider: cloudProviderToDto(provider)))
          .map((v) => v.id)
          .toList();
}
