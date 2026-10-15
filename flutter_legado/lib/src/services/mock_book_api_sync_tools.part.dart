// mock_book_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 MockBookApiSyncTools mixin：自动任务。
// MockBookApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 内存存储字段来自 MockBookApiStore（on 约束），同一 library 内私有成员可直接访问。
part of 'mock_book_api.dart';

mixin MockBookApiSyncTools on MockBookApiStore implements BookApi {
  // ========== 自动任务 ==========

  @override
  Future<Map<String, dynamic>> autoTaskBuildBookUpdateTask({
    required String bookUrl,
    required String bookName,
    required String bookAuthor,
    required String name,
  }) async => {
    'id': 'mock-task-${_nextId++}',
    'name': name,
    'bookUrl': bookUrl,
    'bookName': bookName,
    'bookAuthor': bookAuthor,
    'cron': '0 0 8 * * *',
    'enabled': true,
  };

  @override
  Future<List<Map<String, dynamic>>> autoTaskUpdateCronBatch({
    required String rulesJson,
    required String idsJson,
    required String cron,
  }) async {
    final rules = (jsonDecode(rulesJson) as List<dynamic>)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final ids = (jsonDecode(idsJson) as List<dynamic>)
        .map((e) => e.toString())
        .toList();
    for (final rule in rules) {
      if (ids.contains(rule['id']?.toString())) {
        rule['cron'] = cron;
      }
    }
    return rules;
  }

  @override
  Future<List<Map<String, dynamic>>> autoTaskPrepareImported({
    required String localTasksJson,
    required String importedJson,
  }) async {
    final imported = (jsonDecode(importedJson) as List<dynamic>)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    return imported;
  }

  @override
  Future<Map<String, dynamic>> autoTaskExecute({
    required String protocolJson,
  }) async => {'success': true, 'message': 'Mock 执行成功'};

  @override
  Future<Map<String, dynamic>> autoTaskExecuteWithId({
    required String protocolJson,
    required String taskId,
  }) async => {'success': true, 'taskId': taskId, 'message': 'Mock 执行成功'};

  @override
  Future<String> autoTaskNormalizeScript({required String script}) async {
    if (script.startsWith('@js:')) return script.substring(4);
    return script;
  }

  @override
  Future<bool> autoTaskCanRefreshBookToc({
    required bool canUpdate,
    required bool respectCanUpdate,
  }) async {
    if (!respectCanUpdate) return true;
    return canUpdate;
  }

  @override
  Future<Map<String, dynamic>?> autoTaskFindBookUpdateTask({
    required String tasksJson,
    required String bookUrl,
    required String bookName,
    required String bookAuthor,
  }) async => null;

  @override
  Future<int> autoTaskNextDueAt({
    required String cron,
    required int fromMs,
  }) async => fromMs + 86400000; // +24h

  // ========== 自动任务数据库 CRUD ==========

  final List<Map<String, dynamic>> _mockAutoTaskRules = [];

  @override
  Future<List<Map<String, dynamic>>> autoTaskListRules() async =>
      List.from(_mockAutoTaskRules);

  @override
  Future<String> autoTaskCreateRule({required String ruleJson}) async {
    final rule = jsonDecode(ruleJson) as Map<String, dynamic>;
    final id = rule['id']?.toString() ?? 'mock-task-${_nextId++}';
    rule['id'] = id;
    _mockAutoTaskRules.add(rule);
    return id;
  }

  @override
  Future<void> autoTaskUpdateRule({required String ruleJson}) async {
    final rule = jsonDecode(ruleJson) as Map<String, dynamic>;
    final id = rule['id']?.toString();
    if (id != null) {
      final index = _mockAutoTaskRules.indexWhere((r) => r['id'] == id);
      if (index >= 0) {
        _mockAutoTaskRules[index] = rule;
      }
    }
  }

  @override
  Future<void> autoTaskDeleteRule({required String id}) async {
    _mockAutoTaskRules.removeWhere((r) => r['id'] == id);
  }

  @override
  Future<Map<String, dynamic>?> autoTaskFindRuleById({
    required String id,
  }) async {
    try {
      return _mockAutoTaskRules.firstWhere((r) => r['id'] == id);
    } catch (_) {
      return null;
    }
  }
}
