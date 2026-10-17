import '../../domain/contracts/read_aloud_voice_repository.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../bridge/media_dto_mapping.dart';

/// 目录权威状态位于 Rust 数据库。— Codex + Bridge
final class RustReadAloudVoiceRepository implements ReadAloudVoiceRepository {
  const RustReadAloudVoiceRepository();
  @override
  bool get supportsCatalog => true;
  @override
  Future<List<ReadAloudVoice>> list() async =>
      (await bridge.readAloudVoiceList())
          .map(readAloudVoiceFromDto)
          .toList(growable: false);
  @override
  Future<void> save(ReadAloudVoice voice) =>
      bridge.readAloudVoiceSave(voice: readAloudVoiceToDto(voice));
  @override
  Future<void> delete(String id) async {
    if (!await bridge.readAloudVoiceDelete(id: id)) throw StateError('用户音色不存在');
  }

  @override
  Future<void> syncSystem(
    String engineId,
    List<SystemVoiceCatalogEntry> entries,
  ) => bridge.readAloudVoiceSyncSystem(
    engineId: engineId,
    entries: entries.map(systemVoiceToDto).toList(),
  );
  @override
  Future<void> setFlags(
    String id, {
    required bool enabled,
    required bool excluded,
  }) async {
    if (!await bridge.readAloudVoiceSetFlags(
      id: id,
      enabled: enabled,
      excluded: excluded,
    )) {
      throw StateError('音色不存在');
    }
  }
}
