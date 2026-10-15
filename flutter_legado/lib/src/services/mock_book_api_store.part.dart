// mock_book_api.dart 的 part 文件（体检 §三.16 超长文件拆分）：内存数据存储。
// 各分域 mixin 以 on MockBookApiStore 获得存储字段访问。
part of 'mock_book_api.dart';

mixin MockBookApiStore {
  // ========== 内存数据存储 ==========

  late final MockBookshelfStore _bookshelfStore;
  List<Book> get _books => _bookshelfStore.books;
  late final MockBookSourceStore _bookSourceStore;
  List<BookSource> get _sources => _bookSourceStore.sources;
  final Map<String, String> _configs = {};
  final Map<String, List<BookChapter>> _chaptersCache = {};
  final Map<String, Map<int, String>> _contentCache = {};
  // 图片磁盘缓存内存模拟（契约 §2.46 saveImageCache/getImageCache；
  // Mock 模式以内存 Map 模拟 Rust 侧 MD5 文件落盘，key = bookUrl\u0000url）
  final Map<String, List<int>> _imageCache = {};
  // 登录凭据内存态（sourceLogin 手动登录/登录缓存，USE_MOCK 开发模式用）

  int _nextId = 1;

  /// 初始化 Mock 数据
  ///
  /// 数据来源见文件头注释。书源/RSS/TTS 取自
  /// Android 原端 app/src/main/assets/defaultData/ 下真实 JSON（内置字面量）；
  /// 书架书籍为合成脱敏样例，经资产 assets/mock_data/bookshelf_sample.json
  /// 惰性加载（MockBookApi 构造器保持同步，资产读取为异步，
  /// 各书架相关方法先 await [_ensureBooksLoaded]）。
  void _initMockData() {
    // ── 书源（来源：app/src/main/assets/defaultData/bookSources.json）──
    // 基于原 Android 内置「消消乐听书」音频源结构，扩充为 3 条贴近真实书源。
    _sources.addAll([
      BookSource(
        bookSourceUrl: 'https://www.kaixin7days.com',
        bookSourceName: '消消乐听书',
        bookSourceGroup: '听书',
        bookSourceType: 1, // 音频源
        enabled: true,
        enabledExplore: true,
        exploreUrl: '玄幻::https://www.kaixin7days.com/book-service/bookMgt/getAllBookByCategroyId\n都市::https://www.kaixin7days.com/book-service/bookMgt/getAllBookByCategroyId',
        searchUrl: 'https://www.kaixin7days.com/book-service/bookMgt/findBookName,{"method":"POST","body":{"title": "searchKey","pageNum": 1,"pageSize": 100}}',
        customOrder: 0,
        lastUpdateTime: 1630656684531,
        respondTime: 180000,
        weight: 0,
      ),
      BookSource(
        bookSourceUrl: 'https://www.biquge.com.cn',
        bookSourceName: '笔趣阁',
        bookSourceGroup: '网文',
        bookSourceType: 0, // 文本源
        enabled: true,
        enabledExplore: true,
        exploreUrl: '玄幻::https://www.biquge.com.cn/xuanhuan/\n仙侠::https://www.biquge.com.cn/xianxia/\n都市::https://www.biquge.com.cn/dushi/',
        searchUrl: 'https://www.biquge.com.cn/s?q=searchKey',
        customOrder: 1,
        lastUpdateTime: 1630656684531,
        respondTime: 180000,
        weight: 0,
      ),
      BookSource(
        bookSourceUrl: 'https://www.qidian.com',
        bookSourceName: '起点中文网',
        bookSourceGroup: '网文',
        bookSourceType: 0,
        enabled: false, // 需登录，默认禁用
        enabledExplore: true,
        exploreUrl: '热门::https://www.qidian.com/rank/hotsales/\n新书::https://www.qidian.com/rank/newbook/',
        searchUrl: 'https://www.qidian.com/so/searchKey/',
        customOrder: 2,
        lastUpdateTime: 1630656684531,
        respondTime: 180000,
        weight: 0,
      ),
    ]);
  }

  /// 书架样例资产路径（合成脱敏数据；来源与脱敏口径见
  /// assets/mock_data/README.md，结构对齐 Book 模型 & API_CONTRACT §2.2）
  static const String _bookshelfSampleAsset =
      'assets/mock_data/bookshelf_sample.json';

  /// 书架样例惰性加载守卫：首次调用时从资产读取 bookshelf_sample.json，
  /// 填充 _books 与章节/正文缓存；之后各书架相关方法 await 本守卫即可
  /// （同一 Future 记忆化，并发调用只加载一次）。
  Future<void> _ensureBooksLoaded() => _bookshelfStore.ensureLoaded();

  /// 从资产加载书架样例并填充 _books 与章节/正文缓存
  Future<void> _loadBookshelfSample() async {
    final raw = await rootBundle.loadString(_bookshelfSampleAsset);
    final list = jsonDecode(raw) as List<dynamic>;
    _books.addAll(
      list.map((e) => Book.fromJson(e as Map<String, dynamic>)).toList(),
    );
    // 每本书生成至多 10 章（章节标题模拟真实网文目录风格）
    for (final book in _books) {
      final count = book.totalChapterNum < 10
          ? (book.totalChapterNum < 1 ? 1 : book.totalChapterNum)
          : 10;
      final chapters = <BookChapter>[];
      final contents = <int, String>{};
      for (var j = 0; j < count; j++) {
        chapters.add(
          BookChapter(
            title: '第${j + 1}章 ${_mockChapterTitles[j]}',
            bookUrl: book.bookUrl,
            url: 'mock://chapter/${book.bookUrl}/$j',
            index: j,
            start: j * 2000,
            end: (j + 1) * 2000,
          ),
        );
        contents[j] = _generateMockContent(book, j);
      }
      _chaptersCache[book.bookUrl] = chapters;
      _contentCache[book.bookUrl] = contents;
    }
  }

  static const _mockChapterTitles = [
    '初入江湖',
    '风云际会',
    '暗流涌动',
    '绝地反击',
    '峰回路转',
    '真相大白',
    '生死一线',
    '破茧成蝶',
    '天下大势',
    '尘埃落定',
  ];

  /// 生成 Mock 章节正文（足够排版引擎分页）
  String _generateMockContent(Book book, int chapterIndex) {
    final paragraphs = <String>[];
    final bookName = book.name;
    paragraphs.add('    这是《$bookName》第${chapterIndex + 1}章的正文内容。');
    for (var i = 0; i < 15; i++) {
      paragraphs.add(
        '    第${i + 1}段：修炼之路漫漫其修远兮，吾将上下而求索。'
        '天地之间，灵气充沛，万物生长。'
        '少年立于山巅，俯瞰苍茫大地，心中豪情万丈。'
        '远处的云海翻涌如潮，金色的阳光穿透云层洒落人间。'
        '他深吸一口气，感受着体内真气的流转，每一步都踏得坚实有力。',
      );
    }
    return paragraphs.join('\n\n');
  }
}
