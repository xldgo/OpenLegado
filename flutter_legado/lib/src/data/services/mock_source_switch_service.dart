import '../../domain/contracts/source_switch_service.dart';
import '../../domain/contracts/bookshelf_repository.dart';
import '../../domain/contracts/book_source_repository.dart';
import '../../domain/models/source_switch_batch.dart';
import '../../models/models.dart';

/// 共用书架记录，模拟候选状态；不模拟真实规则与预拉命中。— Codex + Bridge
final class MockSourceSwitchService implements SourceSwitchService {
  MockSourceSwitchService({required this._bookshelf, required this._sources});
  final BookshelfRepository _bookshelf;
  final BookSourceRepository _sources;
  final Map<(String, String), List<SourceMatch>> _results = {};
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
    final all = _results.putIfAbsent((bookName, author), () {
      const names = ['消消乐听书', '笔趣阁', '起点中文网'];
      const urls = [
        'https://www.kaixin7days.com',
        'https://www.biquge.com.cn',
        'https://www.qidian.com',
      ];
      return List.generate(
        3,
        (i) => SourceMatch(
          sourceUrl: urls[i],
          sourceName: names[i],
          bookUrl: 'mock://switch/$bookName/$i',
          bookName: bookName,
          author: author,
          latestChapter: '最新章节${i + 1}',
          wordCount: '${100 + i * 50}万字',
          score: 90.0 - i * 10,
        ),
      );
    });
    return all
        .where(
          (m) =>
              sourceUrls == null ||
              sourceUrls.isEmpty ||
              sourceUrls.contains(m.sourceUrl),
        )
        .toList();
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
  }) async* {
    final all = await searchSource(
      bookName,
      author,
      sourceUrls: sourceUrls,
      loadInfo: loadInfo,
      loadToc: loadToc,
      loadWordCount: loadWordCount,
      forceRefresh: forceRefresh,
    );
    if (all.isEmpty) {
      yield SourceSwitchBatch(isLast: true);
    }
    for (var i = 0; i < all.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      yield SourceSwitchBatch(
        sourceIndex: i,
        sourceUrl: all[i].sourceUrl,
        sourceName: all[i].sourceName,
        finishedCount: i + 1,
        totalCount: all.length,
        isLast: i == all.length - 1,
        matches: all.take(i + 1).toList(),
      );
    }
  }

  @override
  Future<Book> switchSource(
    String bookUrl,
    String newSourceUrl,
    String newBookUrl,
  ) async {
    final book = await _bookshelf.getBook(bookUrl);
    if (book == null) throw StateError('书籍不存在：$bookUrl');
    if (newBookUrl.isEmpty) throw ArgumentError('新源详情页地址不能为空');
    final sources = await _sources.getBookSources();
    final source = sources
        .where((s) => s.bookSourceUrl == newSourceUrl)
        .firstOrNull;
    final updated = book.copyWith(
      origin: newSourceUrl,
      originName: source?.bookSourceName ?? newSourceUrl,
      originBookUrl: newBookUrl,
    );
    await _bookshelf.updateBook(updated);
    return updated;
  }

  @override
  Future<Book> switchSourcePrefetch(
    String bookUrl,
    String newSourceUrl,
    String newBookUrl,
  ) => switchSource(bookUrl, newSourceUrl, newBookUrl);
  @override
  Future<void> cancelSwitchSourceApply() async {}
  @override
  Future<void> updateSearchBookScore(String bookUrl, int score) async {
    if (score < -1 || score > 1) throw ArgumentError('评分仅允许-1、0、1');
    var found = false;
    for (final list in _results.values) {
      final index = list.indexWhere((m) => m.bookUrl == bookUrl);
      if (index >= 0) {
        list[index] = list[index].copyWith(bookScore: score);
        found = true;
      }
    }
    if (!found) throw StateError('候选不存在：$bookUrl');
  }

  @override
  Future<void> deleteSearchBook(String bookUrl) async {
    var found = false;
    for (final list in _results.values) {
      final before = list.length;
      list.removeWhere((m) => m.bookUrl == bookUrl);
      found = found || before != list.length;
    }
    if (!found) throw StateError('候选不存在：$bookUrl');
  }
}
