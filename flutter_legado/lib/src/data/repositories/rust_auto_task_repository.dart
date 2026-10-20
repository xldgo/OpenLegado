import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/auto_task_repository.dart';
import '../../models/misc.dart';
import '../bridge/auto_task_dto_mapping.dart';

/// 规则 CRUD 直接委托类型化 FRB，失败向上传递。— Codex + Bridge
final class RustAutoTaskRepository implements AutoTaskRepository {
  const RustAutoTaskRepository();
  @override
  Future<List<AutoTaskRule>> listRules() async => (await rustFuture(
    () => bridge.autoTaskListRules(),
    operation: 'autoTaskListRules',
  )).map(autoTaskFromDto).toList();
  @override
  Future<String> createRule(AutoTaskRule rule) => rustFuture(
    () => bridge.autoTaskCreateRule(rule: autoTaskToDto(rule)),
    operation: 'autoTaskCreateRule',
  );
  @override
  Future<void> updateRule(AutoTaskRule rule) => rustFuture(
    () => bridge.autoTaskUpdateRule(rule: autoTaskToDto(rule)),
    operation: 'autoTaskUpdateRule',
  );
  @override
  Future<void> deleteRule(String id) => rustFuture(
    () => bridge.autoTaskDeleteRule(id: id),
    operation: 'autoTaskDeleteRule',
  );
  @override
  Future<AutoTaskRule?> findRuleById(String id) async {
    final rule = await rustFuture(
      () => bridge.autoTaskFindRuleById(id: id),
      operation: 'autoTaskFindRuleById',
    );
    return rule == null ? null : autoTaskFromDto(rule);
  }
}
