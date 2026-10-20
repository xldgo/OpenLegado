import 'dart:convert';

import '../../domain/contracts/auto_task_service.dart';
import '../../domain/models/auto_task_execution_result.dart';
import '../../models/misc.dart';

/// 保留无真实执行器的Mock行为，不复制Rust的cron或JS实现。— Codex + Bridge
final class MockAutoTaskService implements AutoTaskService {
  MockAutoTaskService({required this._allocateId});
  final String Function() _allocateId;
  @override
  Future<AutoTaskRule> buildBookUpdateTask({
    required String bookUrl,
    required String bookName,
    required String bookAuthor,
    required String name,
  }) async => AutoTaskRule(
    id: _allocateId(),
    name: name,
    cron: '0 0 8 * * *',
    script:
        '(${jsonEncode({'type': 'refreshToc', 'bookUrl': bookUrl, 'bookName': bookName, 'bookAuthor': bookAuthor, 'generatedBy': 'bookUpdate'})})',
  );
  @override
  Future<List<AutoTaskRule>> updateCronBatch({
    required List<AutoTaskRule> rules,
    required List<String> ids,
    required String cron,
  }) async => rules
      .map((rule) => ids.contains(rule.id) ? rule.copyWith(cron: cron) : rule)
      .toList();
  @override
  Future<List<AutoTaskRule>> prepareImportedTasks({
    required List<AutoTaskRule> localTasks,
    required String importedJson,
  }) async {
    final decoded = jsonDecode(importedJson);
    final list = decoded is List ? decoded : [decoded];
    return list
        .map((value) => AutoTaskRule.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AutoTaskExecutionResult> execute({
    required Map<String, dynamic> protocol,
    String? taskId,
  }) async => AutoTaskExecutionResult(
    success: true,
    taskId: taskId ?? '',
    message: 'Mock 执行成功',
  );
  @override
  Future<String> normalizeScript(String script) async =>
      script.startsWith('@js:') ? script.substring(4) : script;
  @override
  Future<bool> canRefreshBookToc({
    required bool canUpdate,
    required bool respectCanUpdate,
  }) async => canUpdate || !respectCanUpdate;
  @override
  Future<AutoTaskRule?> findBookUpdateTask({
    required List<AutoTaskRule> tasks,
    required String bookUrl,
    required String bookName,
    required String bookAuthor,
  }) async => null;
  @override
  Future<int> nextDueAt({required String cron, required int fromMs}) async =>
      fromMs + 86400000;
}
