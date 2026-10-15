// rust_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 RustApiDiscoveryCache mixin：分组 / 搜索历史 / 缓存 / 章节购买 / WebBook / 发现页。
// RustApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 解码辅助来自 RustApiDecode（on 约束），同一 library 内私有成员可直接访问。
part of 'rust_api.dart';

mixin RustApiDiscoveryCache on RustApiDecode implements BookApi {
  // ========== 图片磁盘缓存（对齐原版 BookHelp.saveImage/getImage，契约 §2.46） ==========

  /// [P4-2a | 2026-09-29] 接通 save_image_cache FFI（契约 §2.46 image_cache）：
  /// bytes 先 base64 编码跨 FFI（对齐 fetchImageWithDecode 的 base64 约定）；
  /// 任何异常统一降级 `false`（写失败不影响在线加载，对齐原版 saveImage
  /// catch 仅记日志不抛异常语义）。
  @override
  Future<bool> saveImageCache({
    required String bookUrl,
    required String url,
    required List<int> bytes,
  }) async {
    try {
      return await bridge.saveImageCache(
        bookUrl: bookUrl,
        url: url,
        bytesBase64: base64Encode(bytes),
      );
    } catch (e) {
      debugPrint('[RustApi] saveImageCache 失败（降级在线加载）：$e');
      return false;
    }
  }

  /// [P4-2a | 2026-09-29] 接通 get_image_cache FFI（契约 §2.46 image_cache）：
  /// 命中 → base64 解码返回图片字节；未命中/读失败/FFI 异常统一降级
  /// `null`（调用方回落网络加载，对齐原版 mangaImagePath 本地优先语义）。
  @override
  Future<List<int>?> getImageCache(String bookUrl, String url) async {
    try {
      final b64 = await bridge.getImageCache(bookUrl: bookUrl, url: url);
      if (b64 == null || b64.isEmpty) return null;
      return base64Decode(b64);
    } catch (e) {
      debugPrint('[RustApi] getImageCache 失败（降级在线加载）：$e');
      return null;
    }
  }

  // ========== 音频章节文件缓存（对齐原版 AudioCacheManager，契约 §2.47） ==========

  /// [B1 | 2026-10-04] 接通 audio_cache_query FFI（契约 §2.47）：
  /// 查询失败/FFI 异常统一降级 `false`（按未缓存处理，播放链回落在线取流，
  /// 缓存是加速器不是数据源）。
  @override
  Future<bool> audioCacheQuery({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
  }) async {
    try {
      return await bridge.audioCacheQuery(
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
        chapterUrl: chapterUrl,
        chapterTitle: chapterTitle,
      );
    } catch (e) {
      debugPrint('[RustApi] audioCacheQuery 失败（降级未缓存）：$e');
      return false;
    }
  }

  /// [B1 | 2026-10-04] 接通 audio_cache_list FFI（契约 §2.47）：
  /// 返回已缓存章节下标（`Int32List` 即 `List<int>`，升序去重）；
  /// 失败/FFI 异常统一降级空数组（按无缓存处理）。
  @override
  Future<List<int>> audioCacheList({required String bookUrl}) async {
    try {
      return await bridge.audioCacheList(bookUrl: bookUrl);
    } catch (e) {
      debugPrint('[RustApi] audioCacheList 失败（降级空列表）：$e');
      return const <int>[];
    }
  }

  /// [B1 | 2026-10-04] 接通 audio_cache_clear_chapter FFI（契约 §2.47）：
  /// 返回实际删除文件数（含 `.complete` 标记）；失败/FFI 异常统一降级 `0`
  /// （幂等语义下与「已清理」同义）。
  @override
  Future<int> audioCacheClearChapter({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
  }) async {
    try {
      return await bridge.audioCacheClearChapter(
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
        chapterUrl: chapterUrl,
        chapterTitle: chapterTitle,
      );
    } catch (e) {
      debugPrint('[RustApi] audioCacheClearChapter 失败（降级 0）：$e');
      return 0;
    }
  }

  /// [B1 | 2026-10-04] 接通 audio_cache_clear_book FFI（契约 §2.47）：
  /// 返回实际删除文件数；失败/FFI 异常统一降级 `0`（幂等语义下与「已清理」同义）。
  @override
  Future<int> audioCacheClearBook({required String bookUrl}) async {
    try {
      return await bridge.audioCacheClearBook(bookUrl: bookUrl);
    } catch (e) {
      debugPrint('[RustApi] audioCacheClearBook 失败（降级 0）：$e');
      return 0;
    }
  }

  // ========== 音频章节预下载写入面（契约 §2.48） ==========

  /// [B2 | 2026-10-03] 接通 audio_cache_download FFI（契约 §2.48）：
  /// 直通返回安装结果 JSON（`installed`/`already_cached`）。
  /// **不做 catch 降级**——写入是显式用户动作，失败必须上抛驱动批量循环
  /// 计 failCount（契约 §2.48「失败语义」有意区别于 §2.47 读面）。
  @override
  Future<String> audioCacheDownload({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
    required String playUrl,
  }) => bridge.audioCacheDownload(
    bookUrl: bookUrl,
    chapterIndex: chapterIndex,
    chapterUrl: chapterUrl,
    chapterTitle: chapterTitle,
    playUrl: playUrl,
  );

  /// [B2 | 2026-10-03] 接通 audio_cache_cancel FFI（契约 §2.48）：
  /// 取消在途下载（进程级取消代数单槽）。同步立即返回；
  /// `true` = 置位时快照到在途下载（尽力提示），`false` = 当前无在途。
  @override
  Future<bool> audioCacheCancel() => bridge.audioCacheCancel();

  // ========== 视频弹幕（契约 §2.49，V-B1） ==========

  /// 查询某章弹幕数据（只读、幂等；降级路径返回 null）
  ///
  /// 直通 FFI：Rust 侧已完成「章节 variable inline → 大数据文件」归一
  /// （`DanmakuSource` 三态），Dart 侧无需解析，原样透传 `String?`。
  /// FFI 不可用/调用异常统一降级 `null`（弹幕是增强层不是数据源，
  /// 对齐 §2.46 口径）；Rust 侧本身也已对内部失败降级 `null`。
  @override
  Future<String?> getVideoDanmaku({
    required String bookUrl,
    required int chapterIndex,
  }) async {
    try {
      return await bridge.getVideoDanmaku(
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
      );
    } catch (e) {
      debugPrint('[RustApi] getVideoDanmaku 失败（降级 null）：$e');
      return null;
    }
  }

  // ========== 视频弹幕解析（契约 §2.50，V-B2） ==========

  /// 解析 B 站弹幕 XML（Rust 纯函数；降级路径返回 null）
  ///
  /// 直通 FFI 后仅做 JSON 解码 + 模型映射，不含 XML 语义逻辑（p 属性、
  /// 类型过滤、实体解码均在 Rust）。FFI 不可用 / 返回 null / JSON 形状
  /// 异常统一降级 `null`（弹幕是增强层不是数据源，对齐 §2.50 口径）。
  @override
  Future<List<VideoDanmakuItem>?> parseVideoDanmaku({
    required String raw,
  }) async {
    try {
      final json = await bridge.parseVideoDanmaku(raw: raw);
      if (json == null) return null;
      final decoded = jsonDecode(json);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(VideoDanmakuItem.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[RustApi] parseVideoDanmaku 失败（降级 null）：$e');
      return null;
    }
  }

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
