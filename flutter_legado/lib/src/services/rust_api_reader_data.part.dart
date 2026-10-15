// rust_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 RustApiReaderData mixin：阅读器 / 配置 / 备份 / 阅读记录。
// RustApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 解码辅助来自 RustApiDecode（on 约束），同一 library 内私有成员可直接访问。
part of 'rust_api.dart';

mixin RustApiReaderData on RustApiDecode implements BookApi {
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
}
