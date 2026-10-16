import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/auto_task_service.dart';
import '../../domain/models/auto_task_execution_result.dart';
import '../../models/misc.dart';
import '../bridge/auto_task_json.dart';
import '../bridge/rust_json_decode.dart';

/// 复用现有Rust任务算法和执行器；传输编码限定在此。— Codex + Bridge
final class RustAutoTaskService implements AutoTaskService {
  const RustAutoTaskService();
  @override
  Future<AutoTaskRule> buildBookUpdateTask({
    required String bookUrl,
    required String bookName,
    required String bookAuthor,
    required String name,
  }) async => decodeAutoTaskRule(
    decodeRustJsonMap(
      await bridge.autoTaskBuildBookUpdate(
        bookUrl: bookUrl,
        bookName: bookName,
        bookAuthor: bookAuthor,
        name: name,
      ),
      'autoTaskBuildBookUpdate',
    ),
  );
  @override
  Future<List<AutoTaskRule>> updateCronBatch({
    required List<AutoTaskRule> rules,
    required List<String> ids,
    required String cron,
  }) async => decodeAutoTaskRules(
    await bridge.autoTaskUpdateCronBatch(
      rulesJson: jsonEncode(rules.map(autoTaskCoreJson).toList()),
      idsJson: jsonEncode(ids),
      cron: cron,
    ),
    'autoTaskUpdateCronBatch',
    originals: rules,
  );
  @override
  Future<List<AutoTaskRule>> prepareImportedTasks({
    required List<AutoTaskRule> localTasks,
    required String importedJson,
  }) async => decodeAutoTaskRules(
    await bridge.autoTaskPrepareImported(
      localTasksJson: jsonEncode(localTasks.map(autoTaskCoreJson).toList()),
      importedJson: importedJson,
    ),
    'autoTaskPrepareImported',
  );
  @override
  Future<AutoTaskExecutionResult> execute({
    required Map<String, dynamic> protocol,
    String? taskId,
  }) async {
    final encoded = jsonEncode(protocol);
    final raw = taskId == null
        ? await bridge.autoTaskExecute(protocolJson: encoded)
        : await bridge.autoTaskExecuteWithId(
            protocolJson: encoded,
            taskId: taskId,
          );
    final result = decodeRustJsonMap(raw, 'autoTaskExecute');
    if (result['success'] is! bool) {
      throw const FormatException('自动任务执行结果缺少success');
    }
    return AutoTaskExecutionResult(
      success: result['success'] as bool,
      taskId: result['task_id'] as String? ?? taskId ?? '',
      message: result['message'] as String? ?? '',
      durationMs: (result['duration_ms'] ?? result['durationMs']) as int? ?? 0,
      details: result['details'] as String?,
    );
  }

  @override
  Future<String> normalizeScript(String script) =>
      bridge.autoTaskNormalizeScript(script: script);
  @override
  Future<bool> canRefreshBookToc({
    required bool canUpdate,
    required bool respectCanUpdate,
  }) => bridge.autoTaskCanRefreshToc(
    canUpdate: canUpdate,
    respectCanUpdate: respectCanUpdate,
  );
  @override
  Future<AutoTaskRule?> findBookUpdateTask({
    required List<AutoTaskRule> tasks,
    required String bookUrl,
    required String bookName,
    required String bookAuthor,
  }) async {
    final raw = await bridge.autoTaskFindBookUpdate(
      tasksJson: jsonEncode(tasks.map(autoTaskCoreJson).toList()),
      bookUrl: bookUrl,
      bookName: bookName,
      bookAuthor: bookAuthor,
    );
    if (raw.isEmpty || raw == 'null') return null;
    final map = decodeRustJsonMap(raw, 'autoTaskFindBookUpdate');
    return decodeAutoTaskRule(
      map,
      original: tasks.where((rule) => rule.id == map['id']).firstOrNull,
    );
  }

  @override
  Future<int> nextDueAt({required String cron, required int fromMs}) async =>
      (await bridge.autoTaskNextDueAt(cron: cron, fromMs: fromMs)).toInt();
}
