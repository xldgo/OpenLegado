import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/source_switch_service.dart';
import '../../domain/models/source_switch_batch.dart';
import '../../models/models.dart';
import '../bridge/rust_json_decode.dart';

/// 复用既有换源事务与取消，不在Dart复制匹配逻辑。— Codex + Bridge
final class RustSourceSwitchService implements SourceSwitchService {
  const RustSourceSwitchService();
  String _options(bool info, bool toc, bool count, bool refresh) => jsonEncode({
    'loadInfo': info,
    'loadToc': toc,
    'loadWordCount': count,
    'forceRefresh': refresh,
  });
  List<SourceMatch> _matches(Object? value) {
    if (value is! List) throw const FormatException('换源候选必须是数组');
    return value.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('换源候选必须是对象');
      }
      return SourceMatch.fromJson(entry);
    }).toList();
  }

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
    final result = decodeRustJsonMap(
      await bridge.sourceSwitchSearch(
        bookName: bookName,
        author: author,
        sourceUrlsJson: jsonEncode(sourceUrls ?? []),
        optionsJson: _options(loadInfo, loadToc, loadWordCount, forceRefresh),
      ),
      'sourceSwitchSearch',
    );
    return _matches(result['matches']);
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
  }) => bridge
      .sourceSwitchSearchStream(
        bookName: bookName,
        author: author,
        sourceUrlsJson: jsonEncode(sourceUrls ?? []),
        optionsJson: _options(loadInfo, loadToc, loadWordCount, forceRefresh),
      )
      .map((raw) {
        final value = decodeRustJsonMap(raw, 'sourceSwitchSearchStream');
        return SourceSwitchBatch(
          sourceIndex: value['source_index'] as int? ?? 0,
          sourceUrl: value['source_url'] as String? ?? '',
          sourceName: value['source_name'] as String? ?? '',
          error: value['error'] as String?,
          finishedCount: value['finished_count'] as int? ?? 0,
          totalCount: value['total_count'] as int? ?? 0,
          isLast: value['is_last'] as bool? ?? false,
          matches: _matches(value['matches']),
        );
      });
  Book _book(String raw, String bookUrl) {
    final book = Book.fromJson(decodeRustJsonMap(raw, 'sourceSwitchApply'));
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
