import '../../bridge/ffi/ffi.dart' as bridge;
import '../../bridge/source_tools_dto.dart';
import '../../domain/contracts/cover_rule_repository.dart';
import '../../domain/models/cover_rule.dart';

/// 配置逐字段传输，规则原文和可空Cookie开关保持。— Codex + Bridge
final class RustCoverRuleRepository implements CoverRuleRepository {
  const RustCoverRuleRepository();
  @override
  Future<CoverRule> getCoverRule() async {
    final result = await bridge.getCoverRule();
    return CoverRule(
      enable: result.enable,
      searchUrl: result.searchUrl,
      coverRule: result.coverRule,
      enabledCookieJar: result.enabledCookieJar,
    );
  }

  @override
  Future<bool> saveCoverRule(CoverRule rule) => bridge.saveCoverRule(
    rule: CoverRuleDto(
      enable: rule.enable,
      searchUrl: rule.searchUrl,
      coverRule: rule.coverRule,
      enabledCookieJar: rule.enabledCookieJar,
    ),
  );
  @override
  Future<bool> deleteCoverRule() => bridge.deleteCoverRule();
}
