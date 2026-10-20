import 'read_aloud_content.dart';

/// 朗读普通偏好的不可变领域模型，不包含 Provider 或存储细节。— Codex + UI
final class ReadAloudSettings {
  const ReadAloudSettings({
    this.splitMode = ReadAloudSplitMode.paragraph,
    this.splitSymbols = defaultReadAloudSplitSymbols,
    this.followSystem = true,
    this.detachReminder = true,
    this.mediaButtonPerNext = true,
    this.manualSpeed = 1,
    this.paragraphIntervalMs = 0,
    this.audioPreDownloadNum = 3,
    this.ttsPreSynthesisConcurrency = 3,
    this.audioCacheCleanTime = 10,
    this.hasStoredManualSpeed = false,
  });

  final ReadAloudSplitMode splitMode;
  final String splitSymbols;
  final bool followSystem;
  final bool detachReminder;
  final bool mediaButtonPerNext;
  final double manualSpeed;
  final int paragraphIntervalMs;
  final int audioPreDownloadNum;
  final int ttsPreSynthesisConcurrency;
  final int audioCacheCleanTime;
  final bool hasStoredManualSpeed;

  /// 跟随系统语速时使用标准倍率，不读取平台设置中的滑块值。
  double get effectiveSpeed => followSystem ? 1 : manualSpeed;

  ReadAloudSettings copyWith({
    ReadAloudSplitMode? splitMode,
    String? splitSymbols,
    bool? followSystem,
    bool? detachReminder,
    bool? mediaButtonPerNext,
    double? manualSpeed,
    int? paragraphIntervalMs,
    int? audioPreDownloadNum,
    int? ttsPreSynthesisConcurrency,
    int? audioCacheCleanTime,
    bool? hasStoredManualSpeed,
  }) => ReadAloudSettings(
    splitMode: splitMode ?? this.splitMode,
    splitSymbols: splitSymbols ?? this.splitSymbols,
    followSystem: followSystem ?? this.followSystem,
    detachReminder: detachReminder ?? this.detachReminder,
    mediaButtonPerNext: mediaButtonPerNext ?? this.mediaButtonPerNext,
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
      splitMode == other.splitMode &&
      splitSymbols == other.splitSymbols &&
      followSystem == other.followSystem &&
      detachReminder == other.detachReminder &&
      mediaButtonPerNext == other.mediaButtonPerNext &&
      manualSpeed == other.manualSpeed &&
      paragraphIntervalMs == other.paragraphIntervalMs &&
      audioPreDownloadNum == other.audioPreDownloadNum &&
      ttsPreSynthesisConcurrency == other.ttsPreSynthesisConcurrency &&
      audioCacheCleanTime == other.audioCacheCleanTime &&
      hasStoredManualSpeed == other.hasStoredManualSpeed;

  @override
  int get hashCode => Object.hash(
    splitMode,
    splitSymbols,
    followSystem,
    detachReminder,
    mediaButtonPerNext,
    manualSpeed,
    paragraphIntervalMs,
    audioPreDownloadNum,
    ttsPreSynthesisConcurrency,
    audioCacheCleanTime,
    hasStoredManualSpeed,
  );
}
