import '../../domain/models/app_log_entry.dart';

/// 应用日志页状态（不可变，copyWith 更新）
class AppLogState {
  /// 当前选中级别
  final String currentLevel;

  /// 当前级别的日志列表（最新在前，与 Rust 返回顺序一致）
  final List<AppLogEntry> logs;

  /// 是否正在加载
  final bool isLoading;

  /// 错误信息（null 表示无错误）
  final String? error;

  const AppLogState({
    this.currentLevel = 'message',
    this.logs = const [],
    this.isLoading = false,
    this.error,
  });

  AppLogState copyWith({
    String? currentLevel,
    List<AppLogEntry>? logs,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AppLogState(
      currentLevel: currentLevel ?? this.currentLevel,
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
