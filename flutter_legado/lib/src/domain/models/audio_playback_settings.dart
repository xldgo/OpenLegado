/// 音频播放普通设置的类型化快照，存储键仅由数据层解释。— Codex + UI
final class AudioPlaybackSettings {
  const AudioPlaybackSettings({
    this.wakeLock = false,
    this.openCredits = 0,
    this.closeCredits = 0,
  });
  final bool wakeLock;
  final int openCredits;
  final int closeCredits;
  AudioPlaybackSettings copyWith({
    bool? wakeLock,
    int? openCredits,
    int? closeCredits,
  }) => AudioPlaybackSettings(
    wakeLock: wakeLock ?? this.wakeLock,
    openCredits: openCredits ?? this.openCredits,
    closeCredits: closeCredits ?? this.closeCredits,
  );
}
