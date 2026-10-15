// rust_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 RustApiReaderData mixin：替换规则 / 阅读器 / 配置 / 词典 / 日志 / 备份 / 阅读记录。
// RustApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 解码辅助来自 RustApiDecode（on 约束），同一 library 内私有成员可直接访问。
part of 'rust_api.dart';

mixin RustApiReaderData on RustApiDecode implements BookApi {
  // ========== 替换规则操作 ==========

  /// 获取所有替换规则
  @override
  Future<List<ReplaceRule>> getReplaceRules() async {
    final json = await bridge.replaceRuleList();
    final list = _decodeList(json, 'bookApi');
    return list
        .map((e) => ReplaceRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取启用的替换规则
  @override
  Future<List<ReplaceRule>> getEnabledReplaceRules() async {
    final json = await bridge.replaceRuleEnabled();
    final list = _decodeList(json, 'bookApi');
    return list
        .map((e) => ReplaceRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 添加替换规则
  ///
  /// [A3 写链路补齐 | 2026-09-11] FFI 加法式扩参后，分组/作用范围
  /// （标题·正文·书源作用域）/排除范围/超时随对象全字段落库
  /// （缺省语义由 Rust 侧兜底：group=null、scopeTitle=false、
  /// scopeContent=true、scopeSource=false、excludeScope=null、
  /// timeoutMillisecond=3000）。
  @override
  Future<ReplaceRule> addReplaceRule(ReplaceRule rule) async {
    final id = await bridge.replaceRuleAdd(
      name: rule.name,
      pattern: rule.pattern,
      replacement: rule.replacement,
      isRegex: rule.isRegex,
      scope: rule.scope ?? '',
      group: rule.group,
      scopeTitle: rule.scopeTitle,
      scopeContent: rule.scopeContent,
      excludeScope: rule.excludeScope,
      timeoutMillisecond: rule.timeoutMillisecond,
      // [书源作用域 | 2026-09-13] 全字段透传；Rust 侧 None→false（对齐原版默认 0）
      scopeSource: rule.scopeSource,
    );
    return rule.copyWith(id: id);
  }

  /// 更新替换规则
  ///
  /// [A3 写链路补齐 | 2026-09-11] 与 add 相同的全字段透传。
  /// 调用方约定传「完整对象」（读自 API 后 copyWith），故 group/
  /// excludeScope 为 null 即表示「该规则无此字段」，统一以空串透传
  /// → Rust 侧按「清除该字段」处理（与 MockBookApi 整对象替换语义一致；
  /// Rust 侧 None=保留既有值 仅服务 C-ABI 等旧调用方）。
  ///
  /// [书源作用域 | 2026-09-13] 新增 scopeSource 全字段透传；
  /// Rust 侧 None=保留既有值，Some(b)=覆盖。
  @override
  Future<void> updateReplaceRule(ReplaceRule rule) => bridge.replaceRuleUpdate(
    ruleId: rule.id,
    name: rule.name,
    pattern: rule.pattern,
    replacement: rule.replacement,
    isRegex: rule.isRegex,
    isEnabled: rule.isEnabled,
    group: rule.group ?? '',
    scopeTitle: rule.scopeTitle,
    scopeContent: rule.scopeContent,
    excludeScope: rule.excludeScope ?? '',
    timeoutMillisecond: rule.timeoutMillisecond,
    // [书源作用域 | 2026-09-13] 全字段透传；Rust 侧 None=保留既有值
    scopeSource: rule.scopeSource,
  );

  /// 删除替换规则
  @override
  Future<void> deleteReplaceRule(int id) =>
      bridge.replaceRuleDelete(ruleId: id);

  /// 启用/禁用替换规则
  @override
  Future<void> setReplaceRuleEnabled(int id, bool enabled) =>
      bridge.replaceRuleSetEnabled(ruleId: id, enabled: enabled);

  /// 书源导入时应用「书源作用域」替换规则（契约 §2.8 `applyReplaceRulesToSource`）
  ///
  /// [书源作用域 | 2026-09-13] 透传 FFI：对整源 JSON 应用
  /// `isEnabled && scopeSource && pattern 非空` 且 scope/excludeScope
  /// 按源名称/源 URL（忽略大小写）匹配的规则；未命中返回原文；
  /// 任何规则级/DB 错误均原样返回输入 JSON（不上抛 FFI），保证导入不中断。
  @override
  Future<String> applyReplaceRulesToSource(
    String sourceJson,
    String sourceName,
    String sourceUrl,
  ) => bridge.applyReplaceRulesToSource(
    sourceJson: sourceJson,
    sourceName: sourceName,
    sourceUrl: sourceUrl,
  );

  /// 替换规则编辑器预览：对单条规则在示例文本上执行真实替换管线（契约 §2.8 `previewReplaceRule`）
  ///
  /// [替换规则预览 | 2026-09-13] 透传 FFI：成功=返回替换后文本；
  /// 规则级错误（非法正则 / `@js:` JS 异常 / 执行超时）=返回 `⚠️ ` 前缀
  /// 错误文本（不上抛 FFI）；非法输入（JSON 解析失败）MAY Err。
  @override
  Future<String> previewReplaceRule(String ruleJson, String sampleContent) =>
      bridge.replaceRulePreview(ruleJson: ruleJson, sample: sampleContent);

  // ========== 阅读器操作 ==========

  /// 设置阅读器繁简转换类型并持久化（0=不转换 / 1=繁转简 / 2=简转繁）
  ///
  /// 语义对齐 Android `AppConfig.chineseConverterType`；非法取值归一为 0。
  @override
  Future<void> setChineseConvertType(int type) =>
      bridge.readerSetChineseConvert(convertType: type);

  /// 获取当前繁简转换类型（0=不转换 / 1=繁转简 / 2=简转繁）
  @override
  Future<int> getChineseConvertType() => bridge.readerGetChineseConvert();

  /// 章级「删除重复标题」开关（契约 §2.9.10，Task #50 加法式新增）
  ///
  /// enable=true 恢复全局默认（去除重复标题）；false 该章保留原始标题。
  /// 状态持久化于 Rust 侧 DB，重启后保持。
  @override
  Future<void> toggleSameTitleRemoved(
    String bookUrl,
    int chapterIndex,
    bool enable,
  ) => bridge.readerToggleSameTitleRemoved(
    bookUrl: bookUrl,
    chapterIndex: chapterIndex,
    enable: enable,
  );

  @override
  Future<bool> getSameTitleRemoved(String bookUrl, int chapterIndex) => bridge
      .readerGetSameTitleRemoved(bookUrl: bookUrl, chapterIndex: chapterIndex);

  @override
  Future<bool> canRemoveSameTitle(String chapterTitle, String rawContent) =>
      bridge.readerCanRemoveSameTitle(
        chapterTitle: chapterTitle,
        rawContent: rawContent,
      );

  // ========== 配置操作 ==========

  /// 获取配置值
  @override
  Future<String?> getConfig(String key) async {
    final v = await bridge.configGet(key: key);
    return v.isEmpty ? null : v;
  }

  /// 设置配置值
  @override
  Future<void> setConfig(String key, String value) async {
    await bridge.configSet(key: key, value: value);
  }

  /// 删除配置（设置为空字符串）
  @override
  Future<void> deleteConfig(String key) async {
    await bridge.configSet(key: key, value: '');
  }

  /// 获取所有配置
  @override
  Future<Map<String, String>> getAllConfigs() async {
    final json = await bridge.configGetAll();
    final m = _decodeMap(json, 'bookApi');
    return m.map((k, v) => MapEntry(k, v.toString()));
  }

  // ========== 词典操作 ==========

  /// 词典查询（本地内置词典）
  ///
  /// Rust 侧返回结构化释义 JSON 对象，字段：`word` / `phonetic` / `definitions`。
  /// 未收录词返回空 `definitions`（非异常）。
  @override
  Future<Map<String, dynamic>> dictLookup(String word) async {
    final json = await bridge.dictLookup(word: word);
    return _decodeMap(json, 'dictLookup');
  }

  // ========== 字典规则操作（dict_rule FFI，契约 §2.45） ==========

  @override
  Future<List<Map<String, dynamic>>> dictRuleList() async {
    final json = await bridge.dictRuleList();
    return _decodeList(json, 'dictRuleList').cast<Map<String, dynamic>>();
  }

  @override
  Future<int> dictRuleAdd({
    required String name,
    required String urlRule,
    required String showRule,
  }) => bridge.dictRuleAdd(name: name, urlRule: urlRule, showRule: showRule);

  @override
  Future<bool> dictRuleUpdate({
    required int id,
    required String name,
    required String urlRule,
    required String showRule,
  }) => bridge.dictRuleUpdate(
    id: id,
    name: name,
    urlRule: urlRule,
    showRule: showRule,
  );

  @override
  Future<bool> dictRuleDelete(int id) => bridge.dictRuleDelete(id: id);

  @override
  Future<bool> dictRuleSetEnabled({required int id, required bool enabled}) =>
      bridge.dictRuleSetEnabled(id: id, enabled: enabled);

  @override
  Future<int> dictRuleReorder(String idsJson) =>
      bridge.dictRuleReorder(idsJson: idsJson);

  @override
  Future<int> dictRuleImport({
    required String jsonOrUrl,
    required String kind,
  }) => bridge.dictRuleImport(jsonOrUrl: jsonOrUrl, kind: kind);

  // ========== 应用日志（appLog FFI） ==========
  // [审计修复 §1.2] 接通契约 §2.38 appLog* 五方法（frb 绑定已生成） — QoderCN

  @override
  Future<void> appLogPush({required String level, required String message}) =>
      bridge.appLogPush(level: level, message: message);

  @override
  Future<String> appLogList({required String level}) =>
      bridge.appLogList(level: level);

  @override
  Future<void> appLogClear({required String level}) =>
      bridge.appLogClear(level: level);

  @override
  Future<void> appLogClearAll() => bridge.appLogClearAll();

  @override
  Future<String> appLogExport() => bridge.appLogExport();
}
