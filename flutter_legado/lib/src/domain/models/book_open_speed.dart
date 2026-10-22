/// 封面开合时长，独立于正文翻页速度。— Codex + UI
enum BookOpenSpeed {
  fast(320, 270),
  standard(420, 350),
  relaxed(560, 470);

  const BookOpenSpeed(this.openMilliseconds, this.closeMilliseconds);
  final int openMilliseconds;
  final int closeMilliseconds;

  Duration get openDuration => Duration(milliseconds: openMilliseconds);
  Duration get closeDuration => Duration(milliseconds: closeMilliseconds);

  static BookOpenSpeed fromStorage(Object? value) =>
      BookOpenSpeed.values.where((speed) => speed.name == value).firstOrNull ??
      BookOpenSpeed.standard;
}
