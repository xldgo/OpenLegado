import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/reading_content_service.dart';

/// 复用原引擎设置及章级KV，不建立Dart偏好副本。— Codex + Bridge
class RustReadingContentService implements ReadingContentService {
  const RustReadingContentService();
  @override
  Future<void> setChineseConvertType(int type) =>
      bridge.readerSetChineseConvert(convertType: type);
  @override
  Future<int> getChineseConvertType() => bridge.readerGetChineseConvert();
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
}
