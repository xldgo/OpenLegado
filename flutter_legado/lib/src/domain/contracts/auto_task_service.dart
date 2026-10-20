import '../../models/misc.dart';
import '../models/auto_task_execution_result.dart';

/// 任务计算与执行，不持有页面状态或调度Timer。— Codex + Bridge
abstract interface class AutoTaskService {
  Future<AutoTaskRule> buildBookUpdateTask({
    required String bookUrl,
    required String bookName,
    required String bookAuthor,
    required String name,
  });
  Future<List<AutoTaskRule>> updateCronBatch({
    required List<AutoTaskRule> rules,
    required List<String> ids,
    required String cron,
  });
  Future<List<AutoTaskRule>> prepareImportedTasks({
    required List<AutoTaskRule> localTasks,
    required String importedJson,
  });
  Future<AutoTaskExecutionResult> execute({
    required Map<String, dynamic> protocol,
    String? taskId,
  });
  Future<String> normalizeScript(String script);
  Future<bool> canRefreshBookToc({
    required bool canUpdate,
    required bool respectCanUpdate,
  });
  Future<AutoTaskRule?> findBookUpdateTask({
    required List<AutoTaskRule> tasks,
    required String bookUrl,
    required String bookName,
    required String bookAuthor,
  });
  Future<int> nextDueAt({required String cron, required int fromMs});
}
