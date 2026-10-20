import '../models/eye_protection_settings.dart';

/// 普通偏好的读取、订阅与显式字段更新。— Codex + UI
abstract interface class EyeProtectionSettingsRepository {
  EyeProtectionSettings get current;
  Stream<EyeProtectionSettings> watch();
  Future<EyeProtectionSettings> load();
  Future<void> reload();
  Future<void> update({
    bool? enabled,
    int? intensity,
    bool? autoNight,
    bool? schedule,
    String? startTime,
    String? endTime,
  });
}
