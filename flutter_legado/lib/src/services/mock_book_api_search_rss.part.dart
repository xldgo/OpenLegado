// mock_book_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 MockBookApiSearchRss mixin：换源与封面搜索。
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
}
