import '../../domain/contracts/reading_content_service.dart';

/// 与根配置共享繁简值；仅记录章级开关，不模拟真实转换和缓存。— Codex + Bridge
class MockReadingContentService implements ReadingContentService {
  MockReadingContentService({required this._configs});
  final Map<String, String> _configs;
  final Set<(String, int)> _sameTitleOptOut = {};
  @override
  Future<void> setChineseConvertType(int type) async {
    final normalized = type >= 0 && type <= 2 ? type : 0;
    _configs['chineseConverterType'] = '$normalized';
  }

  @override
  Future<int> getChineseConvertType() async =>
      int.tryParse(_configs['chineseConverterType'] ?? '') ?? 0;
  @override
  Future<void> toggleSameTitleRemoved(
    String bookUrl,
    int chapterIndex,
    bool enable,
  ) async {
    if (enable) {
      _sameTitleOptOut.remove((bookUrl, chapterIndex));
    } else {
      _sameTitleOptOut.add((bookUrl, chapterIndex));
    }
  }

  @override
  Future<bool> getSameTitleRemoved(String bookUrl, int chapterIndex) async =>
      !_sameTitleOptOut.contains((bookUrl, chapterIndex));
  @override
  Future<bool> canRemoveSameTitle(
    String chapterTitle,
    String rawContent,
  ) async =>
      chapterTitle.isNotEmpty &&
      rawContent.isNotEmpty &&
      rawContent.trimLeft().startsWith(chapterTitle);
}
