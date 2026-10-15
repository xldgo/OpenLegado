/// 阅读状态条的可见信息，与系统状态栏和页眉页脚分别管理。— Codex + UI
final class ReaderStatusStripSettings {
  const ReaderStatusStripSettings({
    this.showBattery = false,
    this.showTime = false,
    this.showProgress = false,
    this.showChapterName = false,
  });

  final bool showBattery;
  final bool showTime;
  final bool showProgress;
  final bool showChapterName;

  @override
  bool operator ==(Object other) =>
      other is ReaderStatusStripSettings &&
      showBattery == other.showBattery &&
      showTime == other.showTime &&
      showProgress == other.showProgress &&
      showChapterName == other.showChapterName;

  @override
  int get hashCode =>
      Object.hash(showBattery, showTime, showProgress, showChapterName);
}
