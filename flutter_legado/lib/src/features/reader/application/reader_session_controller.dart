import '../../../utils/error_message.dart';
import '../../../data/services/chapter_content_service.dart';
import '../../../domain/contracts/bookshelf_repository.dart';
import '../../../domain/contracts/reading_repository.dart';
import '../../../domain/contracts/read_record_repository.dart';
import '../../../domain/contracts/read_record_settings_repository.dart';
import '../../../models/models.dart';
import 'reader_state.dart';
import '../../../services/reader_position_store.dart';
import 'reader_session_host.dart';

/// 阅读会话编排；状态只由宿主持有，仓储与服务显式注入。— Codex + UI
final class ReaderSessionController {
  ReaderSessionController({
    required this._host,
    required this._reading,
    required this._bookshelf,
    required this._content,
    required this._records,
    required this._recordSettings,
    required this._positionStore,
    int Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final ReaderSessionHost _host;
  final ReadingRepository _reading;
  final BookshelfRepository _bookshelf;
  final ChapterContentService _content;
  final ReadRecordRepository _records;
  final ReadRecordSettingsRepository _recordSettings;
  final int Function() _clock;
  final ReaderPositionStore _positionStore;
  ReaderSourceAnchor? _sourceAnchor;
  String? _anchorBookUrl;
  int _readRecordSession = 0;
  int? _pendingReadStartMs;
  int _readStartMs = 0;
  int _baseReadTimeMs = 0;
  int _loadSeq = 0;
  int _openSeq = 0;
  bool _refreshing = false;
  bool _changeSourceFlowActive = false;
  bool _disposed = false;

  ReaderState get state => _host.readState();
  set state(ReaderState value) {
    if (!_disposed) _host.writeState(value);
  }

  static String chapterIdFor(BookChapter chapter, int index) =>
      chapter.url.isNotEmpty ? chapter.url : '$index:${chapter.title}';

  bool get isRefreshing => _refreshing;
  bool get isChangeSourceFlowActive => _changeSourceFlowActive;

  /// 销毁仅使在途结果失效，不访问已释放的宿主或取消底层共享能力。
  void dispose() {
    _disposed = true;
    _openSeq++;
    _loadSeq++;
    _readRecordSession++;
  }

  int? get currentSourceOffset {
    if (_disposed) return null;
    final chapter = state.currentChapter;
    final anchor = _sourceAnchor;
    if (chapter == null ||
        anchor == null ||
        _anchorBookUrl != state.currentBook?.bookUrl ||
        anchor.chapterIndex != state.currentChapterIndex ||
        anchor.chapterId != chapterIdFor(chapter, state.currentChapterIndex)) {
      return null;
    }
    return anchor.sourceOffset;
  }

  bool tryBeginChangeSourceFlow() {
    if (_disposed) return false;
    if (_changeSourceFlowActive) return false;
    _changeSourceFlowActive = true;
    return true;
  }

  void endChangeSourceFlow() {
    if (_disposed) return;
    _changeSourceFlowActive = false;
  }

  Future<void> openBook(Book book) async {
    if (_disposed) return;
    final openSeq = ++_openSeq;
    _loadSeq++;
    _sourceAnchor = null;
    _anchorBookUrl = book.bookUrl;
    // [C1a-hunt | 2026-09-24] 换书判定：与当前书 bookUrl 不同才清旧书残留
    final isBookChange =
        state.currentBook == null || state.currentBook!.bookUrl != book.bookUrl;
    state = state.copyWith(
      currentBook: book,
      isLoading: true,
      error: null,
      showControls: false,
    );
    if (isBookChange) {
      // [C1a-hunt | 2026-09-24] 换书即清旧书残留（对齐原版
      // resetData → clearTextChapter）：换书失败时错误页门槛（error 非空
      // && 正文为空）可生效，目录/正文不再残留上一本书
      state = state.copyWith(
        chapters: const <BookChapter>[],
        chapterContent: '',
        currentChapterIndex: 0,
        currentChapterPos: 0,
      );
      _host.resetPagination();
    }
    await _beginReadRecordSession(book);
    if (openSeq != _openSeq || _disposed) return;

    try {
      var chapters = await _reading.getChapters(book.bookUrl);
      if (openSeq != _openSeq) return; // [C1b-hunt] 已被更新的 openBook 取代，丢弃旧结果
      // 对齐原版：本地无目录的网络书籍（如刚从搜索结果加入书架，
      // 尚未拉取过目录），自动经书源规则从网络获取目录
      if (chapters.isEmpty && book.origin.isNotEmpty) {
        chapters = await _reading.refreshToc(book.bookUrl, book.origin);
        if (openSeq != _openSeq) return; // [C1b-hunt]
      }
      var chapterIndex = book.durChapterIndex;
      if (chapterIndex >= chapters.length && chapters.isNotEmpty) {
        chapterIndex = 0;
      }
      final anchor = await _positionStore.read(
        book.bookUrl,
        chapterIndex: chapterIndex,
      );
      if (openSeq != _openSeq || _disposed) return;
      _sourceAnchor = anchor;
      state = state.copyWith(
        chapters: chapters,
        currentChapterIndex: chapterIndex,
        currentChapterPos: 0,
      );
      await _loadChapterContent();
    } catch (e) {
      // 被更新开书操作取代的错误不得覆盖当前会话。
      if (openSeq == _openSeq) state = state.copyWith(error: errorMessage(e));
    } finally {
      if (openSeq == _openSeq) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> nextChapter() async {
    if (_disposed) return;
    if (!state.hasNextChapter) return;
    await _saveProgress();
    if (_disposed) return;
    state = state.copyWith(
      currentChapterIndex: state.currentChapterIndex + 1,
      currentChapterPos: 0,
      isLoading: true,
    );
    _syncCurrentBookProgress();
    // [F1-hunt F2 | 2026-09-24] 被更新的加载取代时（快速连点翻页）
    // 加载返回 false：不清 isLoading、不保存进度（防旧章进度覆盖新章）
    final applied = await _loadChapterContent();
    if (!applied) return;
    state = state.copyWith(isLoading: false);
    await _saveProgress();
  }

  Future<void> prevChapter() async {
    if (_disposed) return;
    if (!state.hasPreviousChapter) return;
    await _saveProgress();
    if (_disposed) return;
    state = state.copyWith(
      currentChapterIndex: state.currentChapterIndex - 1,
      currentChapterPos: -1,
      isLoading: true,
    );
    _syncCurrentBookProgress();
    final applied = await _loadChapterContent();
    if (!applied) return;
    state = state.copyWith(isLoading: false);
    await _saveProgress();
  }

  void resetChapterPos() {
    if (_disposed) return;
    state = state.copyWith(currentChapterPos: 0);
    _syncCurrentBookProgress();
  }

  Future<void> goToChapter(int index, {int? sourceOffset}) async {
    if (_disposed) return;
    if (index < 0 || index >= state.chapters.length) return;
    await _saveProgress();
    if (_disposed) return;
    _anchorBookUrl = state.currentBook?.bookUrl;
    _sourceAnchor = sourceOffset == null
        ? null
        : ReaderSourceAnchor(
            chapterId: chapterIdFor(state.chapters[index], index),
            chapterIndex: index,
            sourceOffset: sourceOffset,
          );
    state = state.copyWith(
      currentChapterIndex: index,
      currentChapterPos: 0,
      isLoading: true,
      showControls: false,
    );
    _syncCurrentBookProgress();
    final applied = await _loadChapterContent();
    if (!applied) return;
    state = state.copyWith(isLoading: false);
    await _saveProgress();
  }

  Future<void> applyBookProgress({required int chapterIndex}) async {
    if (_disposed) return;
    if (chapterIndex < 0 || chapterIndex >= state.chapters.length) return;
    await _saveProgress();
    if (_disposed) return;
    _sourceAnchor = null;
    state = state.copyWith(
      currentChapterIndex: chapterIndex,
      currentChapterPos: 0,
      isLoading: true,
      showControls: false,
    );
    _syncCurrentBookProgress();
    final applied = await _loadChapterContent();
    if (!applied) return;
    state = state.copyWith(isLoading: false);
    await _saveProgress();
  }

  void updatePosition(int position, {int? sourceOffset}) {
    if (_disposed) return;
    final chapter = state.currentChapter;
    if (sourceOffset != null && chapter != null) {
      _anchorBookUrl = state.currentBook?.bookUrl;
      _sourceAnchor = ReaderSourceAnchor(
        chapterId: chapterIdFor(chapter, state.currentChapterIndex),
        chapterIndex: state.currentChapterIndex,
        sourceOffset: sourceOffset.clamp(0, state.chapterContent.length),
      );
    } else {
      _sourceAnchor = null;
    }
    state = state.copyWith(currentChapterPos: position);
    // [F1-hunt F1 | 2026-09-24] 章内位置变化同样回写 currentBook，
    // 下游消费者（设置保存全行 updateBook 等）读到的进度保持鲜活
    _syncCurrentBookProgress();
  }

  Future<void> reloadChapterContent() async {
    if (_disposed) return;
    await _loadChapterContent();
  }

  void updateCurrentBook(Book book) {
    if (_disposed) return;
    state = state.copyWith(currentBook: book);
  }

  Future<String?> refreshChapterContent() async {
    if (_disposed) return '阅读会话已结束';
    final book = state.currentBook;
    if (book == null || state.chapters.isEmpty) return '没有书籍或目录';
    if (book.origin.isEmpty ||
        book.origin == BookType.localTag ||
        book.origin.startsWith(BookType.webDavTag)) {
      return '本地书不支持刷新正文';
    }
    final idx = state.currentChapterIndex;
    if (idx < 0 || idx >= state.chapters.length) return '无效章节索引';
    if (_refreshing) return '正文刷新进行中'; // [C5-hunt] 重入守卫
    _refreshing = true;
    final seq = ++_loadSeq;
    final chapter = state.chapters[idx];
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 服务保持先失效当前章、再抓取；加载状态和失败时的旧正文由此会话持有。
      final content = await _content.refresh(
        bookUrl: book.bookUrl,
        chapterIndex: idx,
        chapterUrl: chapter.url,
        sourceUrl: book.origin,
      );
      if (seq != _loadSeq) return null;
      if (content.trim().isEmpty) {
        // 空正文视为抓取失败：保留旧正文（当前章缓存行已失效，
        // 他章不受影响，无整书清理）
        state = state.copyWith(isLoading: false, error: '正文抓取为空');
        return '正文抓取为空';
      }
      // 3) 成功：持久化新内容（fetch 已自动回写当前章缓存行）
      state = state.copyWith(chapterContent: content, isLoading: false);
      return null;
    } catch (e) {
      if (seq != _loadSeq) return null;
      // [STAGE3-C2B] 失败保留旧正文并显示原因；仅当前章缓存行丢失
      // （对齐上游，不做整书清理）
      final msg = errorMessage(e);
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    } finally {
      _refreshing = false; // [C5-hunt]
    }
  }

  Future<String?> reloadAfterSourceChange(String bookUrl) async {
    if (_disposed) return '阅读会话已结束';
    final book = state.currentBook;
    if (book == null) return '没有书籍';
    // [SB-HUNT | 2026-09-25] 重入兜底：重载阶段在途（或导航阶段
    // 进行中）时直接返回，不重复 getBook/重载目录/清缓存
    if (_changeSourceFlowActive) return '更换书源进行中';
    _changeSourceFlowActive = true;
    final openSeq = _openSeq;
    final oldIndex = state.currentChapterIndex;
    final oldChapter =
        (state.chapters.isNotEmpty &&
            oldIndex >= 0 &&
            oldIndex < state.chapters.length)
        ? state.chapters[oldIndex]
        : null;
    final oldTitle = (oldChapter?.title ?? book.durChapterTitle ?? '').trim();
    final oldPos = state.currentChapterPos;

    state = state.copyWith(isLoading: true, error: null);
    try {
      // 1) 重读书籍记录（换源事务后的新记录）
      final newBook = await _bookshelf.getBook(bookUrl);
      if (openSeq != _openSeq || _disposed) return null;
      if (newBook == null) {
        throw StateError('读取书籍记录失败');
      }
      // 2) 同步书籍对象（bookUrl 稳定，源相关字段为新值）
      state = state.copyWith(currentBook: newBook);
      // 3) 重载目录（对齐 openBook：本地库优先，空则联网）
      var chapters = await _reading.getChapters(bookUrl);
      if (openSeq != _openSeq || _disposed) return null;
      if (chapters.isEmpty && newBook.origin.isNotEmpty) {
        chapters = await _reading.refreshToc(bookUrl, newBook.origin);
      }
      if (openSeq != _openSeq || _disposed) return null;
      if (chapters.isEmpty) {
        throw StateError('目录加载失败（新源无目录）');
      }
      // 4) 章节定位 + 位置保留
      final target = _matchChapterAfterTocReload(chapters, oldTitle, oldIndex);
      final sameChapter =
          oldChapter != null &&
          chapters[target].title.trim() == oldChapter.title.trim();
      state = state.copyWith(
        chapters: chapters,
        currentChapterIndex: target,
        currentChapterPos: sameChapter ? oldPos : 0,
      );
      // [F1-hunt F1 | 2026-09-24] 换源重载完成章节定位后回写进度，
      // 保证后续 _saveProgress 持久化的是新目录下的命中章/保留位
      _syncCurrentBookProgress();
      // 5) 强制刷新命中章正文（同 Fix A 路径；[STAGE3-C2B] 先失效当前
      //    章缓存行再抓取，bookUrl 不变时仍保证取到新源正文）
      final err = await refreshChapterContent();
      if (openSeq != _openSeq || _disposed) return null;
      if (err != null) {
        // 正文抓取失败：目录已是新源，保留旧正文，错误显式返回
        state = state.copyWith(isLoading: false, error: err);
        return '正文刷新失败：$err';
      }
      // 持久化换源后的新进度（新章节索引/位置）
      await _saveProgress();
      if (openSeq != _openSeq || _disposed) return null;
      state = state.copyWith(isLoading: false);
      return null;
    } catch (e) {
      if (openSeq != _openSeq || _disposed) return null;
      final msg = errorMessage(e);
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    } finally {
      // [SB-HUNT | 2026-09-25] 重载阶段锁必复位（含异常/取消路径）
      _changeSourceFlowActive = false;
    }
  }

  int _matchChapterAfterTocReload(
    List<BookChapter> toc,
    String oldTitle,
    int oldIndex,
  ) {
    if (toc.isEmpty) return 0;
    final title = oldTitle.trim();
    if (title.isNotEmpty) {
      final exact = toc.indexWhere((c) => c.title.trim() == title);
      if (exact >= 0) return exact;
      final soft = toc.indexWhere(
        (c) =>
            c.title.isNotEmpty &&
            (c.title.contains(title) || title.contains(c.title)),
      );
      if (soft >= 0) return soft;
    }
    if (oldIndex >= 0 && oldIndex < toc.length) return oldIndex;
    return 0;
  }

  Future<void> _saveProgress() async {
    if (_disposed) return;
    final session = _readRecordSession;
    final book = state.currentBook;
    if (book == null) return;
    try {
      // [F1-hunt F6 | 2026-09-24] 哨兵归一：prevChapter 的 -1（跳末页
      // 哨兵）只存在于 state.currentChapterPos 供视图消费，落库前归 0，
      // -1 不得持久化（修复前 -1 随 updateReadingProgress 写入
      // durChapterPos，下次 openBook 按非法位置定位）
      final pos = state.currentChapterPos < 0 ? 0 : state.currentChapterPos;
      final anchor = currentSourceOffset == null ? null : _sourceAnchor;
      await _reading.updateReadingProgress(
        bookUrl: book.bookUrl,
        chapterIndex: state.currentChapterIndex,
        chapterPos: pos,
      );
      if (anchor != null &&
          _anchorBookUrl == book.bookUrl &&
          anchor.chapterIndex == book.durChapterIndex) {
        await _positionStore.save(book.bookUrl, anchor);
      } else if (anchor == null) {
        // 显式回到章首或应用云端章节后，旧锚点不能在重开书时复活。
        await _positionStore.clear(book.bookUrl);
      }
      if (!_disposed && session == _readRecordSession) {
        await _upReadTime(book);
      }
    } catch (_) {
      // 保存失败不阻断阅读流程
    }
  }

  void _syncCurrentBookProgress() {
    if (_disposed) return;
    final book = state.currentBook;
    if (book == null) return;
    final pos = state.currentChapterPos < 0 ? 0 : state.currentChapterPos;
    final title = state.currentChapter?.title ?? book.durChapterTitle;
    if (book.durChapterIndex == state.currentChapterIndex &&
        book.durChapterPos == pos &&
        book.durChapterTitle == title) {
      return; // 无变化不重建（免无谓 notify / 重分页）
    }
    state = state.copyWith(
      currentBook: book.copyWith(
        durChapterIndex: state.currentChapterIndex,
        durChapterPos: pos,
        durChapterTitle: title,
      ),
    );
  }

  Future<void> _beginReadRecordSession(Book book) async {
    if (_disposed) return;
    final session = ++_readRecordSession;
    _pendingReadStartMs = null;
    _readStartMs = _clock();
    _baseReadTimeMs = 0;
    try {
      final enable = (await _recordSettings.load()).enableRecord;
      if (_disposed || !enable) return;
      final records = await _records.getReadRecords();
      if (session != _readRecordSession) return;
      for (final r in records) {
        if (r.bookName == book.name) {
          _baseReadTimeMs += r.readTime;
        }
      }
    } catch (_) {
      // 忽略：阅读记录失败不阻断打开书籍
    }
  }

  Future<void> _upReadTime(Book book) async {
    if (_disposed) return;
    final session = _readRecordSession;
    try {
      final enable = (await _recordSettings.load()).enableRecord;
      if (_disposed || !enable || session != _readRecordSession) return;
      final now = _clock();
      if (_readStartMs <= 0) {
        _readStartMs = now;
        return;
      }
      final delta = now - _readStartMs;
      if (delta <= 0) return;
      final start = _pendingReadStartMs ?? _readStartMs;
      _pendingReadStartMs ??= _readStartMs;
      _baseReadTimeMs += delta;
      _readStartMs = now;
      final targetReadTime = _baseReadTimeMs;
      await _records.putReadRecord(
        ReadRecord(
          bookName: book.name,
          author: book.author,
          startTime: start,
          readTime: targetReadTime,
          lastRead: now,
        ),
        bookUrl: book.bookUrl,
        chapterIndex: book.durChapterIndex,
      );
      if (session == _readRecordSession && _baseReadTimeMs == targetReadTime) {
        _pendingReadStartMs = null;
      }
    } catch (_) {
      // 写记录失败不阻断阅读
    }
  }

  Future<bool> _loadChapterContent() async {
    if (_disposed) return false;
    final book = state.currentBook;
    if (book == null || state.chapters.isEmpty) return true;
    final seq = ++_loadSeq;
    // await 前捕获目标章：连点翻页后旧加载仍按自己捕获的索引取内容，
    // 完成后因代际过期被丢弃，不会误取/误写新章
    final index = state.currentChapterIndex;
    try {
      final content = await _content.read(book.bookUrl, index);
      if (seq != _loadSeq) return false; // 已被更新的加载取代，丢弃旧结果
      state = state.copyWith(chapterContent: content, error: null);
      return true;
    } catch (e) {
      if (seq != _loadSeq) return false; // 被取代加载的错误同样不得覆盖新状态
      state = state.copyWith(error: errorMessage(e), chapterContent: '');
      return true;
    }
  }

  /// 接收表现层解析的目标位置，不拥有跨章节分页器。
  Future<void> goToPage({
    required int chapterIndex,
    required int pageIndex,
    required int globalIndex,
  }) async {
    if (_disposed) return;
    if (chapterIndex != state.currentChapterIndex) {
      await _saveProgress();
      if (_disposed) return;
      _sourceAnchor = null;
      state = state.copyWith(
        currentChapterIndex: chapterIndex,
        currentChapterPos: pageIndex,
        globalPageIndex: globalIndex,
        isLoading: true,
      );
      _syncCurrentBookProgress();
      if (!await _loadChapterContent()) return;
      state = state.copyWith(isLoading: false);
      await _saveProgress();
    } else {
      _sourceAnchor = null;
      state = state.copyWith(
        currentChapterPos: pageIndex,
        globalPageIndex: globalIndex,
      );
      _syncCurrentBookProgress();
    }
  }

  Future<void> saveProgress() => _saveProgress();
}
