import '../bridge/rust_errors.dart';
import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/reading_content_service.dart';

/// 复用原引擎设置及章级KV，不建立Dart偏好副本。— Codex + Bridge
class RustReadingContentService implements ReadingContentService {
  const RustReadingContentService();
  @override
  Future<void> setChineseConvertType(int type) => rustFuture(
    () => bridge.readerSetChineseConvert(convertType: type),
    operation: 'readerSetChineseConvert',
  );
  @override
  Future<int> getChineseConvertType() => rustFuture(
    () => bridge.readerGetChineseConvert(),
    operation: 'readerGetChineseConvert',
  );
  @override
  Future<void> toggleSameTitleRemoved(
    String bookUrl,
    int chapterIndex,
    bool enable,
  ) => rustFuture(
    () => bridge.readerToggleSameTitleRemoved(
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
      enable: enable,
    ),
    operation: 'readerToggleSameTitleRemoved',
  );
  @override
  Future<bool> getSameTitleRemoved(String bookUrl, int chapterIndex) =>
      rustFuture(
        () => bridge.readerGetSameTitleRemoved(
          bookUrl: bookUrl,
          chapterIndex: chapterIndex,
        ),
        operation: 'readerGetSameTitleRemoved',
      );
  @override
  Future<bool> canRemoveSameTitle(String chapterTitle, String rawContent) =>
      rustFuture(
        () => bridge.readerCanRemoveSameTitle(
          chapterTitle: chapterTitle,
          rawContent: rawContent,
        ),
        operation: 'readerCanRemoveSameTitle',
      );
}
