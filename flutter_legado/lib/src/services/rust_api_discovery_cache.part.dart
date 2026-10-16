// rust_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 RustApiDiscoveryCache mixin：分组 / 搜索历史 / 缓存 / 章节购买 / WebBook / 发现页。
// RustApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 解码辅助来自 RustApiDecode（on 约束），同一 library 内私有成员可直接访问。
part of 'rust_api.dart';

mixin RustApiDiscoveryCache on RustApiDecode implements BookApi {
  // ========== 章节购买 ==========

  /// 执行章节购买动作（契约 §2.43.2，对照 Kotlin ReadBookActivity.payAction）
  ///
  /// 解析 Rust 返回的 `{"kind": ..., "value": ...}` JSON 为元组；
  /// kind 缺失时视为 none，value 缺失时视为空串。
  /// [UI-fix v2.0.3 | 2026-08-08] — QoderCN
  @override
  Future<({String kind, String value})> chapterPayAction({
    required String bookUrl,
    required int chapterIndex,
  }) async {
    final json = await bridge.chapterPayAction(
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
    );
    final map = _decodeMap(json, 'chapterPayAction');
    return (
      kind: (map['kind'] ?? 'none').toString(),
      value: (map['value'] ?? '').toString(),
    );
  }

  @override
  Future<Map<String, dynamic>> sourceCallBackBtn({
    required String event,
    required String bookUrl,
    int? chapterIndex,
    String? result,
    int bookType = 0,
  }) async {
    final json = await bridge.sourceCallBackBtn(
      event: event,
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
      result: result,
      bookType: bookType,
    );
    return _decodeMap(json, 'sourceCallBackBtn');
  }

  // ========== WebBook 操作 ==========
  // 以下解析类方法统一经平台桥接拦截（Task #114）：Rust 侧 webView 类 JS API
  // 无头运行时返回桥接载荷 JSON，恰为整体结果时由此执行并以真实结果回填 — QoderCN

  /// 搜索书籍（书源规则驱动）
  @override
  Future<String> webbookSearch(
    String sourceJson,
    String query,
    int page,
  ) async => PlatformBridgeService.instance.interceptResult(
    await bridge.webbookSearch(
      sourceJson: sourceJson,
      query: query,
      page: page,
    ),
  );

  /// 获取书籍详情
  @override
  Future<String> webbookInfo(String sourceJson, String bookUrl) async =>
      PlatformBridgeService.instance.interceptResult(
        await bridge.webbookInfo(sourceJson: sourceJson, bookUrl: bookUrl),
      );

  /// 获取章节列表
  @override
  Future<String> webbookChapters(
    String sourceJson,
    String bookUrl, {
    String tocUrl = '',
    String bookName = '',
  }) async => PlatformBridgeService.instance.interceptResult(
    await bridge.webbookChapters(
      sourceJson: sourceJson,
      bookUrl: bookUrl,
      tocUrl: tocUrl,
      bookName: bookName,
    ),
  );

  /// 获取章节正文
  @override
  Future<String> webbookContent(String sourceJson, String chapterJson) async =>
      PlatformBridgeService.instance.interceptResult(
        await bridge.webbookContent(
          sourceJson: sourceJson,
          chapterJson: chapterJson,
        ),
      );

  /// 流式书源调试（对齐 Debug.Callback）
  @override
  Stream<Map<String, dynamic>> debugBookSourceStream(
    String sourceUrl,
    String key,
  ) => bridge
      .debugBookSourceStream(sourceUrl: sourceUrl, key: key)
      .map((item) => _decodeMap(item, 'debugBookSourceStream'));

  /// 取消正在进行的书源调试
  @override
  Future<void> cancelDebugBookSource() async {
    await bridge.debugBookSourceCancel();
  }

  // ========== 发现页操作 ==========

  /// 解析 exploreUrl 为分类列表
  ///
  /// 返回 `List<ExploreCategory>`，每项包含 title 和 url。
  /// 对标 Android BookSourceExtensions.exploreKinds()
  @override
  Future<List<ExploreCategory>> exploreParseUrl(
    String exploreUrl, {
    String sourceJson = '',
  }) async {
    final json = await bridge.exploreParseUrl(
      exploreUrl: exploreUrl,
      sourceJson: sourceJson,
    );
    final list = _decodeList(json, 'bookApi');
    return list
        .map((e) => ExploreCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 抓取发现分类的书籍列表
  ///
  /// [sourceJson] — BookSource JSON 字符串
  /// [url] — 分类 URL
  /// [page] — 页码（从 1 开始）
  ///
  /// 返回 `List<SearchBook>`，对标 Android WebBook.exploreBookAwait
  @override
  Future<List<SearchBook>> exploreFetchBooks(
    String sourceJson,
    String url,
    int page,
  ) async {
    // 平台桥接拦截（Task #114）— QoderCN
    final json = await PlatformBridgeService.instance.interceptResult(
      await bridge.exploreFetchBooks(
        sourceJson: sourceJson,
        url: url,
        page: page,
      ),
    );
    final list = _decodeList(json, 'bookApi');
    // [UI-fix v2.0.3 | 2026-08-06] 发现分类返回的是 Rust WebSearchResult
    // （snake_case：book_url/cover_url/source_url，且无 origin/originName），
    // 与 SearchBook.fromJson 期望的 camelCase 键不一致，直接 fromJson 会丢失
    // bookUrl/origin/coverUrl → 详情页因 origin 为空无法联网补全目录/封面
    // （未入库书共 0 章 / 无封面）。此处显式归一化，并用本次发现所属书源
    // 补齐 origin/originName（同源批量，权威）。 — Qoder
    String srcUrl = '';
    String srcName = '';
    try {
      final sm = jsonDecode(sourceJson);
      if (sm is Map) {
        srcUrl = (sm['bookSourceUrl'] ?? sm['book_source_url'] ?? '')
            .toString();
        srcName = (sm['bookSourceName'] ?? sm['book_source_name'] ?? '')
            .toString();
      }
    } catch (_) {}
    return list
        .map(
          (e) => _searchBookFromExplore(
            e as Map<String, dynamic>,
            srcUrl,
            srcName,
          ),
        )
        .toList();
  }

  @override
  Future<void> exploreInfoMapPut(String sourceUrl, String key, String value) =>
      bridge.exploreInfoMapPut(sourceUrl: sourceUrl, key: key, value: value);

  @override
  Future<void> exploreInfoMapEnsureDefault(
    String sourceUrl,
    String key,
    String defaultValue,
  ) => bridge.exploreInfoMapEnsureDefault(
    sourceUrl: sourceUrl,
    key: key,
    defaultValue: defaultValue,
  );

  /// 读取发现 infoMap 快照（JSON 对象字符串）— 发现页修复 B①
  @override
  Future<String> exploreInfoMapSnapshot(String sourceUrl) =>
      bridge.exploreInfoMapSnapshot(sourceUrl: sourceUrl);

  @override
  Future<Map<String, dynamic>> exploreEvalAction({
    required String sourceJson,
    required String actionJs,
  }) async {
    final json = await bridge.exploreEvalAction(
      sourceJson: sourceJson,
      actionJs: actionJs,
    );
    return _decodeMap(json, 'exploreEvalAction');
  }

  @override
  Future<String> exploreEvalUiJs({
    required String sourceJson,
    required String jsStr,
  }) => bridge.exploreEvalUiJs(sourceJson: sourceJson, jsStr: jsStr);

  /// 将发现分类返回的 WebSearchResult 归一化为 SearchBook。
  /// 兼容 snake_case 与 camelCase 两种键名；origin/originName 用所属书源补齐，
  /// 避免 Rust 侧字段命名差异导致 origin 丢失（未入库书详情页无法联网取目录/封面）。
  SearchBook _searchBookFromExplore(
    Map<String, dynamic> e,
    String sourceUrl,
    String sourceName,
  ) {
    String? pick(String camel, String snake) {
      final v = e[camel] ?? e[snake];
      final s = v?.toString();
      return (s != null && s.isNotEmpty) ? s : null;
    }

    return SearchBook(
      bookUrl: _absoluteUrl(
        pick('origin', 'source_url') ?? sourceUrl,
        pick('bookUrl', 'book_url'),
      ),
      origin: pick('origin', 'source_url') ?? sourceUrl,
      originName: pick('originName', 'source_name') ?? sourceName,
      name: pick('name', 'name') ?? '',
      author: pick('author', 'author') ?? '',
      kind: pick('kind', 'kind'),
      coverUrl: _absoluteUrlOrNull(
        pick('origin', 'source_url') ?? sourceUrl,
        pick('coverUrl', 'cover_url'),
      ),
      intro: pick('intro', 'intro'),
      wordCount: pick('wordCount', 'word_count'),
      latestChapterTitle: pick('latestChapterTitle', 'latest_chapter'),
      tocUrl: pick('tocUrl', 'toc_url') ?? '',
      // 类型位标记（Rust WebSearchResult 序列化键为 type；漫画/听书/视频源
      // 据此分流阅读器，缺省 0=文本）— 发现页修复 A8
      bookType: e['type'] is int
          ? e['type'] as int
          : (int.tryParse(e['type']?.toString() ?? '') ?? 0),
    );
  }

  /// 将可能为相对路径的 URL 解析为绝对 URL（对标原版 NetworkUtils.getAbsoluteURL）。
  /// 发现/搜索返回的 book_url 可能是相对路径（如 /book/65308/），直接传给
  /// webbookInfo/webbookChapters 会导致 reqwest “builder error”。以书源基地址补齐。
  String _absoluteUrl(String base, String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty || base.isEmpty) return u;
    if (u.contains('://') || u.startsWith('data:')) return u;
    try {
      return Uri.parse(base).resolve(u).toString();
    } catch (_) {
      return u;
    }
  }

  /// [_absoluteUrl] 的可空包装：空值返回 null（保持封面可空语义）。
  String? _absoluteUrlOrNull(String base, String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return null;
    return _absoluteUrl(base, u);
  }
}
