import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/contracts/auto_task_repository.dart';
import '../../../domain/contracts/auto_task_service.dart';
import '../../../models/misc.dart';
import '../../../providers/auto_task/auto_task_dependencies.dart';
import 'auto_task_state.dart';

export 'auto_task_state.dart';

/// 管理任务界面状态，规则与执行分别委托窄接口。— Codex + UI
class AutoTaskNotifier extends Notifier<AutoTaskState> {
  AutoTaskRepository get _repository => ref.read(autoTaskRepositoryProvider);
  AutoTaskService get _service => ref.read(autoTaskServiceProvider);

  @override
  AutoTaskState build() => const AutoTaskState();

  Future<void> loadTasks({bool silent = false}) async {
    if (!silent) state = state.copyWith(isLoading: true, error: null);
    try {
      final rules = await _repository.listRules();
      state = state.copyWith(
        tasks: rules.map(AutoTask.fromRule).toList(),
        error: null,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: '加载任务失败: $e', isLoading: false);
    }
  }

  Future<bool> createTask(AutoTask task) => createRule(task.toRule());

  Future<bool> createRule(AutoTaskRule rule) async {
    try {
      await _repository.createRule(rule);
      await loadTasks(silent: true);
      return true;
    } catch (e) {
      state = state.copyWith(error: '创建任务失败: $e');
      return false;
    }
  }

  Future<bool> updateRule(AutoTaskRule rule) async {
    if (rule.id.isEmpty) {
      state = state.copyWith(error: '更新任务失败: 缺少任务 id');
      return false;
    }
    try {
      await _repository.updateRule(rule);
      await loadTasks(silent: true);
      return true;
    } catch (e) {
      state = state.copyWith(error: '更新任务失败: $e');
      return false;
    }
  }

  /// 乐观启停只改enable，写入失败恢复原列表。
  Future<void> toggleTask(String id, bool enabled) async {
    final previous = state.tasks;
    state = state.copyWith(
      tasks: previous
          .map(
            (task) => task.id == id ? task.copyWith(isEnabled: enabled) : task,
          )
          .toList(),
    );
    try {
      final task = state.tasks.firstWhere((task) => task.id == id);
      await _repository.updateRule(task.toRule());
      await loadTasks(silent: true);
    } catch (e) {
      state = state.copyWith(tasks: previous, error: '更新任务失败: $e');
    }
  }

  Future<bool> deleteTask(String id) async {
    try {
      await _repository.deleteRule(id);
      await loadTasks(silent: true);
      return true;
    } catch (e) {
      state = state.copyWith(error: '删除任务失败: $e');
      return false;
    }
  }

  /// 保留当前立即执行协议；真实执行协议缺口另行处理。
  Future<void> runNow(String id) async {
    try {
      final task = state.tasks.where((task) => task.id == id).firstOrNull;
      final result = await _service.execute(
        protocol: {'action': task?.taskType ?? 'noop', 'taskId': id},
        taskId: id,
      );
      state = state.copyWith(
        tasks: state.tasks
            .map(
              (task) => task.id == id
                  ? task.copyWith(
                      lastRunAt: _formatNow(),
                      lastResult: result.success ? '成功' : '失败',
                    )
                  : task,
            )
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: '运行任务失败: $e');
    }
  }

  String _formatNow() {
    final dt = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  Future<AutoTaskRule?> buildBookUpdateTask({
    required String bookUrl,
    required String bookName,
    required String bookAuthor,
    required String name,
  }) async {
    try {
      return await _service.buildBookUpdateTask(
        bookUrl: bookUrl,
        bookName: bookName,
        bookAuthor: bookAuthor,
        name: name,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<AutoTaskRule>?> updateCronBatch({
    required List<AutoTaskRule> rules,
    required List<String> ids,
    required String cron,
  }) async {
    try {
      return await _service.updateCronBatch(rules: rules, ids: ids, cron: cron);
    } catch (_) {
      return null;
    }
  }

  Future<List<AutoTaskRule>?> prepareImportedTasks({
    required List<AutoTaskRule> localTasks,
    required String importedJson,
  }) async {
    try {
      return await _service.prepareImportedTasks(
        localTasks: localTasks,
        importedJson: importedJson,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> normalizeScript(String script) async {
    try {
      return await _service.normalizeScript(script);
    } catch (_) {
      return null;
    }
  }

  Future<bool?> canRefreshBookToc({
    required bool canUpdate,
    required bool respectCanUpdate,
  }) async {
    try {
      return await _service.canRefreshBookToc(
        canUpdate: canUpdate,
        respectCanUpdate: respectCanUpdate,
      );
    } catch (_) {
      return null;
    }
  }

  Future<AutoTaskRule?> findBookUpdateTask({
    required String bookUrl,
    required String bookName,
    required String bookAuthor,
  }) async {
    List<AutoTaskRule> rules;
    try {
      rules = await _repository.listRules();
    } catch (_) {
      rules = state.tasks.map((task) => task.toRule()).toList();
    }
    try {
      return await _service.findBookUpdateTask(
        tasks: rules,
        bookUrl: bookUrl,
        bookName: bookName,
        bookAuthor: bookAuthor,
      );
    } catch (_) {
      return null;
    }
  }

  Future<int?> nextDueAt({required String cron, int? fromMs}) async {
    try {
      return await _service.nextDueAt(
        cron: cron,
        fromMs: fromMs ?? DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }
}

final autoTaskNotifierProvider =
    NotifierProvider<AutoTaskNotifier, AutoTaskState>(AutoTaskNotifier.new);
