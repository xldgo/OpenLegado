import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/auto_task_service.dart';
import '../../domain/models/auto_task_execution_result.dart';
import '../../models/misc.dart';
import '../bridge/auto_task_dto_mapping.dart';

/// 实体直接传输，JSON 仅用于真实脚本协议与导入文档。— Codex + Bridge
final class RustAutoTaskService implements AutoTaskService {
  const RustAutoTaskService();
  @override
  Future<AutoTaskRule> buildBookUpdateTask({
    required String bookUrl,
    required String bookName,
    required String bookAuthor,
    required String name,
  }) async => autoTaskFromDto(
    await bridge.autoTaskBuildBookUpdate(
      bookUrl: bookUrl,
      bookName: bookName,
      bookAuthor: bookAuthor,
      name: name,
    ),
  );
  @override
  Future<List<AutoTaskRule>> updateCronBatch({
    required List<AutoTaskRule> rules,
    required List<String> ids,
    required String cron,
  }) async => (await bridge.autoTaskUpdateCronBatch(
    rules: rules.map(autoTaskToDto).toList(),
    ids: ids,
    cron: cron,
  )).map(autoTaskFromDto).toList();
  @override
  Future<List<AutoTaskRule>> prepareImportedTasks({
    required List<AutoTaskRule> localTasks,
    required String importedJson,
  }) async => (await bridge.autoTaskPrepareImported(
    localTasks: localTasks.map(autoTaskToDto).toList(),
    importedJson: importedJson,
  )).map(autoTaskFromDto).toList();
  @override
  Future<AutoTaskExecutionResult> execute({
    required Map<String, dynamic> protocol,
    String? taskId,
  }) async {
    final encoded = jsonEncode(protocol);
    final result = taskId == null
        ? await bridge.autoTaskExecute(protocolJson: encoded)
        : await bridge.autoTaskExecuteWithId(
            protocolJson: encoded,
            taskId: taskId,
          );
    return AutoTaskExecutionResult(
      success: result.success,
      taskId: result.taskId,
      message: result.message,
      durationMs: result.durationMs.toInt(),
      details: result.details,
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
    final rule = await bridge.autoTaskFindBookUpdate(
      tasks: tasks.map(autoTaskToDto).toList(),
      bookUrl: bookUrl,
      bookName: bookName,
      bookAuthor: bookAuthor,
    );
    return rule == null ? null : autoTaskFromDto(rule);
  }

  @override
  Future<int> nextDueAt({required String cron, required int fromMs}) async =>
      (await bridge.autoTaskNextDueAt(cron: cron, fromMs: fromMs)).toInt();
}
