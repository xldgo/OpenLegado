// mock_book_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 MockBookApiSearchRss mixin：搜索 / 本地书籍 / TXT 全文搜索。
// MockBookApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 内存存储字段来自 MockBookApiStore（on 约束），同一 library 内私有成员可直接访问。
part of 'mock_book_api.dart';

mixin MockBookApiSearchRss on MockBookApiStore implements BookApi {
  @override
  Future<List<Map<String, dynamic>>> searchSource(
    String bookName,
    String author, {
    List<String>? sourceUrls,
    bool loadInfo = false,
    bool loadToc = false,
    bool loadWordCount = false,
    bool forceRefresh = false,
  }) async {
    // forceRefresh 仅真实后端消费；Mock 忽略
    // ignore: unused_local_variable
    final _ = forceRefresh;
    const srcNames = ['消消乐听书', '笔趣阁', '起点中文网'];
    const srcUrls = [
      'https://www.kaixin7days.com',
      'https://www.biquge.com.cn',
      'https://www.qidian.com',
    ];
    // 对齐 Rust `SourceMatch` 的 snake_case 序列化（按 score 降序，Rust 侧已排序）
    final all = List.generate(
      3,
      (i) => {
        'source_url': srcUrls[i],
        'source_name': srcNames[i],
        'book_url': 'mock://switch/$bookName/$i',
        'book_name': bookName,
        'author': author,
        'latest_chapter': '最新章节${i + 1}',
        'word_count': '${100 + i * 50}万字',
        'score': 90.0 - i * 10,
      },
    );
    // [UI-fix v2.0.3 | 2026-08-06] 留项#12（Task #131）：模拟 sourceUrls 过滤语义，
    // 非空列表时仅返回指定书源的候选 — QoderCN
    if (sourceUrls != null && sourceUrls.isNotEmpty) {
      return all.where((m) => sourceUrls.contains(m['source_url'])).toList();
    }
    return all;
  }

  /// T6 Mock：模拟逐源完成的渐进推送（对齐 Rust `ChangeSourceBatch` 批次字段；
  /// `matches` 为累积候选全量快照——与 [searchSource] 同源数据按到达顺序累积）
  @override
  Stream<Map<String, dynamic>> searchSourceStream(
    String bookName,
    String author, {
    List<String>? sourceUrls,
    bool loadInfo = false,
    bool loadToc = false,
    bool loadWordCount = false,
    bool forceRefresh = false,
  }) async* {
    // forceRefresh 仅真实后端消费；Mock 忽略
    // ignore: unused_local_variable
    final _ = forceRefresh;
    const srcNames = ['消消乐听书', '笔趣阁', '起点中文网'];
    const srcUrls = [
      'https://www.kaixin7days.com',
      'https://www.biquge.com.cn',
      'https://www.qidian.com',
    ];
    // 与 searchSource 同源的候选全集（snake_case，score 降序）
    final all = List.generate(
      3,
      (i) => {
        'source_url': srcUrls[i],
        'source_name': srcNames[i],
        'book_url': 'mock://switch/$bookName/$i',
        'book_name': bookName,
        'author': author,
        'latest_chapter': '最新章节${i + 1}',
        'word_count': '${100 + i * 50}万字',
        'score': 90.0 - i * 10,
      },
    );
    // sourceUrls 过滤语义（与 searchSource 一致）
    final pool = (sourceUrls != null && sourceUrls.isNotEmpty)
        ? all.where((m) => sourceUrls.contains(m['source_url'])).toList()
        : all;
    if (pool.isEmpty) {
      yield {
        'source_index': 0,
        'source_url': '',
        'source_name': '',
        'error': null,
        'finished_count': 0,
        'total_count': 0,
        'is_last': true,
        'matches': <Map<String, dynamic>>[],
      };
      return;
    }
    // 模拟逐源完成：每轮追加一个候选（累积快照），末批 is_last
    var accumulated = <Map<String, dynamic>>[];
    for (var i = 0; i < pool.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      accumulated = [...accumulated, pool[i]];
      yield {
        'source_index': i,
        'source_url': pool[i]['source_url'],
        'source_name': pool[i]['source_name'],
        'error': null,
        'finished_count': i + 1,
        'total_count': pool.length,
        'is_last': i == pool.length - 1,
        'matches': accumulated,
      };
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchCover(String bookName) async {
    // 模拟网络延迟
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // 按书名生成确定性候选封面（占位数据，字段对齐 Rust `CoverCandidate`）
    final base = bookName.hashCode.abs();
    return List.generate(
      5,
      (i) => {
        'url': 'https://picsum.photos/seed/${base + i}/240/320',
        'width': 240,
        'height': 320,
      },
    );
  }

  @override
  Future<String> switchSource(
    String bookUrl,
    String newSourceUrl,
    String newBookUrl,
  ) async {
    return newBookUrl;
  }

  /// 预拉缓存版 mock：命中语义无法在纯 mock 表达，直通 [switchSource]；
  /// 计数供单测断言「选中命中后不再触发第二次抓取」（call count）
  int prefetchApplyCallCount = 0;
  int cancelApplyCallCount = 0;

  @override
  Future<String> switchSourcePrefetch(
    String bookUrl,
    String newSourceUrl,
    String newBookUrl,
  ) async {
    prefetchApplyCallCount++;
    return switchSource(bookUrl, newSourceUrl, newBookUrl);
  }

  @override
  Future<void> cancelSwitchSourceApply() async {
    cancelApplyCallCount++;
  }

  final Map<String, int> _searchBookScores = {};

  @override
  Future<void> updateSearchBookScore(String bookUrl, int score) async {
    _searchBookScores[bookUrl] = score;
  }

  @override
  Future<void> deleteSearchBook(String bookUrl) async {
    _searchBookScores.remove(bookUrl);
  }

  // ========== 本地书籍操作 ==========

  @override
  Future<Book> importLocalBook(String filePath) async {
    await _ensureBooksLoaded();
    // [cbz 批 C | 2026-10-03] 与 Rust `import_local_book` 对齐：`.cbz` 图片
    // 漫画包额外带 image(64) 媒体位（LOCAL|image=0x1040），其余本地格式仅
    // LOCAL；位域语义见 BookType（book.dart），勿用 == 单值比较。
    final isCbz = filePath.toLowerCase().endsWith('.cbz');
    final book = Book(
      bookUrl: 'file://$filePath',
      name: filePath
          .split(RegExp(r'[/\\]'))
          .last
          .replaceAll(RegExp(r'\.\w+$'), ''),
      author: '本地导入',
      bookType: isCbz ? BookType.local | BookType.image : BookType.local,
    );
    _books.add(book);
    return book;
  }

  @override
  Future<List<Map<String, dynamic>>> scanLocalBooks(String dirPath) async {
    return [
      {
        'path': '$dirPath/book1.txt',
        'name': 'book1.txt',
        'size': 102400,
        'lastModified': DateTime.now().toIso8601String(),
      },
      {
        'path': '$dirPath/book2.epub',
        'name': 'book2.epub',
        'size': 2048000,
        'lastModified': DateTime.now().toIso8601String(),
      },
    ];
  }

  @override
  Future<String> detectFormat(String filePath) async {
    if (filePath.endsWith('.epub')) return 'epub';
    if (filePath.endsWith('.pdf')) return 'pdf';
    return 'txt';
  }

  @override
  Future<String> parseMetadata(String filePath) async {
    return jsonEncode({'title': '未知书籍', 'author': '未知作者', 'format': 'txt'});
  }

  // ========== 本地 TXT 全文搜索（Task #98 缺口#4，加法式新增） ==========

  /// 构造 Mock 搜索结果（字段结构对齐 Rust TxtSearchResult）
  List<Map<String, dynamic>> _mockTxtSearchResults(String query) {
    return [
      {
        'chapter_index': 0,
        'chapter_title': '第一章 测试章节',
        'char_offset': 42,
        'matched_text': query,
        'context': '……这是包含 $query 的上下文摘要……',
        'context_match_start': 6,
        'context_match_end': 6 + query.length,
      },
      {
        'chapter_index': 1,
        'chapter_title': '第二章 后续发展',
        'char_offset': 108,
        'matched_text': query,
        'context': '……另一处包含 $query 的正文片段……',
        'context_match_start': 8,
        'context_match_end': 8 + query.length,
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> txtSearch(
    String path,
    String query, {
    bool caseSensitive = false,
    int maxResults = 500,
  }) async {
    if (query.isEmpty) return [];
    return _mockTxtSearchResults(query);
  }

  @override
  Future<List<Map<String, dynamic>>> txtSearchRegex(
    String path,
    String pattern, {
    bool caseSensitive = false,
    int maxResults = 500,
  }) async {
    if (pattern.isEmpty) return [];
    return _mockTxtSearchResults(pattern);
  }

  @override
  Future<List<Map<String, dynamic>>> txtSearchInChapter(
    String path,
    String query,
    int chapterIndex, {
    bool caseSensitive = false,
    int maxResults = 50,
  }) async {
    if (query.isEmpty) return [];
    return _mockTxtSearchResults(query)
        .where((r) => r['chapter_index'] == chapterIndex)
        .toList();
  }

  @override
  Future<int> txtSearchCount(
    String path,
    String query, {
    bool caseSensitive = false,
  }) async {
    if (query.isEmpty) return 0;
    return 2;
  }
}
