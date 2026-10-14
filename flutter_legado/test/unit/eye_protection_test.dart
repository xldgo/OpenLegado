import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/theme/eye_protection.dart';
import 'package:flutter_legado/src/data/repositories/app_eye_protection_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 10, 13, hour, minute);

  test('色温矩阵对齐上游系数，保持透明度且限制强度范围', () {
    expect(eyeProtectionMatrix(0), eyeProtectionIdentityMatrix);
    expect(eyeProtectionMatrix(-1), eyeProtectionIdentityMatrix);
    expect(eyeProtectionMatrix(101), eyeProtectionMatrix(100));
    final matrix = eyeProtectionMatrix(50);
    expect(matrix[0], 1);
    expect(matrix[6], closeTo(0.8526167357, 0.000001));
    expect(matrix[12], closeTo(0.7152242061, 0.000001));
    expect(matrix[18], 1);
    expect(matrix[4], 0);
    expect(eyeProtectionMatrix(100)[12], lessThan(matrix[12]));
  });

  test('手动开关、跟随深色与定时独立，关掉手动仍可跟随深色', () {
    const disabled = EyeProtectionSettings();
    expect(disabled.isActiveAt(isDark: true, now: at(23)), isFalse);
    expect(
      disabled.copyWith(enabled: true).isActiveAt(isDark: false, now: at(12)),
      isTrue,
    );
    const automatic = EyeProtectionSettings(autoNight: true);
    expect(automatic.configured, isTrue);
    expect(automatic.isActiveAt(isDark: false, now: at(23)), isFalse);
    expect(automatic.isActiveAt(isDark: true, now: at(12)), isTrue);
    expect(
      automatic.copyWith(schedule: true).isActiveAt(isDark: true, now: at(12)),
      isFalse,
    );
    expect(
      automatic.copyWith(schedule: true).isActiveAt(isDark: true, now: at(23)),
      isTrue,
    );
  });

  test('跨午夜时段包含起点、排除终点', () {
    const settings = EyeProtectionSettings(enabled: true, schedule: true);
    for (final now in [at(22), at(23, 30), at(0, 30), at(6, 59)]) {
      expect(settings.isActiveAt(isDark: false, now: now), isTrue);
    }
    for (final now in [at(7), at(12), at(21, 59)]) {
      expect(settings.isActiveAt(isDark: false, now: now), isFalse);
    }
  });

  test('同日时段、相同时间和无效时间按上游规则处理', () {
    const settings = EyeProtectionSettings(
      enabled: true,
      schedule: true,
      startTime: '08:00',
      endTime: '18:00',
    );
    expect(settings.isActiveAt(isDark: false, now: at(8)), isTrue);
    expect(settings.isActiveAt(isDark: false, now: at(18)), isFalse);
    expect(
      settings.copyWith(endTime: '08:00').isActiveAt(isDark: false, now: at(3)),
      isTrue,
    );
    expect(
      settings
          .copyWith(startTime: 'invalid')
          .isActiveAt(isDark: false, now: at(3)),
      isTrue,
    );
    expect(parseEyeProtectionTime('24:00'), isNull);
    expect(parseEyeProtectionTime('22:60'), isNull);
    expect(parseEyeProtectionTime('٢٢:٠٠'), 1320);
    expect(parseEyeProtectionTime('０７:００'), 420);
  });

  test('重启保留护眼配置，定时判定不改写总开关', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = const EyeProtectionSettings().copyWith(
      enabled: true,
      intensity: 65,
      autoNight: true,
      schedule: true,
      startTime: '21:30',
      endTime: '06:45',
    );
    final service = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(service.dispose);
    final repository = AppEyeProtectionSettingsRepository(service);
    await repository.update(
      enabled: settings.enabled,
      intensity: settings.intensity,
      autoNight: settings.autoNight,
      schedule: settings.schedule,
      startTime: settings.startTime,
      endTime: settings.endTime,
    );
    await repository.reload();
    final loaded = repository.current;
    expect(loaded.enabled, isTrue);
    expect(loaded.intensity, 65);
    expect(loaded.autoNight, isTrue);
    expect(loaded.schedule, isTrue);
    expect(loaded.startTime, '21:30');
    expect(loaded.endTime, '06:45');
    expect(loaded.isActiveAt(isDark: true, now: at(12)), isFalse);
    expect(prefs.getBool('eyeProtectionEnabled'), isTrue);
  });
}
