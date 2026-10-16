/// 正文处理设置及章级规则，存储和实际转换仍由原引擎负责。— Codex + Bridge
abstract interface class ReadingContentService {
  /// 0不转换，1繁转简，2简转繁；非法值由引擎归零。
  Future<void> setChineseConvertType(int type);
  Future<int> getChineseConvertType();

  /// true恢复全局默认的去重行为，false在当前章节保留原标题。
  Future<void> toggleSameTitleRemoved(
    String bookUrl,
    int chapterIndex,
    bool enable,
  );
  Future<bool> getSameTitleRemoved(String bookUrl, int chapterIndex);
  Future<bool> canRemoveSameTitle(String chapterTitle, String rawContent);
}
