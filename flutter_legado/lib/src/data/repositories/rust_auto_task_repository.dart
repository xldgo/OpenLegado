import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/auto_task_repository.dart';
import '../../models/misc.dart';
import '../bridge/auto_task_json.dart';
import '../bridge/rust_json_decode.dart';

/// 规则CRUD直接委托现有FRB，失败向上传递。— Codex + Bridge
final class RustAutoTaskRepository implements AutoTaskRepository {
  const RustAutoTaskRepository();
  @override
  Future<List<AutoTaskRule>> listRules() async => decodeAutoTaskRules(
    await bridge.autoTaskListRules(),
    'autoTaskListRules',
  );
  @override
  Future<String> createRule(AutoTaskRule rule) =>
      bridge.autoTaskCreateRule(ruleJson: jsonEncode(rule.toJson()));
  @override
  Future<void> updateRule(AutoTaskRule rule) async {
    await bridge.autoTaskUpdateRule(ruleJson: jsonEncode(rule.toJson()));
  }

  @override
  Future<void> deleteRule(String id) async {
    await bridge.autoTaskDeleteRule(id: id);
  }

  @override
  Future<AutoTaskRule?> findRuleById(String id) async {
    final raw = await bridge.autoTaskFindRuleById(id: id);
    if (raw.isEmpty || raw == 'null') return null;
    return decodeAutoTaskRule(decodeRustJsonMap(raw, 'autoTaskFindRuleById'));
  }
}
