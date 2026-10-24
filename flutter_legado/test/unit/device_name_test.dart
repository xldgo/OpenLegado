import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/platform/device_name.dart';

class _DeviceInfo extends Fake implements DeviceInfoPlugin {
  _DeviceInfo(this.read);
  final Future<BaseDeviceInfo> Function() read;

  @override
  Future<BaseDeviceInfo> get deviceInfo => read();
}

class _AndroidInfo extends Fake implements AndroidDeviceInfo {
  _AndroidInfo(this.name);
  @override
  final String name;
}

class _IosInfo extends Fake implements IosDeviceInfo {
  _IosInfo(this.name);
  @override
  final String name;
}

void main() {
  test('直接使用插件设备名，保留iOS通用名称', () async {
    for (final (info, expected) in <(BaseDeviceInfo, String)>[
      (_AndroidInfo('我的手机'), '我的手机'),
      (_IosInfo('iPhone'), 'iPhone'),
    ]) {
      expect(
        await readSystemDeviceName(deviceInfo: _DeviceInfo(() async => info)),
        expected,
      );
    }
  });

  test('名称为空或平台读取失败时使用平台名', () async {
    expect(
      await readSystemDeviceName(
        deviceInfo: _DeviceInfo(() async => _AndroidInfo('')),
      ),
      Platform.operatingSystem,
    );
    expect(
      await readSystemDeviceName(
        deviceInfo: _DeviceInfo(
          () async => throw PlatformException(code: 'unavailable'),
        ),
      ),
      Platform.operatingSystem,
    );
  });
}
