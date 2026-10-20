import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// [iOS 轨 P2-C] 锁屏控制 / Now Playing——对齐 Android MediaSessionBridge 的通道协议：
/// Flutter→Native: init / release / requestAudioFocus / abandonAudioFocus /
///   updatePlaybackState{state,position} / updateMetadata / updateArtwork /
///   setPlaying{playing} / setWakeLock{enabled}
/// Native→Flutter: onPlay / onPause / onSkipToNext / onSkipToPrevious / onStop /
///   onAudioFocusChange{gain|loss|lossTransient|lossTransientCanDuck}
///
/// iOS 无前台服务/WakeLock 概念（后台运行由 UIBackgroundModes=audio +
/// AppDelegate 的 AVAudioSession playback 类别保障），setWakeLock 为空实现。
/// 媒体进度使用毫秒协议，拖动回传当前书章与会话身份。
@objc class NowPlayingBridge: NSObject {
  static let shared = NowPlayingBridge()

  private var channel: FlutterMethodChannel?
  private var isPlaying = false
  private var commandsConfigured = false
  private var interruptionsObserved = false

  private override init() {
    super.init()
  }

  /// 在 AppDelegate 的引擎初始化回调中调用（进程内仅一次）
  func attach(messenger: FlutterBinaryMessenger) {
    guard channel == nil else { return }
    let ch = FlutterMethodChannel(name: "legado/media_session", binaryMessenger: messenger)
    ch.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    channel = ch
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "init":
      configureRemoteCommands()
      observeInterruptions()
      result(true)
    case "release":
      clearNowPlaying()
      result(nil)
    case "requestAudioFocus":
      // iOS 无竞争焦点模型：会话已在 AppDelegate 设为 playback，
      // 中断经 interruptionNotification 下发（见 observeInterruptions）
      result(true)
    case "takePendingOpen":
      // iOS由系统点击媒体面板打开应用，不接管系统页面跳转。
      result(nil)
    case "updateProgress":
      updateProgress(call.arguments as? [String: Any] ?? [:])
      result(nil)
    case "abandonAudioFocus":
      // 保持会话激活（退出后台继续播放），不做降激活
      result(nil)
    case "updatePlaybackState":
      let args = call.arguments as? [String: Any] ?? [:]
      let state = args["state"] as? String ?? "paused"
      let positionMs = (args["position"] as? NSNumber)?.intValue ?? 0
      updatePlaybackState(state: state, positionMs: positionMs)
      result(nil)
    case "updateMetadata":
      let args = call.arguments as? [String: Any] ?? [:]
      updateMetadata(
        title: args["title"] as? String ?? "",
        artist: args["artist"] as? String ?? "",
        album: args["album"] as? String ?? "",
        mediaId: args["mediaId"] as? String ?? "",
        sessionToken: (args["sessionToken"] as? NSNumber)?.int64Value ?? 0,
        timerText: args["timerText"] as? String ?? ""
      )
      result(nil)
    case "updateArtwork":
      let args = call.arguments as? [String: Any] ?? [:]
      updateArtwork(
        mediaId: args["mediaId"] as? String ?? "",
        sessionToken: (args["sessionToken"] as? NSNumber)?.int64Value ?? 0,
        bytes: (args["artworkBytes"] as? FlutterStandardTypedData)?.data
      )
      result(nil)
    case "setPlaying":
      let args = call.arguments as? [String: Any] ?? [:]
      isPlaying = args["playing"] as? Bool ?? false
      result(nil)
    case "setWakeLock":
      // iOS 无 WakeLock：后台保活由音频会话承担
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Now Playing 信息

  private var nowPlayingInfo: [String: Any] = [:]
  private var metadataMediaId: String?
  private var metadataSessionToken: Int64 = 0
  private var timelineChapter = -1
  private var timelineKnown = false
  private var timelinePosition = 0.0
  private var timelineDuration = 0.0
  private var timelineSpeed = 1.0
  private var timelineUpdatedAt = 0.0
  private var seekEnabled = false

  private func updatePlaybackState(state: String, positionMs: Int) {
    let now = ProcessInfo.processInfo.systemUptime
    let previousRate = nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0
    let elapsed = timelineKnown
      ? min(timelineDuration, timelinePosition + max(0, now - timelineUpdatedAt) * previousRate)
      : Double(positionMs) / 1000.0
    timelinePosition = elapsed
    timelineUpdatedAt = now
    switch state {
    case "playing":
      isPlaying = true
      nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = timelineSpeed
      nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
    case "paused", "buffering":
      isPlaying = false
      nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
      nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
    default: // stopped
      clearNowPlaying()
      return
    }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  private func updateMetadata(
    title: String, artist: String, album: String,
    mediaId: String, sessionToken: Int64, timerText: String
  ) {
    // 文字更新保留同一媒体封面，身份变化先去掉上一张图。— Codex + Bridge
    if metadataMediaId != mediaId || metadataSessionToken != sessionToken {
      nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyArtwork)
      nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyPlaybackDuration)
      timelineKnown = false
      seekEnabled = false
      MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = false
    }
    metadataMediaId = mediaId
    metadataSessionToken = sessionToken
    nowPlayingInfo[MPMediaItemPropertyTitle] = title
    nowPlayingInfo[MPMediaItemPropertyArtist] = artist
    nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
    // 定时不占用书名、章节或专辑字段；系统是否展示此辅助项由系统决定。
    nowPlayingInfo[MPMediaItemPropertyComments] = timerText
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  private func updateArtwork(mediaId: String, sessionToken: Int64, bytes: Data?) {
    guard metadataMediaId == mediaId, metadataSessionToken == sessionToken else { return }
    if let bytes = bytes {
      guard bytes.count <= 1024 * 1024,
            let image = UIImage(data: bytes),
            image.size.width > 0, image.size.width <= 384,
            image.size.height > 0, image.size.height <= 384 else { return }
      nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    } else {
      nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyArtwork)
    }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  private func updateProgress(_ args: [String: Any]) {
    guard let id = args["mediaId"] as? String,
          let token = args["sessionToken"] as? NSNumber,
          metadataMediaId == id, metadataSessionToken == token.int64Value,
          let chapter = args["chapterIndex"] as? NSNumber, chapter.intValue >= 0,
          let duration = args["duration"] as? NSNumber,
          let position = args["position"] as? NSNumber,
          let speed = args["speed"] as? NSNumber,
          speed.doubleValue.isFinite, speed.doubleValue > 0 else { return }
    timelineKnown = true
    timelineChapter = chapter.intValue
    timelineDuration = max(0, duration.doubleValue / 1000.0)
    timelinePosition = min(timelineDuration, max(0, position.doubleValue / 1000.0))
    timelineSpeed = speed.doubleValue
    timelineUpdatedAt = ProcessInfo.processInfo.systemUptime
    seekEnabled = timelineDuration > 0 && (args["canSeek"] as? Bool == true)
    let center = MPRemoteCommandCenter.shared()
    center.changePlaybackPositionCommand.isEnabled = seekEnabled
    center.previousTrackCommand.isEnabled = args["hasPrevious"] as? Bool == true
    center.nextTrackCommand.isEnabled = args["hasNext"] as? Bool == true
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = timelineDuration
    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = timelinePosition
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = args["state"] as? String == "playing" ? timelineSpeed : 0.0
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  private func clearNowPlaying() {
    isPlaying = false
    metadataMediaId = nil
    metadataSessionToken = 0
    timelineKnown = false
    seekEnabled = false
    timelineChapter = -1
    MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = false
    nowPlayingInfo.removeAll()
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }

  // MARK: - 远程命令（锁屏/控制中心/耳机线控）

  private func configureRemoteCommands() {
    guard !commandsConfigured else { return }
    commandsConfigured = true
    let center = MPRemoteCommandCenter.shared()

    center.playCommand.isEnabled = true
    center.playCommand.addTarget { [weak self] _ in
      self?.notifyFlutter("onPlay")
      return .success
    }
    center.pauseCommand.isEnabled = true
    center.pauseCommand.addTarget { [weak self] _ in
      self?.notifyFlutter("onPause")
      return .success
    }
    center.togglePlayPauseCommand.isEnabled = true
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.notifyFlutter(self?.isPlaying == true ? "onPause" : "onPlay")
      return .success
    }
    center.nextTrackCommand.isEnabled = true
    center.nextTrackCommand.addTarget { [weak self] _ in
      self?.notifyFlutter("onSkipToNext")
      return .success
    }
    center.previousTrackCommand.isEnabled = true
    center.previousTrackCommand.addTarget { [weak self] _ in
      self?.notifyFlutter("onSkipToPrevious")
      return .success
    }
    center.stopCommand.isEnabled = true
    center.stopCommand.addTarget { [weak self] _ in
      self?.notifyFlutter("onStop")
      return .success
    }
    center.changePlaybackPositionCommand.isEnabled = false
    center.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let self = self, self.seekEnabled,
            let id = self.metadataMediaId,
            let change = event as? MPChangePlaybackPositionCommandEvent,
            change.positionTime.isFinite, change.positionTime >= 0,
            change.positionTime < Double(Int64.max) / 1000 else { return .commandFailed }
      self.notifyFlutter("onSeekTo", [
        "mediaId": id, "sessionToken": self.metadataSessionToken,
        "chapterIndex": self.timelineChapter,
        "position": Int64(max(0, change.positionTime) * 1000.0),
      ])
      return .success
    }
  }

  // MARK: - 系统中断（来电/Siri）→ 焦点事件映射

  private func observeInterruptions() {
    guard !interruptionsObserved else { return }
    interruptionsObserved = true
    NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] notification in
      guard
        let info = notification.userInfo,
        let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
        let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
      else { return }
      switch type {
      case .began:
        self?.notifyFlutter("onAudioFocusChange", "lossTransient")
      case .ended:
        let optionRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        let options = AVAudioSession.InterruptionOptions(rawValue: optionRaw)
        self?.notifyFlutter(
          "onAudioFocusChange",
          options.contains(.shouldResume) ? "gain" : "loss"
        )
      @unknown default:
        break
      }
    }
  }

  // MARK: - Native → Flutter

  private func notifyFlutter(_ method: String, _ arguments: Any? = nil) {
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod(method, arguments: arguments)
    }
  }
}
