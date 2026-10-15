// mock_book_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 MockBookApiSyncTools mixin：WebDAV / 段评 / 书籍导出 / 自动任务。
// MockBookApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 内存存储字段来自 MockBookApiStore（on 约束），同一 library 内私有成员可直接访问。
part of 'mock_book_api.dart';

mixin MockBookApiSyncTools on MockBookApiStore implements BookApi {
  // ========== 段评（书源 ruleReview）==========

  @override
  Future<String> reviewGetSummary(String sourceJson, String requestJson) async {
    return jsonEncode({
      'counts': {'1': 3, '2': 1},
      'keys': {'1': 'mock-para-1', '2': 'mock-para-2'},
    });
  }

  @override
  Future<String> reviewGetDetail(
    String sourceJson,
    String requestJson,
    int page,
  ) async {
    return jsonEncode({
      'items': [
        {
          'id': 'mock_detail_$page-1',
          'name': '读者甲',
          'content': 'Mock 段评内容一（第$page 页）',
          'badges': <String>['作者'],
          'time': '刚刚',
          'replyCount': 2,
          'replies': <Map<String, dynamic>>[],
        },
        {
          'id': 'mock_detail_$page-2',
          'name': '读者乙',
          'content': 'Mock 段评内容二（第$page 页）',
          'badges': <String>[],
          'replyCount': 0,
          'replies': <Map<String, dynamic>>[],
        },
      ],
      'nextPageUrl': page < 2 ? 'mock://next' : null,
      'hasReplyUrl': true,
    });
  }

  @override
  Future<String> reviewGetReplies(
    String sourceJson,
    String requestJson,
    int page,
  ) async {
    // Mock 返回两条示例回复，便于 UI 轨联调段评回复弹窗
    return jsonEncode({
      'items': [
        {
          'id': 'mock_reply_$page-1',
          'name': '读者甲',
          'content': 'Mock 回复内容一（第$page 页）',
          'badges': <String>['沙发'],
          'time': '刚刚',
        },
        {
          'id': 'mock_reply_$page-2',
          'name': '读者乙',
          'content': 'Mock 回复内容二（第$page 页）',
          'badges': <String>[],
        },
      ],
      'nextPageUrl': null,
    });
  }

  // ========== 书籍导出 ==========

  @override
  Future<Map<String, dynamic>> bookExport({
    required String bookUrl,
    required String format,
    required bool includeToc,
  }) async {
    final book = await bookshelfRepository.getBook(bookUrl);
    if (book == null) {
      return {'success': false, 'error': '书籍不存在: $bookUrl'};
    }
    return {
      'success': true,
      'file_name': '${book.name}.$format',
      'data_base64': base64Encode(utf8.encode('Mock 导出内容')),
      'mime_type': 'text/plain',
    };
  }

  @override
  Future<Map<String, dynamic>> bookExportWithOptions({
    required String bookUrl,
    required String format,
    required bool includeToc,
    String optionsJson = '',
  }) async {
    return bookExport(bookUrl: bookUrl, format: format, includeToc: includeToc);
  }

  @override
  Future<Map<String, dynamic>> bookExportInfo({
    required String bookUrl,
    required String format,
  }) async {
    final book = await bookshelfRepository.getBook(bookUrl);
    if (book == null) {
      return {'success': false, 'error': '书籍不存在: $bookUrl'};
    }
    final chapters = await readingRepository.getChapters(bookUrl);
    return {
      'success': true,
      'file_name': '${book.name}.$format',
      'chapter_count': chapters.length.toString(),
    };
  }

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
