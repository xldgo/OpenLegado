import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/platform/privacy/privacy_platform.dart';
import 'package:flutter_legado/src/features/privacy/privacy_controller.dart';
import 'package:flutter_legado/src/features/privacy/privacy_settings.dart';

import 'privacy_controller_test.dart' show privacyContainer;

class TestPrivacyPlatform implements PrivacyPlatform {
  bool enrolled = false, accepted = true, cleared = false;
  @override
  bool get supportsPermissions => true;
  @override
  bool get supportsBatterySettings => false;
  @override
  Future<Map<String, dynamic>> capabilities() async => {
    'biometric': 'available',
    'enrolled': enrolled,
  };
  @override
  Future<bool> enrollBiometric() async {
    enrolled = accepted;
    return accepted;
  }

  @override
  Future<bool> authenticateBiometric() async => accepted && enrolled;
  @override
  Future<bool> clearBiometric() async {
    cleared = true;
    enrolled = false;
    return true;
  }

  @override
  Future<Map<String, dynamic>> permissions() async => {'notifications': true};
  @override
  Future<bool> openNotificationSettings() async => true;
  @override
  Future<bool> openBatterySettings() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('系统认证成功且凭据保存后才能开启，取消不授予权限', () async {
    final platform = TestPrivacyPlatform();
    final c = privacyContainer(platform: platform);
    addTearDown(c.dispose);
    final n = c.read(privacyControllerProvider.notifier);
    await n.initialize();
    await n.update(const PrivacySettings(enabled: true));
    await n.setBiometric(true);
    expect(c.read(privacyControllerProvider).biometricEnrolled, isTrue);
    platform.accepted = false;
    expect(await n.unlockBiometric(bookUrl: 'private'), isFalse);
    expect(c.read(privacyControllerProvider).unlocked, isFalse);
    platform.accepted = true;
    expect(await n.unlockBiometric(verifyOnly: true), isTrue);
    expect(c.read(privacyControllerProvider).unlocked, isFalse);
    expect(await n.unlockBiometric(bookUrl: 'private'), isTrue);
    expect(c.read(privacyControllerProvider).unlocked, isTrue);
    await n.changePassword('口令', '新口令');
    expect(platform.cleared, isTrue);
    expect(
      c.read(privacyControllerProvider).settings.biometricEnabled,
      isFalse,
    );
  });
}
