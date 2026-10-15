// rust_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 RustApiSearchRss mixin：换源与封面搜索。
// RustApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 解码辅助来自 RustApiDecode（on 约束），同一 library 内私有成员可直接访问。
part of 'rust_api.dart';

mixin RustApiSearchRss on RustApiDecode implements BookApi {
  /// 搜索可替换的书源
  ///
  /// Rust 侧返回 SourceSwitchResponse { book_name, author, matches }，
  /// 兼容 Map（提取 matches 字段）和 List（直接使用）两种格式。
  /// [UI-fix v2.0.3 | 2026-08-06] 留项#12（Task #131）：新增 sourceUrls 可选参数，
  /// 编码为 sourceUrlsJson 传入 sourceSwitchSearch；null=搜全部启用源（兼容既有语义） — QoderCN
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
    final urlsJson = sourceUrls != null ? jsonEncode(sourceUrls) : '[]';
    final optionsJson = jsonEncode({
      'loadInfo': loadInfo,
      'loadToc': loadToc,
      'loadWordCount': loadWordCount,
      'forceRefresh': forceRefresh,
    });
    final json = await bridge.sourceSwitchSearch(
      bookName: bookName,
      author: author,
      sourceUrlsJson: urlsJson,
      optionsJson: optionsJson,
    );
    final decoded = jsonDecode(json);
    // Rust 侧返回 SourceSwitchResponse 对象，需提取 matches 字段
    final List<dynamic> list;
    if (decoded is Map<String, dynamic>) {
      list = (decoded['matches'] as List<dynamic>?) ?? [];
    } else if (decoded is List<dynamic>) {
      list = decoded;
    } else {
      list = [];
    }
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// 换源搜索流式版（T6 / 契约 §2.4 `searchSourceStream`）
  ///
  /// 每完成一个书源推送一批次 Map，字段：`source_index` / `source_url` /
  /// `source_name` / `error`（单源失败）/ `finished_count` / `total_count` /
  /// `is_last` / `matches`（当前已过滤评分候选**全量快照**——UI 直接替换展示）。
  /// DB 复用路径推单批即结束；enrich 开启时末批为增强后重排快照。
  /// [BookApi.searchSource] 保留为非流式兼容路径。 — Qoder UI
  @override
  Stream<Map<String, dynamic>> searchSourceStream(
    String bookName,
    String author, {
    List<String>? sourceUrls,
    bool loadInfo = false,
    bool loadToc = false,
    bool loadWordCount = false,
    bool forceRefresh = false,
  }) {
    final urlsJson = sourceUrls != null ? jsonEncode(sourceUrls) : '[]';
    final optionsJson = jsonEncode({
      'loadInfo': loadInfo,
      'loadToc': loadToc,
      'loadWordCount': loadWordCount,
      'forceRefresh': forceRefresh,
    });
    return bridge
        .sourceSwitchSearchStream(
          bookName: bookName,
          author: author,
          sourceUrlsJson: urlsJson,
          optionsJson: optionsJson,
        )
        .map((batch) => _decodeMap(batch, 'searchSourceStream'));
  }

  /// 搜索书籍封面候选列表
  ///
  /// Rust 侧复用多书源搜索提取封面 URL，返回 JSON 数组，
  /// 每项字段：`url` / `width` / `height`（未知尺寸填 0）。
  @override
  Future<List<Map<String, dynamic>>> searchCover(String bookName) async {
    final json = await bridge.searchCover(bookName: bookName);
    final list = _decodeList(json, 'bookApi');
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// 切换书源
  @override
  Future<String> switchSource(
    String bookUrl,
    String newSourceUrl,
    String newBookUrl,
  ) => bridge.sourceSwitchApply(
    bookUrl: bookUrl,
    newSourceUrl: newSourceUrl,
    newBookUrl: newBookUrl,
  );

  /// 切换书源（预拉缓存版，2026-09-24 加法式；命中零网络/未命中现场抓取可取消）
  @override
  Future<String> switchSourcePrefetch(
    String bookUrl,
    String newSourceUrl,
    String newBookUrl,
  ) => bridge.sourceSwitchApplyPrefetch(
    bookUrl: bookUrl,
    newSourceUrl: newSourceUrl,
    newBookUrl: newBookUrl,
  );

  /// 取消进行中的「换源（预拉缓存版）」应用（对齐上游 cancelChangeSource）
  @override
  Future<void> cancelSwitchSourceApply() => bridge.sourceSwitchApplyCancel();

  /// 更新换源列表项用户评分（-1/0/1）
  @override
  Future<void> updateSearchBookScore(String bookUrl, int score) =>
      bridge.updateSearchBookScore(bookUrl: bookUrl, score: score);

  /// 删除换源列表项（按 bookUrl）
  @override
  Future<void> deleteSearchBook(String bookUrl) =>
      bridge.deleteSearchBook(bookUrl: bookUrl);
}
