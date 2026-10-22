import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/book_source_query_service.dart';
import '../../models/models.dart';
import '../bridge/entity_dto_mapping.dart';
import '../bridge/content_dto_mapping.dart';

/// 已解析的书源实体直接进入抓取链，不在查询中写库。— Codex + Bridge
final class RustBookSourceQueryService implements BookSourceQueryService {
  const RustBookSourceQueryService();
  @override
  Future<Book> getBookInfo(
    BookSource source,
    String pageUrl, {
    Book? existingBook,
    bool canReName = true,
  }) async => webBookInfoFromDto(
    await rustFuture(
      () => bridge.webbookInfo(
        source: bookSourceToDto(source),
        bookUrl: pageUrl,
        existingBook: existingBook == null ? null : bookToDto(existingBook),
        canReName: canReName,
      ),
      operation: 'webbookInfo',
    ),
    source,
  );
  @override
  Future<List<BookChapter>> getChapters(
    BookSource source,
    String pageUrl, {
    required String bookUrl,
    String tocUrl = '',
    String bookName = '',
  }) async => (await rustFuture(
    () => bridge.webbookChapters(
      source: bookSourceToDto(source),
      bookUrl: pageUrl,
      tocUrl: tocUrl,
      bookName: bookName,
    ),
    operation: 'webbookChapters',
  )).map((value) => webChapterFromDto(value, bookUrl)).toList();
}
