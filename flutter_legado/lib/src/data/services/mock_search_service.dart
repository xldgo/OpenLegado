import '../../domain/contracts/search_service.dart';
import '../../domain/models/search_batch.dart';
import '../../models/models.dart';
import '../bridge/search_batch_decode.dart';

/// 原搜索访问实现独立迁移，不重建或初始化运行时。— Codex + Bridge
final class MockSearchService implements SearchService {
  const MockSearchService();

  // ========== 搜索操作 ==========

  @override
  Future<List<SearchResult>> searchBooks(
    String keyword, {
    List<String>? sourceUrls,
  }) async {
    // 固定返回 5 条结果（模拟多源聚合搜索）
    const mockSourceNames = ['消消乐听书', '笔趣阁', '起点中文网'];
    return List.generate(5, (i) {
      final srcName = mockSourceNames[i % mockSourceNames.length];
      return SearchResult(
        sourceName: srcName,
        book: Book(
          bookUrl: 'mock://search/$keyword/$i',
          name: '$keyword 相关书籍${i + 1}',
          author: '作者${i + 1}',
          coverUrl:
              'https://www.biquge.com.cn/files/article/image/${i + 1}.jpg',
          intro: '这是搜索"$keyword"的第${i + 1}条结果简介。',
          latestChapterTitle: '最新章节',
          origin: 'https://www.kaixin7days.com',
          originName: srcName,
        ),
      );
    });
  }

  @override
  Future<SearchBook> preciseSearch(
    String name,
    String author, {
    List<String>? sourceUrls,
  }) async {
    return SearchBook(
      name: name,
      author: author,
      bookUrl: 'mock://precise/$name',
      origin: 'https://www.kaixin7days.com',
      originName: '消消乐听书',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> searchMulti(
    String query, {
    List<String>? sourceUrls,
  }) async {
    const srcNames = ['消消乐听书', '笔趣阁', '起点中文网'];
    return List.generate(
      3,
      (i) => {
        'source': srcNames[i],
        'count': 5,
        'results': <Map<String, dynamic>>[],
      },
    );
  }

  @override
  Stream<SearchBatch> searchMultiStream(
    String query, {
    List<String>? sourceUrls,
    int page = 1,
  }) async* {
    const srcNames = ['消消乐听书', '笔趣阁', '起点中文网'];
    const srcUrls = [
      'https://www.kaixin7days.com',
      'https://www.biquge.com.cn',
      'https://www.qidian.com',
    ];
    final total = srcNames.length;
    for (var i = 0; i < total; i++) {
      // 模拟逐源完成的渐进推送
      await Future<void>.delayed(const Duration(milliseconds: 120));
      yield decodeSearchBatch({
        'source_index': i,
        'source_url': srcUrls[i],
        'source_name': srcNames[i],
        'books': List.generate(
          2,
          (j) => {
            'origin': srcUrls[i],
            'originName': srcNames[i],
            // 源级 BookType（对齐原版 getBookType：text=8/audio=32）
            'type': i == 0 ? 32 : 8,
            'name': '$query 相关书籍${i * 2 + j + 1}',
            'author': '作者${i * 2 + j + 1}',
            'bookUrl': 'mock://search/$query/${i}_$j',
            'kind': i == 0 ? '都市,轻松' : '玄幻,热血',
            'wordCount': '${(i * 2 + j + 1) * 12}万字',
            'latestChapterTitle': '最新章节',
            'intro': '渐进搜索“$query”的结果。',
            'coverUrl': null,
          },
        ),
        'error': null,
        'finished_count': i + 1,
        'total_count': total,
        'is_last': i == total - 1,
        // 批次B G-B-02：Mock 批次恒有下一页（非末批语义），与 Rust has_more 累积值对齐
        'has_more': true,
      });
    }
  }

  @override
  Future<void> cancelSearch() async {}

  // 批次B G-B-04：Mock 无真实并发调度，暂停/恢复为空操作（保持接口一致性）
  @override
  Future<void> pauseSearch() async {}

  @override
  Future<void> resumeSearch() async {}
}
