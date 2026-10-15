import 'dart:convert';

import '../../domain/contracts/dict_rule_repository.dart';
import '../../models/misc.dart' show DictRule;

/// Mock规则共用同一仓储；不执行网络或JS查询。— Codex + Bridge
final class MockDictRuleRepository implements DictRuleRepository {
  MockDictRuleRepository() {
    _seedDefaultDictRules();
  }

  final List<Map<String, dynamic>> _dictRules = [];
  int _nextDictRuleId = 1;

  /// 注入原版默认 5 个字典源（海词中文 / 海词英文 / 有道 / 哔哩 / 百度汉语）
  void _seedDefaultDictRules() {
    final defaults = [
      {
        'name': '海词中文',
        'urlRule': 'https://hanyu.dict.cn/{{key}}',
        'showRule': '#cy',
        'enabled': true,
        'sortNumber': 0,
      },
      {
        'name': '海词英文',
        'urlRule': 'https://apii.dict.cn/mini.php?q={{key}}',
        'showRule': 'tag.body@all',
        'enabled': true,
        'sortNumber': 1,
      },
      {
        'name': '有道',
        'urlRule': 'https://m.youdao.com/translate（POST inputtext={{key}}）',
        'showRule': '（@js 占位）',
        'enabled': true,
        'sortNumber': 2,
      },
      {
        'name': '哔哩',
        'urlRule': 'https://search.bilibili.com/all?keyword={{key}}',
        'showRule': '.search-page@all（@js 占位）',
        'enabled': true,
        'sortNumber': 3,
      },
      {
        'name': '百度汉语',
        'urlRule': 'data:;base64,{{java.base64Encode(key)}},{"type":"bd"}',
        'showRule': '（@js 占位）',
        'enabled': true,
        'sortNumber': 4,
      },
    ];
    for (final rule in defaults) {
      _dictRules.add({'id': _nextDictRuleId++, ...rule});
    }
  }

  /// 列出全部字典规则（表为空时注入原版默认 5 源，ORDER BY sortNumber, id）
  @override
  Future<List<DictRule>> dictRuleList() async {
    if (_dictRules.isEmpty) _seedDefaultDictRules();
    final ordered = List<Map<String, dynamic>>.from(_dictRules)
      ..sort((a, b) {
        final bySort = (a['sortNumber'] as int).compareTo(
          b['sortNumber'] as int,
        );
        if (bySort != 0) return bySort;
        return (a['id'] as int).compareTo(b['id'] as int);
      });
    return ordered.map(DictRule.fromJson).toList();
  }

  /// 新增字典规则（enabled=true, sortNumber=0；name 重复 → 错误，对标 name 主键）
  @override
  Future<int> dictRuleAdd({
    required String name,
    required String urlRule,
    required String showRule,
  }) async {
    if (_dictRules.any((r) => r['name'] == name)) {
      throw Exception('字典规则已存在: $name');
    }
    final id = _nextDictRuleId++;
    _dictRules.add({
      'id': id,
      'name': name,
      'urlRule': urlRule,
      'showRule': showRule,
      'enabled': true,
      'sortNumber': 0,
    });
    return id;
  }

  /// 更新字典规则（按 id 改 name/urlRule/showRule；不存在返回 false）
  @override
  Future<bool> dictRuleUpdate({
    required int id,
    required String name,
    required String urlRule,
    required String showRule,
  }) async {
    final hits = _dictRules.where((r) => r['id'] == id).toList();
    if (hits.isEmpty) return false;
    if (_dictRules.any((rule) => rule['id'] != id && rule['name'] == name)) {
      throw Exception('字典规则已存在: $name');
    }
    final rule = hits.first;
    rule['name'] = name;
    rule['urlRule'] = urlRule;
    rule['showRule'] = showRule;
    return true;
  }

  /// 删除字典规则（按 id；不存在返回 false）
  @override
  Future<bool> dictRuleDelete(int id) async {
    final before = _dictRules.length;
    _dictRules.removeWhere((r) => r['id'] == id);
    return _dictRules.length < before;
  }

  /// 设置字典规则启用/禁用（按 id；不存在返回 false）
  @override
  Future<bool> dictRuleSetEnabled({
    required int id,
    required bool enabled,
  }) async {
    if (!_dictRules.any((r) => r['id'] == id)) return false;
    for (final r in _dictRules) {
      if (r['id'] == id) r['enabled'] = enabled;
    }
    return true;
  }

  @override
  Future<int> dictRuleReorder(List<int> ids) async {
    for (final (index, id) in ids.indexed) {
      for (final rule in _dictRules) {
        if (rule['id'] == id) rule['sortNumber'] = index;
      }
    }
    return ids.length;
  }

  /// 导入字典规则（GSON 数组/单对象，REPLACE by name；返回导入条数）
  ///
  /// kind=text：解析 JSON 文本；kind=url：mock 无网络能力，抛明确错误
  /// （Rust 轨走既有抓取链路，mock 不模拟）。
  @override
  Future<int> dictRuleImport({
    required String jsonOrUrl,
    required String kind,
  }) async {
    final rules = _parseImportDictRules(jsonOrUrl, kind);
    for (final rule in rules) {
      _upsertDictRuleByName(rule);
    }
    return rules.length;
  }

  /// 内存态导入解析（数组/单对象；enabled 缺省 true、sortNumber 缺省 0，GSON 语义）
  List<Map<String, dynamic>> _parseImportDictRules(String body, String kind) {
    if (kind == 'url') {
      throw Exception('mock 不支持 URL 导入（无网络能力）: $body');
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty) throw Exception('导入内容为空');
    final dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      throw Exception('解析导入 JSON 失败: $body');
    }
    final List<dynamic> items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map) {
      items = [decoded];
    } else {
      throw Exception('解析导入 JSON 失败: 须为对象数组或单对象');
    }
    if (items.any((e) => e is! Map)) {
      throw Exception('解析导入 JSON 失败: 须为对象数组或单对象');
    }
    final rules = <Map<String, dynamic>>[];
    for (final dynamic e in items) {
      final m = e as Map;
      rules.add({
        'name': (m['name'] ?? '').toString().trim(),
        'urlRule': (m['urlRule'] ?? '').toString(),
        'showRule': (m['showRule'] ?? '').toString(),
        'enabled': m['enabled'] is bool ? m['enabled'] : true,
        // JSON decode 的整数可能为 num（double 字面量场景），统一归一为 int
        'sortNumber': m['sortNumber'] is num
            ? (m['sortNumber'] as num).toInt()
            : 0,
      });
    }
    return rules.where((r) => (r['name'] as String).isNotEmpty).toList();
  }

  /// 内存态 REPLACE by name（同名覆盖 urlRule/showRule/enabled/sortNumber 保留 id，
  /// 异名插入）
  void _upsertDictRuleByName(Map<String, dynamic> rule) {
    final name = rule['name'] as String;
    final existing = _dictRules.cast<Map<String, dynamic>>().firstWhere(
      (r) => r['name'] == name,
      orElse: () => const {},
    );
    if (existing.isNotEmpty) {
      existing['urlRule'] = rule['urlRule'];
      existing['showRule'] = rule['showRule'];
      existing['enabled'] = rule['enabled'];
      existing['sortNumber'] = rule['sortNumber'];
      return;
    }
    _dictRules.add({'id': _nextDictRuleId++, ...rule});
  }
}
