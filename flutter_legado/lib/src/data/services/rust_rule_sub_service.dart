import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/rule_sub_service.dart';
import '../../domain/models/rule_sub_update_result.dart';
import '../bridge/business_dto_mapping.dart';

/// 直接消费类型化更新结果，保留业务失败字段。— Codex + Bridge
final class RustRuleSubService implements RuleSubService {
  const RustRuleSubService();
  @override
  Future<RuleSubCheckResult> ruleSubCheckUpdate({required int id}) async =>
      subscriptionCheckFromDto(
        await rustFuture(
          () => bridge.ruleSubCheckUpdate(id: id),
          operation: 'ruleSubCheckUpdate',
        ),
      );
  @override
  Future<RuleSubApplyResult> ruleSubApplyUpdate({required int id}) async =>
      subscriptionApplyFromDto(
        await rustFuture(
          () => bridge.ruleSubApplyUpdate(id: id),
          operation: 'ruleSubApplyUpdate',
        ),
      );
}
