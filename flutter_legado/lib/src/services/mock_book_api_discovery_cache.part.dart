// mock_book_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 MockBookApiDiscoveryCache mixin：分组 / 搜索历史 / 缓存 / 章节购买 / WebBook / 发现页。
// MockBookApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 内存存储字段来自 MockBookApiStore（on 约束），同一 library 内私有成员可直接访问。
part of 'mock_book_api.dart';

mixin MockBookApiDiscoveryCache on MockBookApiStore implements BookApi {
  // ========== 章节购买 ==========

  @override
  Future<({String kind, String value})> chapterPayAction({
    required String bookUrl,
    required int chapterIndex,
  }) async => (kind: 'none', value: '');

  @override
  Future<Map<String, dynamic>> sourceCallBackBtn({
    required String event,
    required String bookUrl,
    int? chapterIndex,
    String? result,
    int bookType = 0,
  }) async => {
    'invoked': false,
    'jsTrue': false,
    'raw': '',
    'actions': <dynamic>[],
  };

  // ========== WebBook 操作 ==========

  @override
  Future<String> webbookSearch(
    String sourceJson,
    String query,
    int page,
  ) async => jsonEncode([]);

  @override
  Future<String> webbookInfo(String sourceJson, String bookUrl) async =>
      jsonEncode({'name': 'Mock书籍', 'author': 'Mock作者'});

  @override
  Future<String> webbookChapters(
    String sourceJson,
    String bookUrl, {
    String tocUrl = '',
    String bookName = '',
  }) async => jsonEncode([]);

  @override
  Future<String> webbookContent(String sourceJson, String chapterJson) async =>
      '（Mock 章节内容）';

  @override
  Stream<Map<String, dynamic>> debugBookSourceStream(
    String sourceUrl,
    String key,
  ) async* {
    yield {'state': 1, 'msg': '[00:00.000] ⇒开始搜索关键字:$key'};
    yield {'state': 1, 'msg': '[00:00.010] 书源 URL: $sourceUrl'};
    yield {'state': 1000, 'msg': '[00:00.020] ︽Mock 调试完成'};
  }

  @override
  Future<void> cancelDebugBookSource() async {}

  // ========== 发现页操作 ==========

  @override
  Future<List<ExploreCategory>> exploreParseUrl(
    String exploreUrl, {
    String sourceJson = '',
  }) async {
    if (exploreUrl.isEmpty) return [];
    return exploreUrl.split('\n').where((l) => l.contains('::')).map((line) {
      final parts = line.split('::');
      return ExploreCategory(
        title: parts[0].trim(),
        url: parts.length > 1 ? parts[1].trim() : '',
      );
    }).toList();
  }

  @override
  Future<List<SearchBook>> exploreFetchBooks(
    String sourceJson,
    String url,
    int page,
  ) async {
    return List.generate(10, (i) {
      return SearchBook(
        bookUrl: 'mock://explore/$url/$page/$i',
        name: '发现书籍 ${(page - 1) * 10 + i + 1}',
        author: '作者${i + 1}',
        coverUrl: 'https://www.biquge.com.cn/files/article/image/${i + 1}.jpg',
        intro: '发现页书籍简介',
        origin: 'https://www.biquge.com.cn',
        originName: '笔趣阁',
        latestChapterTitle: '最新章节',
      );
    });
  }

  final Map<String, Map<String, String>> _exploreInfoMaps = {};

  @override
  Future<void> exploreInfoMapPut(
    String sourceUrl,
    String key,
    String value,
  ) async {
    _exploreInfoMaps.putIfAbsent(sourceUrl, () => {})[key] = value;
  }

  @override
  Future<void> exploreInfoMapEnsureDefault(
    String sourceUrl,
    String key,
    String defaultValue,
  ) async {
    final map = _exploreInfoMaps.putIfAbsent(sourceUrl, () => {});
    map.putIfAbsent(key, () => defaultValue);
  }

  @override
  Future<String> exploreInfoMapSnapshot(String sourceUrl) async =>
      jsonEncode(_exploreInfoMaps[sourceUrl] ?? const <String, String>{});

  @override
  Future<Map<String, dynamic>> exploreEvalAction({
    required String sourceJson,
    required String actionJs,
  }) async {
    return {
      'raw': '',
      'actions': <dynamic>[],
      'refreshExplore': actionJs.contains('refreshExplore'),
    };
  }

  @override
  Future<String> exploreEvalUiJs({
    required String sourceJson,
    required String jsStr,
  }) async => jsStr;
}
