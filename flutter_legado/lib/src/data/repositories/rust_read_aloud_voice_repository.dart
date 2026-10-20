import '../bridge/rust_errors.dart';
import '../../domain/contracts/read_aloud_voice_repository.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../bridge/media_dto_mapping.dart';

/// 目录权威状态位于 Rust 数据库。— Codex + Bridge
final class RustReadAloudVoiceRepository implements ReadAloudVoiceRepository {
  const RustReadAloudVoiceRepository();
  @override
  bool get supportsCatalog => true;
  @override
  Future<List<ReadAloudVoice>> list() async => (await rustFuture(
    () => bridge.readAloudVoiceList(),
    operation: 'readAloudVoiceList',
  )).map(readAloudVoiceFromDto).toList(growable: false);
  @override
  Future<void> save(ReadAloudVoice voice) => rustFuture(
    () => bridge.readAloudVoiceSave(voice: readAloudVoiceToDto(voice)),
    operation: 'readAloudVoiceSave',
  );
  @override
  Future<void> delete(String id) async {
    if (!await rustFuture(
      () => bridge.readAloudVoiceDelete(id: id),
      operation: 'readAloudVoiceDelete',
    )) {
      throw StateError('用户音色不存在');
    }
  }

  @override
  Future<void> syncSystem(
    String engineId,
    List<SystemVoiceCatalogEntry> entries,
  ) => rustFuture(
    () => bridge.readAloudVoiceSyncSystem(
      engineId: engineId,
      entries: entries.map(systemVoiceToDto).toList(),
    ),
    operation: 'readAloudVoiceSyncSystem',
  );
  @override
  Future<void> setFlags(
    String id, {
    required bool enabled,
    required bool excluded,
  }) async {
    if (!await rustFuture(
      () => bridge.readAloudVoiceSetFlags(
        id: id,
        enabled: enabled,
        excluded: excluded,
      ),
      operation: 'readAloudVoiceSetFlags',
    )) {
      throw StateError('音色不存在');
    }
  }
}
