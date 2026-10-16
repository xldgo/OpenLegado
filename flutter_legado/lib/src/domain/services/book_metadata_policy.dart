import '../../models/book.dart';
import 'book_type_policy.dart';

/// 详情字段合并、在架与抓取地址规则，不持有页面状态。— Codex + UI
class BookMetadataPolicy {
  BookMetadataPolicy._();

  /// 是否在线书籍（非本地、非 WebDAV）
  static bool isOnlineBook(Book book) =>
      book.origin.isNotEmpty &&
      book.origin != BookType.localTag &&
      !book.origin.startsWith(BookType.webDavTag);

  /// DB 记录是否已入书架（对标原版 inBookshelf = bookDao 有记录且非 notShelf）
  static bool isInBookshelf(Book? dbBook) =>
      dbBook != null && (dbBook.bookType & BookType.notShelf) == 0;

  /// refresh_toc 历史占位行：库内无名无作者，路由带完整元数据
  static bool isRefreshTocPlaceholder(Book dbBook, Book? routeBook) {
    if (routeBook == null) return false;
    return dbBook.name.trim().isEmpty &&
        dbBook.author.trim().isEmpty &&
        routeBook.name.trim().isNotEmpty;
  }

  /// 详情/目录页在架判定（排除 notShelf 与 refresh_toc 误插入占位）
  static bool resolveInBookshelf(Book? dbBook, Book? routeBook) {
    if (dbBook == null) return false;
    if ((dbBook.bookType & BookType.notShelf) != 0) return false;
    if (isRefreshTocPlaceholder(dbBook, routeBook)) return false;
    return true;
  }

  /// [P2-8 | P3-1 对齐 2026-09-18] 「抓取书籍页」地址选择：优先
  /// `originBookUrl`（当前书源下该书的详情页地址，换源事务与 preUpdateJs
  /// 钩子写入；bookUrl 作为稳定主键换源后可能仍是旧源地址），为空时回退
  /// `bookUrl`（未换源书籍与存量库行为不变，向后兼容）。
  ///
  /// 语义与 Rust `Book::book_page_fetch_url()` 完全一致：空值判定按
  /// **trim 后**（纯空白视同空值），返回值取字段原值（不 trim）。
  ///
  /// 详情页联网刷新（webbookInfo / webbookChapters 取址）一律经本方法取址，
  /// 保证换源后刷新用「当前书源详情页」而非「旧源地址」——台账 P2-8 根因
  /// 修复（此前用旧源地址套当前书源规则，字段解析为空/退化值写坏 tocUrl）。
  static String bookFetchUrl(Book book) {
    final origin = book.originBookUrl;
    return origin.trim().isNotEmpty ? origin : book.bookUrl;
  }

  /// [P2-4 | 2026-09-18] DB 记录补全路由带入瘦壳书（author/tocUrl/章节数
  /// 等）：路由非空字段优先保留（最新章标题等实时值），DB 非空字段仅填空。
  /// 本方法为纯函数公共静态（对齐 [mergeWebInfo] 的提取模式，可单测）。
  ///
  /// 唯一例外是 [Book.originBookUrl] —— **DB 优先**：换源事务是该字段的
  /// 唯一权威写者（preUpdateJs 钩子也是经 DB 写入，不写路由对象），路由
  /// 对象可能是未携带该字段或携带旧值的陈旧内存瘦壳；若路由优先会把换源
  /// 事务写入的「当前书源详情页地址」覆盖掉，后续详情刷新取址错误。
  /// 路由值仅作兜底（DB 记录缺该字段且为空时）。
  static Book mergeDbBook(Book routeBook, Book dbBook) {
    return routeBook.copyWith(
      coverUrl: (routeBook.coverUrl?.isNotEmpty ?? false)
          ? routeBook.coverUrl
          : dbBook.coverUrl,
      intro: (routeBook.intro?.isNotEmpty ?? false)
          ? routeBook.intro
          : dbBook.intro,
      tocUrl: routeBook.tocUrl.isNotEmpty ? routeBook.tocUrl : dbBook.tocUrl,
      wordCount: (routeBook.wordCount?.isNotEmpty ?? false)
          ? routeBook.wordCount
          : dbBook.wordCount,
      latestChapterTitle: (routeBook.latestChapterTitle?.isNotEmpty ?? false)
          ? routeBook.latestChapterTitle
          : dbBook.latestChapterTitle,
      kind: (routeBook.kind?.isNotEmpty ?? false)
          ? routeBook.kind
          : dbBook.kind,
      author: routeBook.author.isNotEmpty ? routeBook.author : dbBook.author,
      totalChapterNum: routeBook.totalChapterNum > 0
          ? routeBook.totalChapterNum
          : dbBook.totalChapterNum,
      // [P2-4] originBookUrl 以 DB 为权威（换源事务唯一权威写者），路由值仅兜底
      // [P2-11 §198] 空值判定按 trim 后（纯空白视同空值，与 [bookFetchUrl] 口径
      // 一致），取值仍取原值不 trim：DB 值纯空白时让位路由有效值，非空白仍覆盖
      originBookUrl: dbBook.originBookUrl.trim().isNotEmpty
          ? dbBook.originBookUrl
          : routeBook.originBookUrl,
    );
  }

