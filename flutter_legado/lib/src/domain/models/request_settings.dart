/// 通用网络任务并发快照；与Rust契约使用相同范围。— Codex + UI
final class RequestSettings {
  const RequestSettings({this.threadCount = defaultThreadCount});
  static const defaultThreadCount = 16;
  static const minThreadCount = 1;
  static const maxThreadCount = 256;
  final int threadCount;
  RequestSettings copyWith({int? threadCount}) =>
      RequestSettings(threadCount: threadCount ?? this.threadCount);
}
