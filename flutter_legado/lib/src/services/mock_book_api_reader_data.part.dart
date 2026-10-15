// mock_book_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 MockBookApiReaderData mixin：阅读器 / 配置 / 备份 / 阅读记录。
// MockBookApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 内存存储字段来自 MockBookApiStore（on 约束），同一 library 内私有成员可直接访问。
part of 'mock_book_api.dart';

mixin MockBookApiReaderData on MockBookApiStore implements BookApi {
  // ========== 阅读器操作 ==========

  /// 繁简转换类型 Mock 持久化键（与 Rust 侧配置键同名）
  static const _chineseConvertKey = 'chineseConverterType';

  @override
  Future<void> setChineseConvertType(int type) async {
    // 非法取值归一为 0，与 Rust 侧语义对齐
    final normalized = (type >= 0 && type <= 2) ? type : 0;
    _configs[_chineseConvertKey] = normalized.toString();
  }

  @override
  Future<int> getChineseConvertType() async {
    return int.tryParse(_configs[_chineseConvertKey] ?? '') ?? 0;
  }

  /// 章级「删除重复标题」opt-out 记录（契约 §2.9.10，Task #50）
  ///
  /// Mock 内存态：集合内存放「保留原标题」的 `${bookUrl}#$chapterIndex`。
  final Set<String> _sameTitleOptOut = {};

  @override
  Future<void> toggleSameTitleRemoved(
    String bookUrl,
    int chapterIndex,
    bool enable,
  ) async {
    // Mock：短延迟模拟 FFI 往返；enable=true 恢复全局默认，false 章级 opt-out
    await Future.delayed(const Duration(milliseconds: 50));
    final key = '$bookUrl#$chapterIndex';
    if (enable) {
      _sameTitleOptOut.remove(key);
    } else {
      _sameTitleOptOut.add(key);
    }
  }

  @override
  Future<bool> getSameTitleRemoved(String bookUrl, int chapterIndex) async {
    return !_sameTitleOptOut.contains('$bookUrl#$chapterIndex');
  }

  @override
  Future<bool> canRemoveSameTitle(
    String chapterTitle,
    String rawContent,
  ) async {
    if (chapterTitle.isEmpty || rawContent.isEmpty) return false;
    return rawContent.trimLeft().startsWith(chapterTitle);
  }

  // ========== 配置操作 ==========

  @override
  Future<String?> getConfig(String key) async => _configs[key];

  @override
  Future<void> setConfig(String key, String value) async {
    _configs[key] = value;
  }

  @override
  Future<void> deleteConfig(String key) async {
    _configs.remove(key);
  }

  @override
  Future<Map<String, String>> getAllConfigs() async => Map.from(_configs);
}
