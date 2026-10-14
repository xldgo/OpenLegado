import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 平台认证与权限能力，不持有阅读内容或应用密码。— Codex + UI
abstract interface class PrivacyPlatform {
  bool get supportsPermissions;
  bool get supportsBatterySettings;
  Future<Map<String, dynamic>> capabilities();
  Future<bool> enrollBiometric();
  Future<bool> authenticateBiometric();
  Future<bool> clearBiometric();
  Future<Map<String, dynamic>> permissions();
  Future<bool> openNotificationSettings();
  Future<bool> openBatterySettings();
}

final privacyPlatformProvider = Provider<PrivacyPlatform>(
  (ref) => const NativePrivacyPlatform(),
);
final privacyPermissionsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
      (ref) => ref.watch(privacyPlatformProvider).permissions(),
    );

class NativePrivacyPlatform implements PrivacyPlatform {
  const NativePrivacyPlatform();
  static const channel = MethodChannel('legado/privacy');
  @override
  bool get supportsPermissions => Platform.isAndroid || Platform.isIOS;
  @override
  bool get supportsBatterySettings => Platform.isAndroid;
  Future<bool> _call(String method) async =>
      await channel.invokeMethod<bool>(method) ?? false;
  Future<Map<String, dynamic>> _map(String method) async {
    final result = await channel.invokeMapMethod<String, dynamic>(method);
    if (result == null) throw StateError('平台未返回能力状态');
    return result;
  }

  @override
  Future<Map<String, dynamic>> capabilities() async => supportsPermissions
      ? await _map('capabilities')
      : {'biometric': 'unavailable', 'enrolled': false};
  @override
  Future<bool> enrollBiometric() =>
      supportsPermissions ? _call('enrollBiometric') : Future.value(false);
  @override
  Future<bool> authenticateBiometric() => supportsPermissions
      ? _call('authenticateBiometric')
      : Future.value(false);
  @override
  Future<bool> clearBiometric() =>
      supportsPermissions ? _call('clearBiometric') : Future.value(true);
  @override
  Future<Map<String, dynamic>> permissions() async =>
      supportsPermissions ? await _map('permissions') : {};
  @override
  Future<bool> openNotificationSettings() => supportsPermissions
      ? _call('openNotificationSettings')
      : Future.value(false);
  @override
  Future<bool> openBatterySettings() => supportsBatterySettings
      ? _call('openBatterySettings')
      : Future.value(false);
}
