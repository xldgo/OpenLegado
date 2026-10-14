import '../models/welcome_settings.dart';

/// 普通偏好的读取、订阅与显式字段更新。— Codex + UI
abstract interface class WelcomeSettingsRepository {
  WelcomeSettings get current;
  Stream<WelcomeSettings> watch();
  Future<WelcomeSettings> load();
  Future<void> reload();
  Future<void> update({
    int? showTime,
    bool? customWelcome,
    String? imageDay,
    String? imageNight,
    bool? showText,
    bool? showIcon,
    bool? showTextDark,
    bool? showIconDark,
    bool? defaultToRead,
  });
}
