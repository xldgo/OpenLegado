import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

/// 设备名仅作可读标签，备份归属继续使用独立安装标识。— Codex + UI
Future<String> readSystemDeviceName({DeviceInfoPlugin? deviceInfo}) async {
  try {
    final info = await (deviceInfo ?? DeviceInfoPlugin()).deviceInfo;
    final name = switch (info) {
      AndroidDeviceInfo(:final name) => name,
      IosDeviceInfo(:final name) => name,
      MacOsDeviceInfo(:final computerName) => computerName,
      WindowsDeviceInfo(:final computerName) => computerName,
      _ => Platform.localHostname,
    };
    if (name.trim().isNotEmpty) return name.trim();
  } on MissingPluginException {
    // 平台信息不可用不阻断备份。
  } on PlatformException {
    // 保留平台名作为可读回退。
  } on SocketException {
    // 桌面主机名不可用时同样回退平台名。
  }
  return Platform.operatingSystem;
}
