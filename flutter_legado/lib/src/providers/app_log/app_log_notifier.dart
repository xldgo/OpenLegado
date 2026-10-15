import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../bridge/ffi.dart';
import '../app_log_repository_provider.dart';
import 'app_log_state.dart';

export 'app_log_state.dart';

/// 应用日志页 Riverpod Notifier
///
/// 仓储承担日志访问与响应解码，本层管理选中级别和操作状态。— Codex + UI
class AppLogNotifier extends Notifier<AppLogState> {
  /// 支持的日志级别（对齐 Android AppLog.LOG_MESSAGE/LOG_CRASH/LOG_HTTP）
  static const levels = ['message', 'crash', 'http'];

  @override
  AppLogState build() => const AppLogState();

  /// 加载指定级别的日志列表（最新在前，由 Rust 侧保证）
  Future<void> load(String level) async {
    state = state.copyWith(
      currentLevel: level,
      isLoading: true,
      clearError: true,
    );
    try {
      final list = await ref
          .read(appLogRepositoryProvider)
          .appLogList(level: level);
      state = state.copyWith(logs: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        logs: const [],
        isLoading: false,
        error: _mapError(e),
      );
    }
  }

  /// 清空当前级别的日志，成功后刷新列表
  Future<bool> clearCurrentLevel() async {
    final level = state.currentLevel;
    try {
      await ref.read(appLogRepositoryProvider).appLogClear(level: level);
      await load(level);
      return state.error == null;
    } catch (e) {
      state = state.copyWith(error: _mapError(e));
      return false;
    }
  }

  /// 清空全部级别日志（对齐 #543 清空确认后的 AppLog.clear + HttpLogStore.clear）
  Future<bool> clearAll() async {
    try {
      await ref.read(appLogRepositoryProvider).appLogClearAll();
      await load(state.currentLevel);
      return state.error == null;
    } catch (e) {
      state = state.copyWith(error: _mapError(e));
      return false;
    }
  }

  /// 导出全部日志为格式化文本（时间升序，Rust 侧 64_000 字符截断）
  Future<String> export() async {
    return ref.read(appLogRepositoryProvider).appLogExport();
  }

  /// 统一错误映射
  String _mapError(Object e) {
    if (e is BridgeError) return e.message;
    return e.toString();
  }
}

/// 应用日志 Notifier 全局 Provider
///
/// 使用方式：
/// ```dart
/// final state = ref.watch(appLogNotifierProvider);
/// ref.read(appLogNotifierProvider.notifier).load('message');
/// ```
final appLogNotifierProvider = NotifierProvider<AppLogNotifier, AppLogState>(
  AppLogNotifier.new,
);
