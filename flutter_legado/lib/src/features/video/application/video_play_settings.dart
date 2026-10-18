import 'package:shared_preferences/shared_preferences.dart';

/// 视频播放设置（对标原版 `ui/video/config/SettingsDialog` + `VideoPlay` prefs）
class VideoPlaySettings {
  static const _ns = 'videoPlay';
  static const autoPlayKey = '$_ns.autoPlay';
  static const startFullKey = '$_ns.startFull';
  static const longPressSpeedKey = '$_ns.longPressSpeed';
  static const fullBottomProgressKey = '$_ns.fullBottomProgressBar';
  static const defaultFloatWindowKey = '$_ns.defaultFloatWindow';

  bool autoPlay;
  bool startFull;

  /// 原版存 5–60 整数，实际倍速 = value / 10
  int longPressSpeed;
  bool fullBottomProgressBar;

  /// [V-B3] 默认悬浮窗播放（对齐原版 VideoPlay.defaultFloatWindow /
  /// SettingsDialog.kt:26,30 的 cbDefaultFloatWindow；默认 false 同原版）
  bool defaultFloatWindow;

  VideoPlaySettings({
    this.autoPlay = true,
    this.startFull = false,
    this.longPressSpeed = 30,
    this.fullBottomProgressBar = true,
    this.defaultFloatWindow = false,
  });

  double get pressSpeedFactor => longPressSpeed / 10.0;

  static Future<VideoPlaySettings> load() async {
    final p = await SharedPreferences.getInstance();
    return VideoPlaySettings(
      autoPlay: p.getBool(autoPlayKey) ?? true,
      startFull: p.getBool(startFullKey) ?? false,
      longPressSpeed: p.getInt(longPressSpeedKey) ?? 30,
      fullBottomProgressBar: p.getBool(fullBottomProgressKey) ?? true,
      defaultFloatWindow: p.getBool(defaultFloatWindowKey) ?? false,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(autoPlayKey, autoPlay);
    await p.setBool(startFullKey, startFull);
    await p.setInt(longPressSpeedKey, longPressSpeed);
    await p.setBool(fullBottomProgressKey, fullBottomProgressBar);
    await p.setBool(defaultFloatWindowKey, defaultFloatWindow);
  }
}
