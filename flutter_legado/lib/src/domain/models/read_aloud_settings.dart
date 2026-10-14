/// 朗读普通偏好的不可变领域模型，不包含 Provider 或存储细节。— Codex + UI
final class ReadAloudSettings {
  const ReadAloudSettings({
    this.followSystem = true,
    this.detachReminder = true,
    this.manualSpeed = 1,
    this.paragraphIntervalMs = 0,
    this.audioPreDownloadNum = 10,
    this.ttsPreSynthesisConcurrency = 3,
    this.audioCacheCleanTime = 10,
    this.hasStoredManualSpeed = false,
  });

  final bool followSystem;
  final bool detachReminder;
  final double manualSpeed;
  final int paragraphIntervalMs;
  final int audioPreDownloadNum;
  final int ttsPreSynthesisConcurrency;
  final int audioCacheCleanTime;
  final bool hasStoredManualSpeed;

  /// 跟随系统语速时使用标准倍率，不读取平台设置中的滑块值。
  double get effectiveSpeed => followSystem ? 1 : manualSpeed;

  ReadAloudSettings copyWith({
    bool? followSystem,
    bool? detachReminder,
    double? manualSpeed,
    int? paragraphIntervalMs,
    int? audioPreDownloadNum,
    int? ttsPreSynthesisConcurrency,
    int? audioCacheCleanTime,
    bool? hasStoredManualSpeed,
  }) => ReadAloudSettings(
    followSystem: followSystem ?? this.followSystem,
    detachReminder: detachReminder ?? this.detachReminder,
    manualSpeed: manualSpeed ?? this.manualSpeed,
    paragraphIntervalMs: paragraphIntervalMs ?? this.paragraphIntervalMs,
    audioPreDownloadNum: audioPreDownloadNum ?? this.audioPreDownloadNum,
    ttsPreSynthesisConcurrency:
        ttsPreSynthesisConcurrency ?? this.ttsPreSynthesisConcurrency,
    audioCacheCleanTime: audioCacheCleanTime ?? this.audioCacheCleanTime,
    hasStoredManualSpeed: hasStoredManualSpeed ?? this.hasStoredManualSpeed,
  );

  @override
  bool operator ==(Object other) =>
      other is ReadAloudSettings &&
      followSystem == other.followSystem &&
      detachReminder == other.detachReminder &&
      manualSpeed == other.manualSpeed &&
      paragraphIntervalMs == other.paragraphIntervalMs &&
      audioPreDownloadNum == other.audioPreDownloadNum &&
      ttsPreSynthesisConcurrency == other.ttsPreSynthesisConcurrency &&
      audioCacheCleanTime == other.audioCacheCleanTime &&
      hasStoredManualSpeed == other.hasStoredManualSpeed;

  @override
  int get hashCode => Object.hash(
    followSystem,
    detachReminder,
    manualSpeed,
    paragraphIntervalMs,
    audioPreDownloadNum,
    ttsPreSynthesisConcurrency,
    audioCacheCleanTime,
    hasStoredManualSpeed,
  );
}
