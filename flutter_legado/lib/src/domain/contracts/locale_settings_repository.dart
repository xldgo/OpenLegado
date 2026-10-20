import '../models/locale_settings.dart';

/// 普通偏好的读取、订阅与显式字段更新。— Codex + UI
abstract interface class LocaleSettingsRepository {
  LocaleSettings get current;
  Stream<LocaleSettings> watch();
  Future<LocaleSettings> load();
  Future<void> reload();
  Future<void> update({String? locale});
}
