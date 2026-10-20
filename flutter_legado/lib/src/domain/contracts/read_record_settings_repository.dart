import '../models/read_record_settings.dart';

/// 普通偏好的读取、订阅与显式字段更新。— Codex + UI
abstract interface class ReadRecordSettingsRepository {
  ReadRecordSettings get current;
  Stream<ReadRecordSettings> watch();
  Future<ReadRecordSettings> load();
  Future<void> reload();
  Future<void> update({
    bool? enableRecord,
    ReadRecordSortMode? sortMode,
    ReadRecordDisplayMode? displayMode,
  });
}
