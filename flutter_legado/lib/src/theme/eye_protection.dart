import 'package:shared_preferences/shared_preferences.dart';

/// 对齐上游 ThemeSettings，阅读设置与外观设置共用同一份护眼参数。
class EyeProtectionSettings {
  const EyeProtectionSettings({
    this.enabled = false,
    this.intensity = 50,
    this.autoNight = false,
    this.schedule = false,
    this.startTime = '22:00',
    this.endTime = '07:00',
  });

  final bool enabled;
  final int intensity;
  final bool autoNight;
  final bool schedule;
  final String startTime;
  final String endTime;
  bool get configured => enabled || autoNight;

  EyeProtectionSettings copyWith({
    bool? enabled,
    int? intensity,
    bool? autoNight,
    bool? schedule,
    String? startTime,
    String? endTime,
  }) => EyeProtectionSettings(
    enabled: enabled ?? this.enabled,
    intensity: (intensity ?? this.intensity).clamp(0, 100),
    autoNight: autoNight ?? this.autoNight,
    schedule: schedule ?? this.schedule,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
  );

  static EyeProtectionSettings load(SharedPreferences prefs) =>
      EyeProtectionSettings(
        enabled: prefs.getBool('eyeProtectionEnabled') ?? false,
        intensity: (prefs.getInt('colorTemperature') ?? 50).clamp(0, 100),
        autoNight: prefs.getBool('eyeProtectionAutoNight') ?? false,
        schedule: prefs.getBool('eyeProtectionSchedule') ?? false,
        startTime: prefs.getString('eyeProtectionStartTime') ?? '22:00',
        endTime: prefs.getString('eyeProtectionEndTime') ?? '07:00',
      );

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setBool('eyeProtectionEnabled', enabled);
    await prefs.setInt('colorTemperature', intensity);
    await prefs.setBool('eyeProtectionAutoNight', autoNight);
    await prefs.setBool('eyeProtectionSchedule', schedule);
    await prefs.setString('eyeProtectionStartTime', startTime);
    await prefs.setString('eyeProtectionEndTime', endTime);
  }

  /// 手动开启或跟随深色模式后，定时时段才参与判定；不回写总开关。
  bool isActiveAt({required bool isDark, required DateTime now}) {
    if (!(enabled || (autoNight && isDark))) return false;
    if (!schedule) return true;
    final start = parseEyeProtectionTime(startTime);
    final end = parseEyeProtectionTime(endTime);
    if (start == null || end == null || start == end) return true;
    final minute = now.hour * 60 + now.minute;
    return start < end
        ? minute >= start && minute < end
        : minute >= start || minute < end;
  }
}

/// 配置以 HH:mm 保存；支持上游常见的阿拉伯和全角数字时间。
int? parseEyeProtectionTime(String value) {
  final normalized = value.trim().replaceAllMapped(RegExp('[٠-٩۰-۹０-９]'), (
    match,
  ) {
    final code = match[0]!.codeUnitAt(0);
    final zero = code >= 0xFF10
        ? 0xFF10
        : code >= 0x06F0
        ? 0x06F0
        : 0x0660;
    return '${code - zero}';
  });
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(normalized);
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  return hour < 24 && minute < 60 ? hour * 60 + minute : null;
}

const eyeProtectionIdentityMatrix = <double>[
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

/// 使用上游 EyeProtection 的 5500–2596 K 色温及 RGB 多项式系数。
List<double> eyeProtectionMatrix(int intensity) {
  if (intensity <= 0) return eyeProtectionIdentityMatrix;
  final temperature = (5500 - (5500 - 2596) * intensity.clamp(0, 100) / 100)
      .truncateToDouble();
  final squared = temperature * temperature;
  final green =
      squared * -9.623533e-9 + temperature * 1.5304548e-4 + 0.39078277;
  final blue = squared * -1.8935904e-8 + temperature * 3.024122e-4 - 0.1986509;
  return [1, 0, 0, 0, 0, 0, green, 0, 0, 0, 0, 0, blue, 0, 0, 0, 0, 0, 1, 0];
}
