import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/models/auto_task.dart';
export '../../domain/models/auto_task.dart';

part 'auto_task_state.freezed.dart';

/// 定时任务页 UI 状态（immutable）
///
/// 职责边界（对齐旧 AutoTaskProvider）：
/// - [tasks]：任务列表与完整规则快照
/// - [isLoading]：列表加载状态
/// - [error]：错误信息（null 表示无错误）
@freezed
abstract class AutoTaskState with _$AutoTaskState {
  const factory AutoTaskState({
    /// 定时任务列表
    @Default([]) List<AutoTask> tasks,

    /// 是否正在加载任务列表
    @Default(false) bool isLoading,

    /// 错误信息（null 表示无错误）
    String? error,
  }) = _AutoTaskState;
}
