import 'dart:convert';

/// 保留调试路径的协议组装，传输编码由数据层负责。— Codex + Bridge
Map<String, dynamic> buildAutoTaskDebugProtocol(
  String taskType,
  String? storedScript,
) {
  final script = storedScript?.trim() ?? '';
  if (script.startsWith('{')) {
    try {
      final map = jsonDecode(script);
      if (map is Map && map.containsKey('action')) {
        // 已是协议或含 action 的脚本 JSON
        if (map['params'] is Map ||
            map['action'] is Map ||
            map['action'] is String) {
          // 若仅有 Kotlin 风格业务 JSON，仍尝试原样交给执行器
          return Map<String, dynamic>.from(map);
        }
      }
    } catch (_) {}
  }

  switch (taskType) {
    case 'refreshToc':
      return {'action': 'RefreshToc', 'params': _paramsFromScript(script)};
    case 'updateSources':
      return {'action': 'UpdateSources', 'params': {}};
    case 'backup':
      return {'action': 'Backup', 'params': {}};
    default:
      final js = script.isNotEmpty ? script : taskType;
      return {
        'action': {'Custom': js},
        'params': {},
      };
  }
}

Map<String, String> _paramsFromScript(String script) {
  if (!script.startsWith('{')) return {};
  try {
    final map = jsonDecode(script);
    if (map is! Map) return {};
    final bookUrl = map['bookUrl'] ?? map['book_url'];
    if (bookUrl != null && bookUrl.toString().isNotEmpty) {
      return {'bookUrl': bookUrl.toString()};
    }
  } catch (_) {}
  return {};
}
