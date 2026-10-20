import Flutter
import LocalAuthentication
import Security
import UIKit
import UserNotifications

/// 快捷解锁由当前生物信息绑定的 Keychain 项控制。— Codex + UI
final class PrivacyBridge {
  static let shared = PrivacyBridge()
  private let service = "openlegado.privacy.biometric"
  private let token = Data("OpenLegadoPrivacyCredential".utf8)
  private var pending = false
  private var channel: FlutterMethodChannel?
  private var query: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: service, kSecAttrAccount as String: "unlock"]
  }
  func attach(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "legado/privacy", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
  }
  private func status() -> String {
    let context = LAContext()
    var error: NSError?
    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) { return "available" }
    switch error?.code {
    case LAError.biometryNotEnrolled.rawValue: return "notEnrolled"
    case LAError.biometryNotAvailable.rawValue: return "noHardware"
    default: return "unavailable"
    }
  }
  private func clear() -> Bool {
    let value = SecItemDelete(query as CFDictionary)
    return value == errSecSuccess || value == errSecItemNotFound
  }
  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "capabilities":
      var lookup = query
      lookup[kSecReturnAttributes as String] = true
      lookup[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
      let code = SecItemCopyMatching(lookup as CFDictionary, nil)
      result(["biometric": status(), "enrolled": code == errSecSuccess || code == errSecInteractionNotAllowed])
    case "clearBiometric": result(clear())
    case "enrollBiometric": authenticate(enroll: true, result: result)
    case "authenticateBiometric": authenticate(enroll: false, result: result)
    case "permissions":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        DispatchQueue.main.async { result(["notifications": settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional]) }
      }
    case "openNotificationSettings":
      guard let url = URL(string: UIApplication.openSettingsURLString) else { result(false); return }
      UIApplication.shared.open(url, options: [:]) { result($0) }
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func authenticate(enroll: Bool, result: @escaping FlutterResult) {
    guard !pending, status() == "available" else { result(false); return }
    pending = true
    DispatchQueue.global(qos: .userInitiated).async {
      var success = false
      if enroll {
        guard self.clear(), let access = SecAccessControlCreateWithFlags(nil,
          kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .biometryCurrentSet, nil) else {
          DispatchQueue.main.async { self.pending = false; result(false) }; return
        }
        var item = self.query
        item[kSecAttrAccessControl as String] = access
        item[kSecValueData as String] = self.token
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
          DispatchQueue.main.async { self.pending = false; result(false) }; return
        }
      }
      let context = LAContext()
      context.localizedFallbackTitle = ""
      context.localizedCancelTitle = "使用隐私密码"
      context.touchIDAuthenticationAllowableReuseDuration = 0
      var lookup = self.query
      lookup[kSecReturnData as String] = true
      lookup[kSecUseAuthenticationContext as String] = context
      lookup[kSecUseOperationPrompt as String] = "验证后查看私密内容"
      var data: CFTypeRef?
      if SecItemCopyMatching(lookup as CFDictionary, &data) == errSecSuccess,
         let value = data as? Data { success = value == self.token }
      if !success && enroll { _ = self.clear() }
      DispatchQueue.main.async { self.pending = false; result(success) }
    }
  }
}
