import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../bridge/source_tools_dto.dart';
import '../../domain/contracts/cover_rule_repository.dart';
import '../../domain/models/cover_rule.dart';

/// 配置逐字段传输，规则原文和可空Cookie开关保持。— Codex + Bridge
final class RustCoverRuleRepository implements CoverRuleRepository {
  const RustCoverRuleRepository();
  @override
  Future<CoverRule> getCoverRule() async {
    final result = await rustFuture(
      () => bridge.getCoverRule(),
      operation: 'getCoverRule',
    );
    return CoverRule(
      enable: result.enable,
      searchUrl: result.searchUrl,
      coverRule: result.coverRule,
      enabledCookieJar: result.enabledCookieJar,
    );
  }

  @override
  Future<bool> saveCoverRule(CoverRule rule) => rustFuture(
    () => bridge.saveCoverRule(
      rule: CoverRuleDto(
        enable: rule.enable,
        searchUrl: rule.searchUrl,
        coverRule: rule.coverRule,
        enabledCookieJar: rule.enabledCookieJar,
      ),
    ),
    operation: 'saveCoverRule',
  );
  @override
  Future<bool> deleteCoverRule() =>
      rustFuture(() => bridge.deleteCoverRule(), operation: 'deleteCoverRule');
}
