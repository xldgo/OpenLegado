/// 自动翻页偏好；计时器由阅读会话管理。— Codex + UI
final class ReaderAutoPageTurnSettings {
  const ReaderAutoPageTurnSettings({
    this.enabled = false,
    this.intervalSeconds = 10,
    this.forward = true,
  });

  final bool enabled;
  final double intervalSeconds;
  final bool forward;

  @override
  bool operator ==(Object other) =>
      other is ReaderAutoPageTurnSettings &&
      enabled == other.enabled &&
      intervalSeconds == other.intervalSeconds &&
      forward == other.forward;

  @override
  int get hashCode => Object.hash(enabled, intervalSeconds, forward);
}
