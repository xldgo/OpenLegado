import AVFoundation
import CryptoKit
import Darwin
import Flutter
import UIKit

/// 被动取证，不访问播放器私有状态，也不改变音频会话。— Codex + Bridge
final class ReadAloudDiagnostics: NSObject {
  static let shared = ReadAloudDiagnostics()
  private var channel: FlutterMethodChannel?
  private var observers: [NSObjectProtocol] = []
  private var events: [[String: Any]] = []
  private var dropped = 0
  private var enabled = false
  private var generation = 0
  private var previousCPU: Double?
  private var previousWall: Double?
  private var batteryMonitoringWasEnabled = false

  func attach(messenger: FlutterBinaryMessenger) {
    guard channel == nil else { return }
    let channel = FlutterMethodChannel(name: "legado/read_aloud_diagnostics", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "setEnabled":
        self.setEnabled(args["enabled"] as? Bool ?? false)
        result(nil)
      case "drain":
        let captured = self.events
        let lost = self.dropped
        self.events.removeAll(keepingCapacity: true)
        self.dropped = 0
        var reply: [String: Any] = ["events": captured, "dropped": lost]
        if self.enabled && args["sample"] as? Bool == true { reply["sample"] = self.sample() }
        result(reply)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  private func setEnabled(_ value: Bool) {
    guard value != enabled else { return }
    generation += 1
    enabled = value
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    observers.removeAll()
    if !value {
      UIDevice.current.isBatteryMonitoringEnabled = batteryMonitoringWasEnabled
      return
    }
    events.removeAll(keepingCapacity: true)
    dropped = 0
    previousCPU = nil
    previousWall = nil
    batteryMonitoringWasEnabled = UIDevice.current.isBatteryMonitoringEnabled
    UIDevice.current.isBatteryMonitoringEnabled = true
    // 必须先读取热状态，再订阅其变更。
    _ = ProcessInfo.processInfo.thermalState
    let capture = generation
    let names: [(Notification.Name, String)] = [
      (AVPlayerItem.timeJumpedNotification, "item.time_jump"),
      (AVPlayerItem.didPlayToEndTimeNotification, "item.ended"),
      (AVPlayerItem.playbackStalledNotification, "item.stalled"),
      (AVPlayerItem.failedToPlayToEndTimeNotification, "item.failed"),
      (AVAudioSession.interruptionNotification, "audio.interruption"),
      (AVAudioSession.routeChangeNotification, "audio.route_change"),
      (AVAudioSession.mediaServicesWereResetNotification, "audio.services_reset"),
      (ProcessInfo.thermalStateDidChangeNotification, "device.thermal_change")
    ]
    for (name, label) in names {
      // 通知可能来自后台线程，在回调处记录原生时间与位置，再汇入主线程有界缓冲。
      observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] note in
        var entry: [String: Any] = [
          "event": label,
          "wallMs": Date().timeIntervalSince1970 * 1000,
          "uptimeMs": ProcessInfo.processInfo.systemUptime * 1000
        ]
        if label == "device.thermal_change" {
          entry["thermalState"] = ProcessInfo.processInfo.thermalState.rawValue
        }
        if let item = note.object as? AVPlayerItem {
          entry["item"] = String(describing: ObjectIdentifier(item))
          let seconds = item.currentTime().seconds
          if seconds.isFinite { entry["positionMs"] = seconds * 1000 }
          entry["status"] = item.status.rawValue
          entry["bufferEmpty"] = item.isPlaybackBufferEmpty
          entry["likelyToKeepUp"] = item.isPlaybackLikelyToKeepUp
          if let url = (item.asset as? AVURLAsset)?.url {
            let digest = SHA256.hash(data: Data(url.lastPathComponent.utf8))
            entry["file"] = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
          }
        }
        if let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber {
          entry["routeReason"] = reason
        }
        if let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber {
          entry["interruptionType"] = type
        }
        if let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber {
          entry["interruptionOptions"] = options
        }
        let payload = entry
        DispatchQueue.main.async {
          guard let self = self, self.enabled, self.generation == capture else { return }
          if self.events.count >= 256 { self.dropped += 1; return }
          self.events.append(payload)
        }
      })
    }
  }

  private func sample() -> [String: Any] {
    let info = ProcessInfo.processInfo
    var usage = rusage()
    let ok = getrusage(RUSAGE_SELF, &usage) == 0
    let cpu = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
      + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    let wall = info.systemUptime
    var data: [String: Any] = [
      "thermalState": info.thermalState.rawValue,
      "lowPowerMode": info.isLowPowerModeEnabled,
      "batteryLevel": UIDevice.current.batteryLevel,
      "batteryState": UIDevice.current.batteryState.rawValue,
      "applicationState": UIApplication.shared.applicationState.rawValue,
      "processorCount": info.activeProcessorCount
    ]
    if ok {
      data["cpuSeconds"] = cpu
      if let lastCPU = previousCPU, let lastWall = previousWall, wall > lastWall {
        // 单核100%口径，可超过100%；不是整机耗电或电池温度。
        data["cpuPercentOneCore"] = max(0, (cpu - lastCPU) / (wall - lastWall) * 100)
        data["intervalSeconds"] = wall - lastWall
      }
      previousCPU = cpu
      previousWall = wall
    }
    return data
  }
}
