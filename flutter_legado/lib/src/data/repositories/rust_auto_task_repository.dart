import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/auto_task_repository.dart';
import '../../models/misc.dart';
import '../bridge/auto_task_dto_mapping.dart';

/// 规则 CRUD 直接委托类型化 FRB，失败向上传递。— Codex + Bridge
final class RustAutoTaskRepository implements AutoTaskRepository {
  const RustAutoTaskRepository();
  @override
  Future<List<AutoTaskRule>> listRules() async =>
      (await bridge.autoTaskListRules()).map(autoTaskFromDto).toList();
  @override
  Future<String> createRule(AutoTaskRule rule) =>
      bridge.autoTaskCreateRule(rule: autoTaskToDto(rule));
  @override
  Future<void> updateRule(AutoTaskRule rule) =>
      bridge.autoTaskUpdateRule(rule: autoTaskToDto(rule));
  @override
  Future<void> deleteRule(String id) => bridge.autoTaskDeleteRule(id: id);
  @override
  Future<AutoTaskRule?> findRuleById(String id) async {
    final rule = await bridge.autoTaskFindRuleById(id: id);
    return rule == null ? null : autoTaskFromDto(rule);
  }
}
