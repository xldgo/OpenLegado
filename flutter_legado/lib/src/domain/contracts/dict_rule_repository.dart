import '../../models/misc.dart' show DictRule;

/// 词典规则唯一访问入口，查询与管理共享现有SQLite规则表。— Codex + Bridge
abstract interface class DictRuleRepository {
  Future<List<DictRule>> dictRuleList();
  Future<int> dictRuleAdd({
    required String name,
    required String urlRule,
    required String showRule,
  });
  Future<bool> dictRuleUpdate({
    required int id,
    required String name,
    required String urlRule,
    required String showRule,
  });
  Future<bool> dictRuleDelete(int id);
  Future<bool> dictRuleSetEnabled({required int id, required bool enabled});
  Future<int> dictRuleReorder(List<int> ids);
  Future<int> dictRuleImport({required String jsonOrUrl, required String kind});
}