  /// 合并数据层已解码的详情到 book（原始字段映射由查询服务处理，
  /// 不能直接 Book.fromJson 否则 cover_url/toc_url 等丢失）。
  /// - refresh=false（默认）：仅补全当前缺失字段（首屏补全语义）。
  /// - refresh=true（U7 进入刷新）：更新式合并——刷新非空值覆盖现有字段
  ///   （对齐原版 analyzeBookInfo 覆盖语义，刷新 kind 评分/分类/完结态、字数、
  ///   最新章等陈旧值）；刷新值为空时保留现有值（不用空覆盖）。
  /// - [换源后刷新守卫 | 2026-09-18 | 台账 P2-8] 根因修复后（进入刷新取址已
  ///   走 [bookFetchUrl]，即当前书源详情页），守卫降级为纵深防御：正常书籍页
  ///   解析必得书名（ruleBookInfo.name）；name 缺失即视为「未解析到书籍页」，
  ///   本次刷新整体跳过——宁可保留旧值，也不用错页结果覆盖。
  static Book mergeWebInfo(Book book, Book info, {bool refresh = false}) {
    String? nonEmpty(String? value) =>
        value != null && value.isNotEmpty ? value : null;

    if (refresh) {
      final freshName = nonEmpty(info.name);
      if (freshName == null) return book;
      final freshCover = nonEmpty(info.coverUrl);
      final freshIntro = nonEmpty(info.intro);
      final freshWord = nonEmpty(info.wordCount);
      final freshLast = nonEmpty(info.latestChapterTitle);
      final freshKind = nonEmpty(info.kind);
      final freshToc = nonEmpty(info.tocUrl);
      final freshAuthor = nonEmpty(info.author);
      // [P2-15 ②] 详情解析 type 回流：非零覆盖媒体位（JS 写值胜出），
      // 零值/缺键保留现有值（对齐上方 refresh 更新式合并的非空覆盖口径）
      final freshType = info.bookType;
      return book.copyWith(
        coverUrl: freshCover ?? book.coverUrl,
        intro: freshIntro ?? book.intro,
        tocUrl: freshToc ?? book.tocUrl,
        wordCount: freshWord ?? book.wordCount,
        latestChapterTitle: freshLast ?? book.latestChapterTitle,
        kind: freshKind ?? book.kind,
        name: freshName,
        author: freshAuthor ?? book.author,
        bookType: BookTypePolicy.mergeBookType(book.bookType, freshType),
      );
    }

    final hasCover = book.coverUrl != null && book.coverUrl!.isNotEmpty;
    final hasIntro = book.intro != null && book.intro!.isNotEmpty;
    final hasWord = book.wordCount != null && book.wordCount!.isNotEmpty;
    final hasLast =
        book.latestChapterTitle != null && book.latestChapterTitle!.isNotEmpty;
    final hasKind = book.kind != null && book.kind!.isNotEmpty;
    final tocUrl = nonEmpty(info.tocUrl);
    final name = nonEmpty(info.name);
    final author = nonEmpty(info.author);
    // [P2-15 ②] type 非「补全缺失」语义：详情解析是书籍模式权威来源
    // （二合一文本源入架时 bookType=8，详情 JS 写 64 → 必须覆盖切漫画
    // 模式），故非零新值同样覆盖媒体位；零值/缺键保留现有值
    final freshType = info.bookType;
    return book.copyWith(
      coverUrl: hasCover ? book.coverUrl : nonEmpty(info.coverUrl),
      intro: hasIntro ? book.intro : nonEmpty(info.intro),
      // [fix 2026-08-15] tocUrl 用详情解析出的权威值优先（七猫发现列表
      // book.tocUrl 默认=bookUrl，详情 qmBookInfo 生成真实 chapter-list URL）
      tocUrl: tocUrl ?? book.tocUrl,
      wordCount: hasWord ? book.wordCount : nonEmpty(info.wordCount),
      latestChapterTitle: hasLast
          ? book.latestChapterTitle
          : nonEmpty(info.latestChapterTitle),
      kind: hasKind ? book.kind : nonEmpty(info.kind),
      name: book.name.isNotEmpty ? book.name : (name ?? book.name),
      author: book.author.isNotEmpty ? book.author : (author ?? book.author),
      bookType: BookTypePolicy.mergeBookType(book.bookType, freshType),
    );
  }

  /// 缺少封面、简介或目录地址时需要补全详情。
  static bool needsCompletion(Book book) =>
      (book.coverUrl?.isEmpty ?? true) ||
      (book.intro?.isEmpty ?? true) ||
      book.tocUrl.isEmpty;
}
