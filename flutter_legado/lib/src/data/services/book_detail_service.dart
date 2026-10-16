import '../../domain/contracts/book_source_query_service.dart';
import '../../domain/contracts/book_source_repository.dart';
import '../../domain/contracts/bookshelf_repository.dart';
import '../../domain/contracts/reading_repository.dart';
import '../../domain/models/book_detail_data.dart';
import '../../domain/services/book_metadata_policy.dart';
import '../../models/models.dart';

/// 详情与目录的查询、合并和写回共用同一次依赖装配。— Codex + Bridge
class BookDetailService {
  BookDetailService({
    required this._bookshelf,
    required this._reading,
    required this._sources,
    required this._query,
    void Function(String)? log,
  }) : _log = log ?? _ignoreLog;

  final BookshelfRepository _bookshelf;
  final ReadingRepository _reading;
  final BookSourceRepository _sources;
  final BookSourceQueryService _query;
  final void Function(String) _log;
  static void _ignoreLog(String _) {}

  Future<BookDetailData> readLocal(BookDetailRequest request) async {
    final stored = request.bookUrl.isEmpty
        ? null
        : await _bookshelf.getBook(request.bookUrl);
    final inShelf = BookMetadataPolicy.resolveInBookshelf(stored, request.book);
    var book = !inShelf && request.book != null
        ? request.book
        : stored ?? request.book;
    if (!inShelf && book != null && stored != null) {
      book = BookMetadataPolicy.mergeDbBook(book, stored);
    }
    final chapters = request.bookUrl.isEmpty
        ? <BookChapter>[]
        : await _reading.getChapters(request.bookUrl);
    final source = book != null && BookMetadataPolicy.isOnlineBook(book)
        ? await findSource(book.origin)
        : null;
    return BookDetailData(
      book: book,
      chapters: chapters,
      source: source,
      inBookshelf: inShelf,
    );
  }

  bool needsCompletion(BookDetailData data) =>
      data.book != null &&
      BookMetadataPolicy.isOnlineBook(data.book!) &&
      data.source != null;

  /// 已有地址时并行，缺少地址时先补详情；普通失败保留已获得的数据。
  Stream<BookDetailData> complete(
    BookDetailData data, {
    required bool Function() isCurrent,
  }) async* {
    if (!needsCompletion(data) || !isCurrent()) return;
    var book = data.book!;
    final source = data.source!;
    var chapters = data.chapters;
    var shouldPersist = chapters.isEmpty;
    if (chapters.isEmpty) {
      final hasToc = book.tocUrl.isNotEmpty;
      final needInfo = BookMetadataPolicy.needsCompletion(book);
      if (hasToc && needInfo) {
        final infoFuture = _readInfo(book, source);
        final chaptersFuture = _readChapters(
          () => _queryChapters(book, source),
        );
        final info = await infoFuture;
        chapters = await chaptersFuture;
        if (!isCurrent()) return;
        if (info != null) book = BookMetadataPolicy.mergeWebInfo(book, info);
      } else if (hasToc) {
        chapters = await _readChapters(() => _queryChapters(book, source));
      } else {
        final info = await _readInfo(book, source);
        if (!isCurrent()) return;
        if (info != null) {
          book = BookMetadataPolicy.mergeWebInfo(book, info);
          yield data.copyWith(book: book);
        }
        if (!isCurrent()) return;
        chapters = await _readChapters(
          () => data.inBookshelf
              ? _reading.refreshToc(book.bookUrl, book.origin)
              : _queryChapters(book, source),
        );
      }
      if (chapters.isNotEmpty) {
        book = book.copyWith(totalChapterNum: chapters.length);
      }
    } else {
      final info = await _readInfo(book, source);
      if (info != null) {
        book = BookMetadataPolicy.mergeWebInfo(book, info, refresh: true);
        shouldPersist = true;
      }
    }
    if (!isCurrent()) return;
    if (data.inBookshelf && shouldPersist) {
      try {
        await _bookshelf.updateBook(book);
      } catch (error) {
        _log('更新书籍元数据失败: $error');
      }
    }
    if (isCurrent()) yield data.copyWith(book: book, chapters: chapters);
  }

  Future<Book?> _readInfo(Book book, BookSource source) async {
    try {
      return await _query.getBookInfo(
        source,
        BookMetadataPolicy.bookFetchUrl(book),
      );
    } catch (error) {
      _log('详情补全失败，保留现有字段: $error');
      return null;
    }
  }

  Future<List<BookChapter>> _readChapters(
    Future<List<BookChapter>> Function() query,
  ) async {
    try {
      return await query();
    } catch (error) {
      _log('目录查询失败，保留现有目录: $error');
      return const [];
    }
  }

  Future<List<BookChapter>> _queryChapters(Book book, BookSource source) =>
      _query.getChapters(
        source,
        BookMetadataPolicy.bookFetchUrl(book),
        bookUrl: book.bookUrl,
        tocUrl: book.tocUrl,
        bookName: book.name,
      );

  Future<BookSource?> findSource(String origin) async {
    String normalized(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');
    final key = normalized(origin);
    try {
      final sources = await _sources.getBookSources();
      for (final source in sources) {
        if (normalized(source.bookSourceUrl) == key ||
            source.bookSourceUrl == origin) {
          return source;
        }
      }
    } catch (error) {
      _log('获取书源失败: $error');
    }
    return null;
  }

  Future<List<BookChapter>> queryOnlineChapters(
    Book book, {
    BookSource? source,
  }) async {
    final resolved = source ?? await findSource(book.origin);
    return resolved == null ? const [] : _queryChapters(book, resolved);
  }

  Future<List<BookChapter>> refreshChapters(BookDetailData data) {
    final book = data.book;
    if (book == null) throw StateError('书籍信息不可用');
    return data.inBookshelf
        ? _reading.refreshToc(book.bookUrl, book.origin)
        : queryOnlineChapters(book, source: data.source);
  }
}
