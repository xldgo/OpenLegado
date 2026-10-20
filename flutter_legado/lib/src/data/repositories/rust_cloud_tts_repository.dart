import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/cloud_tts_repository.dart';
import '../bridge/media_dto_mapping.dart';

final class RustCloudTtsRepository implements CloudTtsRepository {
  const RustCloudTtsRepository();
  @override
  Future<List<CloudTtsEngine>> list() async => (await rustFuture(
    () => bridge.cloudTtsList(),
    operation: 'cloudTtsList',
  )).map(cloudEngineFromDto).toList();
  @override
  Future<void> save(CloudTtsEngine engine) => rustFuture(
    () => bridge.cloudTtsSave(engine: cloudEngineToDto(engine)),
    operation: 'cloudTtsSave',
  );
  @override
  Future<void> delete(String id) async {
    if (!await rustFuture(
      () => bridge.cloudTtsDelete(id: id),
      operation: 'cloudTtsDelete',
    )) {
      throw StateError('云端引擎不存在');
    }
  }

  @override
  Future<List<String>> voices(String provider) async => (await rustFuture(
    () => bridge.cloudTtsVoices(provider: cloudProviderToDto(provider)),
    operation: 'cloudTtsVoices',
  )).map((v) => v.id).toList();
}
