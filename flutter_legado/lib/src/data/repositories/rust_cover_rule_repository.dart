import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/cover_rule_repository.dart';
import '../../domain/models/cover_rule.dart';
import '../bridge/rust_json_decode.dart';

/// 规则JSON只在数据层编码与解码。— Codex + Bridge
final class RustCoverRuleRepository implements CoverRuleRepository {
  const RustCoverRuleRepository();
  @override
  Future<CoverRule> getCoverRule() async {
    final map = decodeRustJsonMap(await bridge.getCoverRule(), 'getCoverRule');
    return CoverRule(
      enable: map['enable'] as bool? ?? true,
      searchUrl: map['searchUrl'] as String? ?? '',
      coverRule: map['coverRule'] as String? ?? '',
      enabledCookieJar: map['enabledCookieJar'] as bool?,
    );
  }

  @override
  Future<bool> saveCoverRule(CoverRule rule) => bridge.saveCoverRule(
    ruleJson: jsonEncode({
      'enable': rule.enable,
      'searchUrl': rule.searchUrl,
      'coverRule': rule.coverRule,
      if (rule.enabledCookieJar != null)
        'enabledCookieJar': rule.enabledCookieJar,
    }),
  );
  @override
  Future<bool> deleteCoverRule() => bridge.deleteCoverRule();
}
