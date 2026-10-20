import '../../models/book_source.dart';

/// 书源配置读写，不拥有搜索、登录或校验会话。— Codex + UI
abstract interface class BookSourceRepository {
  /// 获取所有书源
  Future<List<BookSource>> getBookSources();

  /// 获取所有启用的书源
  Future<List<BookSource>> getEnabledBookSources();

  /// 添加书源
  Future<BookSource> addBookSource(BookSource source);

  /// 更新书源
  Future<void> updateBookSource(BookSource source);

  /// 设置书源自定义变量（契约 §2.3 setSourceVariable，台账 §5.11-3，Task #63 冻结 / #64-65 实现）
  ///
  /// 对齐原版 `source.setVariable`：单列 UPDATE 语义仅更新 `variable` 单列，
  /// 规避 updateBookSource 全行更新风险；[variable] 为空串表示清除。
  /// 错误码：书源不存在 → Internal；写入失败 → Db。
  Future<void> setSourceVariable(String sourceUrl, String variable);

  /// 删除书源
  Future<void> deleteBookSource(String sourceUrl);

  /// 启用书源
  Future<void> enableBookSource(String sourceUrl);

  /// 禁用书源
  Future<void> disableBookSource(String sourceUrl);

  /// 批量导入书源，返回成功导入的数量
  Future<int> importBookSources(String jsonArray);

  /// 导出所有书源为 JSON 数组
  Future<String> exportBookSources();

  /// 书源排序
  Future<void> sortBookSources(int sortKey, bool ascending);
}
