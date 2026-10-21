import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../platform/display/display_corners.dart';

/// 普通页面统一边到边与透明系统栏，图标明暗跟随当前主题。
/// 阅读器显隐和退出恢复由SystemBarController独立协调。— Codex + UI
class SystemBarService {
  SystemBarService._();

  static const MethodChannel _channel = MethodChannel('legado/system_bar');

  static Future<DisplayCorners?> displayCorners(double pixelRatio) async {
    if (!Platform.isAndroid) return null;
    try {
      final data = await _channel.invokeMethod<Object?>('getDisplayCorners');
      return DisplayCorners.fromPhysical(data, pixelRatio);
    } catch (error) {
      debugPrint('读取屏幕圆角失败：$error');
      return null;
    }
  }

  /// Android 返回物理像素的底部屏幕缺口高度，不包含导航栏占位。
  static Future<double> displayCutoutBottomInset() async {
    if (!Platform.isAndroid) return 0;
    try {
      final bottom = await _channel.invokeMethod<num>(
        'getDisplayCutoutBottomInset',
      );
      return (bottom ?? 0).toDouble().clamp(0, double.infinity);
    } catch (error) {
      debugPrint('读取底部屏幕缺口失败: $error');
      return 0;
    }
  }

  /// 阅读页面独立控制显隐；原生前台恢复不再写入全局窗口设置。
  static Future<void> applyReader({
    required bool statusBarVisible,
    required bool navigationBarVisible,
  }) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('reader');
      } catch (e) {
        debugPrint('SystemBarService.applyReader 原生通道异常: $e');
      }
    }
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [
        if (statusBarVisible) SystemUiOverlay.top,
        if (navigationBarVisible) SystemUiOverlay.bottom,
      ],
    );
  }

  /// 普通页面恢复系统栏并按主题同步图标明暗。
  static Future<void> apply({
    required Color appBarColor,
    required Color navigationBarColor,
  }) async {
    final lightStatusBarIcons =
        ThemeData.estimateBrightnessForColor(appBarColor) == Brightness.light;

    final lightNavIcons =
        ThemeData.estimateBrightnessForColor(navigationBarColor) ==
        Brightness.light;

    if (Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      // iOS 退出阅读器也要恢复显示状态栏，不能只恢复图标配色。
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: lightStatusBarIcons
          ? Brightness.dark
          : Brightness.light,
      statusBarBrightness: lightStatusBarIcons
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: lightNavIcons
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );

    SystemChrome.setSystemUIOverlayStyle(overlayStyle);

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('apply', {
          'lightStatusBarIcons': lightStatusBarIcons,
          'lightNavigationBarIcons': lightNavIcons,
        });
      } catch (e) {
        debugPrint('SystemBarService.apply 原生通道异常: $e');
      }
    }
  }
}
