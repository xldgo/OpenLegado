import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/cloud_tts_repository.dart';

final class RustCloudTtsRepository implements CloudTtsRepository {
  const RustCloudTtsRepository();
  @override
  Future<List<CloudTtsEngine>> list() async =>
      (jsonDecode(await bridge.cloudTtsList()) as List)
          .map((e) => CloudTtsEngine.fromJson(e as Map<String, dynamic>))
          .toList();
  @override
  Future<void> save(CloudTtsEngine engine) =>
      bridge.cloudTtsSave(engineJson: jsonEncode(engine.toJson()));
  @override
  Future<void> delete(String id) async {
    if (!await bridge.cloudTtsDelete(id: id)) throw StateError('云端引擎不存在');
  }

  @override
  Future<List<String>> voices(String provider) async =>
      (jsonDecode(await bridge.cloudTtsVoices(provider: provider)) as List)
          .map((e) => (e as Map<String, dynamic>)['id'] as String)
          .toList();
}
