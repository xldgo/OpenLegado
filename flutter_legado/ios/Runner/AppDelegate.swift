import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 按通知插件接线要求，将前台通知呈现交由 FlutterAppDelegate 分发。
    UNUserNotificationCenter.current().delegate = self
    // 播放与 Web 保活按需通过 AppAudioSession 激活，不在启动时抢占其他音频。
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PrivacyBridge") {
      PrivacyBridge.shared.attach(messenger: registrar.messenger())
    }
    // [iOS 轨 P2-C] 注册锁屏控制通道（legado/media_session，协议对齐
    // Android MediaSessionBridge.kt）。registry 协议仅暴露 registrar，
    // messenger 经 registrar 取（FlutterPlugin.h FlutterBaseRegistrar）。
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NowPlayingBridge") {
      NowPlayingBridge.shared.attach(messenger: registrar.messenger())
    }
    // 运行时更换桌面图标（对齐原版 change_icon；iOS setAlternateIconName）
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LauncherIconBridge") {
      LauncherIconBridge.shared.attach(messenger: registrar.messenger())
    }
    // [2026-10-07 | iOS Web 服务后台保活] 注册近静音音频会话保活通道
    //（legado/web_keepalive；对应原版 WebService WakeLock 的「防睡眠」目的）
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WebKeepAlive") {
      WebKeepAlive.shared.attach(messenger: registrar.messenger())
    }
  }
}
