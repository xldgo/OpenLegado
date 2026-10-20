import 'package:flutter/foundation.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// 阅读亮度控制，两端共用应用亮度接口，不修改系统自动亮度开关。
class SystemBrightness {
  static final _brightness = ScreenBrightness();

  static Future<double> getBrightness() async =>
      (await _brightness.application).clamp(0.0, 1.0);

  /// 操作失败交由界面提示，不把失败当作已生效。
  static Future<void> setBrightness(double brightness) =>
      _brightness.setApplicationScreenBrightness(brightness.clamp(0.0, 1.0));

  static Future<bool> isSupported() async {
    try {
      await getBrightness();
      return true;
    } catch (e) {
      debugPrint('应用亮度不可用: $e');
      return false;
    }
  }

  /// 未设置应用亮度覆盖时，亮度由设备系统管理。
  static Future<bool> isFollowingSystem() async =>
      !await _brightness.hasApplicationScreenBrightnessChanged;

  static Future<void> setFollowSystem(bool followSystem) async {
    if (followSystem) {
      await _brightness.resetApplicationScreenBrightness();
    } else {
      // 从当前亮度开始手动调节，切换模式时不跳变。
      await setBrightness(await getBrightness());
    }
  }

  static Stream<double> get changes =>
      _brightness.onApplicationScreenBrightnessChanged;
}
