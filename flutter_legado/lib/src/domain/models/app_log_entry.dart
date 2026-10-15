// 日志共享模型不依赖Provider或界面组件。— Codex + Bridge
/// 单条应用日志（字段对齐 Rust log_api 返回：timestamp/level/message）
final class AppLogEntry {
  /// 时间戳（毫秒）
  final int timestamp;

  /// 日志级别：`message` / `crash` / `http`
  final String level;

  /// 日志内容
  final String message;

  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  /// 由仓储验证结构后解析既有Rust响应。
  factory AppLogEntry.fromJson(Map<String, dynamic> json) {
    return AppLogEntry(
      timestamp: json['timestamp'] as int,
      level: json['level'] as String,
      message: json['message'] as String,
    );
  }

  /// 时间显示（HH:mm:ss.SSS）
  String get timeText {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}.'
        '${dt.millisecond.toString().padLeft(3, '0')}';
  }
}
