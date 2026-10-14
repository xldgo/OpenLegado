/// 对齐上游 ThemeSettings，阅读设置与外观设置共用同一份护眼参数。
final class EyeProtectionSettings {
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

  @override
  bool operator ==(Object other) =>
      other is EyeProtectionSettings &&
      enabled == other.enabled &&
      intensity == other.intensity &&
      autoNight == other.autoNight &&
      schedule == other.schedule &&
      startTime == other.startTime &&
      endTime == other.endTime;
  @override
  int get hashCode =>
      Object.hash(enabled, intensity, autoNight, schedule, startTime, endTime);

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
