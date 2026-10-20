import '../bridge/rust_errors.dart';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show Int64List;

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/dict_rule_repository.dart';
import '../../models/misc.dart' show DictRule;
import '../bridge/business_dto_mapping.dart';

/// 复用现有FRB与空表默认规则，响应解码集中在数据层。— Codex + Bridge
final class RustDictRuleRepository implements DictRuleRepository {
  const RustDictRuleRepository();

  @override
  Future<List<DictRule>> dictRuleList() async => (await rustFuture(
    () => bridge.dictRuleList(),
    operation: 'dictRuleList',
  )).map(dictionaryRuleFromDto).toList();

  @override
  Future<int> dictRuleAdd({
    required String name,
    required String urlRule,
    required String showRule,
  }) async {
    final id = await rustFuture(
      () =>
          bridge.dictRuleAdd(name: name, urlRule: urlRule, showRule: showRule),
      operation: 'dictRuleAdd',
    );
    if (id <= 0) throw StateError('新增词典规则未返回有效主键');
    return id;
  }

  @override
  Future<bool> dictRuleUpdate({
    required int id,
    required String name,
    required String urlRule,
    required String showRule,
  }) => rustFuture(
    () => bridge.dictRuleUpdate(
      id: id,
      name: name,
      urlRule: urlRule,
      showRule: showRule,
    ),
    operation: 'dictRuleUpdate',
  );

  @override
  Future<bool> dictRuleDelete(int id) => rustFuture(
    () => bridge.dictRuleDelete(id: id),
    operation: 'dictRuleDelete',
  );

  @override
  Future<bool> dictRuleSetEnabled({required int id, required bool enabled}) =>
      rustFuture(
        () => bridge.dictRuleSetEnabled(id: id, enabled: enabled),
        operation: 'dictRuleSetEnabled',
      );

  @override
  Future<int> dictRuleReorder(List<int> ids) => rustFuture(
    () => bridge.dictRuleReorder(ids: Int64List.fromList(ids)),
    operation: 'dictRuleReorder',
  );

  @override
  Future<int> dictRuleImport({
    required String jsonOrUrl,
    required String kind,
  }) => rustFuture(
    () => bridge.dictRuleImport(jsonOrUrl: jsonOrUrl, kind: kind),
    operation: 'dictRuleImport',
  );
}
