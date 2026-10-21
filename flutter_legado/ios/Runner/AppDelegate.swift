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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReaderDisplayInsets") {
      let channel = FlutterMethodChannel(name: "legado/system_bar", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "getDisplayCutoutInsets" else {
          result(FlutterMethodNotImplemented); return
        }
        guard let window = UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .filter({ $0.activationState == .foregroundActive })
          .flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) else {
          result(nil); return
        }
        let safe = window.safeAreaInsets
        let scale = window.screen.scale
        // 公开安全区无法识别硬件轮廓；手机的底部/侧边安全区作为顶部缺口提示。
        // 普通无缺口手机的状态栏高度不当作刘海，iPad保留其公开侧边/底部安全区。
        let phoneCutout = UIDevice.current.userInterfaceIdiom == .phone &&
          (safe.bottom > 0 || safe.left > 0 || safe.right > 0)
        result([
          "width": window.bounds.width * scale, "height": window.bounds.height * scale,
          "left": safe.left * scale, "top": phoneCutout ? safe.top * scale : 0,
          "right": safe.right * scale, "bottom": safe.bottom * scale
        ])
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PrivacyBridge") {
      PrivacyBridge.shared.attach(messenger: registrar.messenger())
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
