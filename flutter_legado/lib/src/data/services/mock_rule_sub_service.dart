import '../../domain/contracts/rule_sub_repository.dart';
import '../../domain/contracts/rule_sub_service.dart';
import '../../domain/models/rule_sub_update_result.dart';
import '../../models/rule_sub.dart';

/// 复用同一Mock仓储，保留无网络检查与零变更应用的占位行为。— Codex + Bridge
final class MockRuleSubService implements RuleSubService {
  MockRuleSubService({required this._repository});

  final RuleSubRepository _repository;

  Future<RuleSub?> _find(int id) async {
    for (final sub in await _repository.ruleSubList()) {
      if (sub.id == id) return sub;
    }
    return null;
  }

  @override
  Future<RuleSubCheckResult> ruleSubCheckUpdate({required int id}) async {
    final sub = await _find(id);
    return RuleSubCheckResult(
      id: id,
      url: sub?.url ?? '',
      name: sub?.name ?? '',
      dueForUpdate: sub != null,
      hasUpdate: false,
      remoteVersion: sub?.version,
      error: sub == null ? '订阅不存在' : null,
    );
  }

  @override
  Future<RuleSubApplyResult> ruleSubApplyUpdate({required int id}) async {
    final sub = await _find(id);
    return RuleSubApplyResult(
      id: id,
      url: sub?.url ?? '',
      success: sub != null,
      itemsAdded: 0,
      itemsUpdated: 0,
      itemsRemoved: 0,
      totalItems: 0,
      error: sub == null ? '订阅不存在' : null,
    );
  }
}
