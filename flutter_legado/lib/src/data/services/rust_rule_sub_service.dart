import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/rule_sub_service.dart';
import '../../domain/models/rule_sub_update_result.dart';
import '../bridge/rust_json_decode.dart';

/// 响应解码在服务边界完成，坏结构不当作更新成功。— Codex + Bridge
final class RustRuleSubService implements RuleSubService {
  const RustRuleSubService();

  @override
  Future<RuleSubCheckResult> ruleSubCheckUpdate({required int id}) async {
    final json = decodeRustJsonMap(
      await bridge.ruleSubCheckUpdate(id: id),
      'ruleSubCheckUpdate',
    );
    return RuleSubCheckResult(
      id: _field<int>(json, 'id'),
      url: _field<String>(json, 'url'),
      name: _field<String>(json, 'name'),
      dueForUpdate: _field<bool>(json, 'dueForUpdate'),
      hasUpdate: _field<bool>(json, 'hasUpdate'),
      remoteVersion: _field<String?>(json, 'remoteVersion'),
      error: _field<String?>(json, 'error'),
    );
  }

  @override
  Future<RuleSubApplyResult> ruleSubApplyUpdate({required int id}) async {
    final json = decodeRustJsonMap(
      await bridge.ruleSubApplyUpdate(id: id),
      'ruleSubApplyUpdate',
    );
    return RuleSubApplyResult(
      id: _field<int>(json, 'id'),
      url: _field<String>(json, 'url'),
      success: _field<bool>(json, 'success'),
      itemsAdded: _field<int>(json, 'itemsAdded'),
      itemsUpdated: _field<int>(json, 'itemsUpdated'),
      itemsRemoved: _field<int>(json, 'itemsRemoved'),
      totalItems: _field<int>(json, 'totalItems'),
      error: _field<String?>(json, 'error'),
    );
  }
}

T _field<T>(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! T) throw FormatException('规则订阅更新响应：$key字段类型无效');
  return value;
}
