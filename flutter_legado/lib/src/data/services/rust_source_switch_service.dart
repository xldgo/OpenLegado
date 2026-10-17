import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/source_switch_service.dart';
import '../../domain/models/source_switch_batch.dart';
import '../../models/models.dart';
import '../../bridge/transfer_dto.dart' as dto;
import '../bridge/entity_dto_mapping.dart';
import '../bridge/stream_dto_mapping.dart';
import '../bridge/managed_rust_stream.dart';

/// 复用既有换源事务与取消，不在Dart复制匹配逻辑。— Codex + Bridge
final class RustSourceSwitchService implements SourceSwitchService {
  const RustSourceSwitchService();
  dto.SwitchSearchOptionsDto _options(
    bool info,
    bool toc,
    bool count,
    bool refresh,
  ) => dto.SwitchSearchOptionsDto(
    loadInfo: info,
    loadToc: toc,
    loadWordCount: count,
    forceRefresh: refresh,
  );
  @override
  Future<List<SourceMatch>> searchSource(
    String bookName,
    String author, {
    List<String>? sourceUrls,
    bool loadInfo = false,
    bool loadToc = false,
    bool loadWordCount = false,
    bool forceRefresh = false,
  }) async {
    final result = await bridge.sourceSwitchSearch(
      bookName: bookName,
      author: author,
      sourceUrls: sourceUrls ?? [],
      options: _options(loadInfo, loadToc, loadWordCount, forceRefresh),
    );
    return result.matches.map(sourceMatchFromDto).toList();
  }

  @override
  Stream<SourceSwitchBatch> searchSourceStream(
    String bookName,
    String author, {
    List<String>? sourceUrls,
    bool loadInfo = false,
    bool loadToc = false,
    bool loadWordCount = false,
    bool forceRefresh = false,
  }) => managedRustStream(
    (request) => bridge.sourceSwitchSearchStream(
      bookName: bookName,
      author: author,
      sourceUrls: sourceUrls ?? [],
      options: _options(loadInfo, loadToc, loadWordCount, forceRefresh),
      request: request,
    ),
  ).map(switchBatchFromDto);
  Book _book(dto.BookDto value, String bookUrl) {
    final book = bookFromDto(value);
    if (book.bookUrl.isEmpty || book.bookUrl != bookUrl) {
      throw const FormatException('换源返回的书籍主键不匹配');
    }
    return book;
  }

  @override
  Future<Book> switchSource(
    String bookUrl,
    String newSourceUrl,
    String newBookUrl,
  ) async => _book(
    await bridge.sourceSwitchApply(
      bookUrl: bookUrl,
      newSourceUrl: newSourceUrl,
      newBookUrl: newBookUrl,
    ),
    bookUrl,
  );
  @override
  Future<Book> switchSourcePrefetch(
    String bookUrl,
    String newSourceUrl,
    String newBookUrl,
  ) async => _book(
    await bridge.sourceSwitchApplyPrefetch(
      bookUrl: bookUrl,
      newSourceUrl: newSourceUrl,
      newBookUrl: newBookUrl,
    ),
    bookUrl,
  );
  @override
  Future<void> cancelSwitchSourceApply() => bridge.sourceSwitchApplyCancel();
  @override
  Future<void> updateSearchBookScore(String bookUrl, int score) =>
      bridge.updateSearchBookScore(bookUrl: bookUrl, score: score);
  @override
  Future<void> deleteSearchBook(String bookUrl) =>
      bridge.deleteSearchBook(bookUrl: bookUrl);
}
