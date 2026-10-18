import 'dart:convert';

import '../../../domain/contracts/book_source_query_service.dart';
import '../../../domain/contracts/book_source_repository.dart';
import '../../../domain/contracts/bookshelf_repository.dart';
import '../../../domain/contracts/network_service.dart';
import '../../../domain/contracts/search_service.dart';
import '../../../models/models.dart';

/// 导入结果不携带界面文案，由页面按当前语言展示。— Codex + UI
sealed class BookshelfImportResult {
  const BookshelfImportResult();
}

final class BookshelfImportSummary extends BookshelfImportResult {
  const BookshelfImportSummary({
    required this.added,
    required this.skipped,
    required this.failed,
  });

  final int added;
  final int skipped;
  final int failed;
}

final class BookshelfImportInvalid extends BookshelfImportResult {
  const BookshelfImportInvalid();
}

final class BookshelfImportFetchFailed extends BookshelfImportResult {
  const BookshelfImportFetchFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

/// 复用窄接口编排导入，不持有Widget/Ref，不拥有书架数据。— Codex + UI
final class BookshelfImportController {
  const BookshelfImportController({
    required this._bookshelf,
    required this._sources,
    required this._sourceQuery,
    required this._search,
    required this._network,
    required this._currentBooks,
    this._log,
  });

  final BookshelfRepository _bookshelf;
  final BookSourceRepository _sources;
  final BookSourceQueryService _sourceQuery;
  final SearchService _search;
  final NetworkService _network;
  final List<Book> Function() _currentBooks;
  final void Function(String)? _log;

  Future<BookshelfImportSummary> addByUrls(
    List<String> urls,
    String fallbackName,
  ) async {
    final existingUrls = _currentBooks().map((b) => b.bookUrl).toSet();
    List<BookSource> sources;
    try {
      sources = await _sources.getEnabledBookSources();
    } catch (_) {
      sources = const [];
    }
    var added = 0, skipped = 0, failed = 0;
    for (final url in urls) {
      if (existingUrls.contains(url)) {
        skipped++;
        continue;
      }
      try {
        final source = _matchSource(sources, url);
        // 沿用当前无匹配书源时创建裸网页书籍的行为。
        final book = source == null
            ? Book(
                bookUrl: url,
                name: fallbackName.isNotEmpty ? fallbackName : url,
                originName: '网页书籍',
              )
            : await _sourceQuery.getBookInfo(source, url);
        await _bookshelf.addBook(book);
        existingUrls.add(url);
        added++;
      } catch (error) {
        failed++;
        _log?.call('添加网址失败 $url: $error');
      }
    }
    return BookshelfImportSummary(
      added: added,
      skipped: skipped,
      failed: failed,
    );
  }

  Future<BookshelfImportResult> importBookshelf(String input) async {
    var content = input;
    if (content.startsWith('http://') || content.startsWith('https://')) {
      try {
        final response = await _network.httpGet(content);
        if (!response.isSuccess) {
          throw StateError('HTTP ${response.statusCode}');
        }
        content = response.body.trim();
      } catch (error, stack) {
        return BookshelfImportFetchFailed(error, stack);
      }
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      decoded = null;
    }
    if (decoded is! List) return const BookshelfImportInvalid();
    // URL书单下载完成后才取书架快照，与原页面时序一致。
    final existing = _currentBooks()
        .map((b) => '${b.name}|${b.author}')
        .toSet();
    List<String> enabledUrls;
    try {
      enabledUrls = (await _sources.getEnabledBookSources())
          .map((s) => s.bookSourceUrl)
          .toList();
    } catch (_) {
      enabledUrls = const [];
    }
    var added = 0, skipped = 0, failed = 0;
    for (final item in decoded) {
      if (item is! Map) continue;
      final name = (item['name'] ?? '').toString().trim();
      final author = (item['author'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      if (existing.contains('$name|$author')) {
        skipped++;
        continue;
      }
      try {
        final hit = await _search.preciseSearch(
          name,
          author,
          sourceUrls: enabledUrls.isEmpty ? null : enabledUrls,
        );
        await _bookshelf.addBook(SearchResult.fromSearchBook(hit).book);
        existing.add('$name|$author');
        added++;
      } catch (error) {
        failed++;
        _log?.call('导入书单条目失败《$name》: $error');
      }
    }
    return BookshelfImportSummary(
      added: added,
      skipped: skipped,
      failed: failed,
    );
  }

  BookSource? _matchSource(List<BookSource> sources, String url) {
    for (final source in sources) {
      final pattern = source.bookUrlPattern;
      if (pattern == null || pattern.isEmpty) continue;
      try {
        if (RegExp(pattern).hasMatch(url)) return source;
      } catch (_) {
        // 非法正则仍可参与之后的域名匹配。
      }
    }
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty) {
      for (final source in sources) {
        final sourceUri = Uri.tryParse(source.bookSourceUrl);
        if (sourceUri != null && sourceUri.host == uri.host) return source;
      }
    }
    return null;
  }
}
