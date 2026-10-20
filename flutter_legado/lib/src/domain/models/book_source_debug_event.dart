/// 书源调试日志，state沿用Rust状态码。— Codex + Bridge
final class BookSourceDebugEvent {
  const BookSourceDebugEvent({required this.state, required this.message});
  final int state;
  final String message;
}
