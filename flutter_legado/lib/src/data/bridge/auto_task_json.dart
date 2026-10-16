import '../../models/misc.dart';
import 'rust_json_decode.dart';

/// 数据库规则采用camelCase，Rust纯计算结构采用snake_case。— Codex + Bridge
AutoTaskRule decodeAutoTaskRule(
  Map<String, dynamic> value, {
  AutoTaskRule? original,
}) {
  if (value['id'] is! String || value['name'] is! String) {
    throw const FormatException('自动任务规则缺少有效id或name');
  }
  final map = <String, dynamic>{...?original?.toJson(), ...value};
  for (final (snake, camel) in [
    ('custom_order', 'customOrder'),
    ('last_run_at', 'lastRunAt'),
    ('last_result', 'lastResult'),
    ('last_error', 'lastError'),
    ('last_log', 'lastLog'),
  ]) {
    if (value.containsKey(snake)) map[camel] = value[snake];
  }
  return AutoTaskRule.fromJson(map);
}

List<AutoTaskRule> decodeAutoTaskRules(
  String raw,
  String method, {
  List<AutoTaskRule> originals = const [],
}) {
  final byId = {for (final rule in originals) rule.id: rule};
  return decodeRustJsonList(raw, method).map((value) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('$method: 自动任务规则必须是对象');
    }
    return decodeAutoTaskRule(value, original: byId[value['id']]);
  }).toList();
}

/// 纯计算接口要求的字段名，不改变数据库序列化格式。
Map<String, dynamic> autoTaskCoreJson(AutoTaskRule rule) => {
  'id': rule.id,
  'name': rule.name,
  'enable': rule.enable,
  'cron': rule.cron,
  'script': rule.script,
  'custom_order': rule.customOrder,
  'last_run_at': rule.lastRunAt,
  'last_result': rule.lastResult,
  'last_error': rule.lastError,
  'last_log': rule.lastLog,
};
