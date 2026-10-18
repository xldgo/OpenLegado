import '../../../utils/error_message.dart';
import 'components/toc_overflow_menu.dart';
import '../application/toc_filter_controller.dart';
import '../application/toc_cache_controller.dart';
import 'components/toc_item_tile.dart';
import 'components/toc_volume_tile.dart';

import 'package:flutter_legado/src/domain/services/book_metadata_policy.dart';

import '../../bookshelf/bookshelf_repositories.dart';
import '../../../providers/reading_provider.dart';
import '../../book_sources/book_source_repository_provider.dart';
import '../../../providers/explore/explore_dependencies.dart';
import '../../../providers/media_provider.dart';
import '../../../domain/models/book_highlight.dart';
import '../../../providers/highlight_repository_provider.dart';
import '../../../providers/chapter_cache_provider.dart';
import '../../../l10n/app_localization.dart';
import '../../../widgets/app_menu.dart';
import '../../bookmarks/bookmarks.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/md3_fast_scroller.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/legado_app_bar.dart';
import '../../../widgets/app_search_field.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../models/models.dart';
import '../../../providers/general_settings_provider.dart';
import '../../reader/application/reader_settings_provider.dart';
import '../../../app/routing/route_names.dart';
import '../../../services/audio_cache_events.dart';
import '../../../services/bookmark_export.dart';
import '../../../utils/app_route_observer.dart';

/// 目录页组合章节、书签和标注；数据及下载保持现有仓储来源。— Codex + UI
class TocScreen extends ConsumerStatefulWidget {
  /// 书籍对象（路由参数规范化：优先使用 Book 对象）
  final Book book;

  const TocScreen({super.key, required this.book});

  @override
  ConsumerState<TocScreen> createState() => _TocScreenState();
}

class _TocScreenState extends ConsumerState<TocScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  /// 目录章节行估算高度（ListView.builder itemExtent，供初次进入按 index 定位）
  static const double _chapterRowExtent = 48;

  late final TabController _tabController;
  final ScrollController _tocScrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  final TocFilterController _filter = TocFilterController();
  late final TocCacheController _cache;
  bool _searching = false;
  String get _searchKey => _filter.query;

  /// 加载字数开关使用共享阅读设置，不维护独立持久化副本。— Codex + UI
  bool get _loadWordCount =>
      ref.read(readerSettingsRepositoryProvider).current.tocLoadWordCount;

  /// 目录 FAB 展开菜单显隐（定位/顶部/底部/一键缓存，对齐参考版）— 2026-09-08
  bool _jumpMenuOpen = false;

  /// 当前书籍（菜单勾选项更新后刷新，如 useReplaceRule/splitLongChapter）
  late Book _book;

  /// 是否在架（对标原版 inBookshelf；未在架时不 refreshToc 落库）
  bool _inBookshelf = false;

  /// 章节列表（含卷行）
  List<BookChapter> _chapters = [];
  bool _chaptersLoading = true;
  String? _chaptersError;

  Set<String> get _cachedUrls => _cache.state.urls;
  Set<int> get _audioCachedIndices => _cache.state.audio;
  Map<String, String> get _polledWordCounts => _cache.state.wordCounts;
  Set<int> get _downloadingIndices => _cache.state.downloading;
  Set<int> get _failedIndices => _cache.state.failed;

  /// 标注列表（BookHighlight实体，经 HighlightRepository.highlightListByBook）
  List<BookHighlight> _highlights = [];
  bool _highlightsLoading = true;
  String? _highlightsError;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _filter.addListener(_onPresentationChanged);
    _cache = TocCacheController(
      readBook: () => _book,
      chapters: ref.read(chapterCacheRepositoryProvider),
      downloads: ref.read(cacheDownloadServiceProvider),
      audio: ref.read(audioCacheRepositoryProvider),
      events: AudioCacheEvents.instance.stream,
    )..addListener(_onPresentationChanged);
    _tabController = TabController(length: 3, vsync: this)
      // Tab 切换需刷新溢出菜单条件显隐与底部信息条（对齐原版 onMenuOpened）
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _initBookshelfState();
    _loadSettings();
    _loadHighlights();
    _cache.start();
    // 书签按书名+作者加载（对齐原版 bookmarkDao.getByBook，规避同名书混入，
    // 契约 §2.7 getBookmarksByBook，台账 §5.14-2，Task #65）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(bookmarkNotifierProvider.notifier)
          .loadByBook(_book.name, _book.author);
    });
  }

  /// 初始化在架状态（DB 有记录且非 notShelf / refresh_toc 占位）
  Future<void> _initBookshelfState() async {
    try {
      final dbBook = await ref
          .read(bookshelfRepositoryProvider)
          .getBook(_book.bookUrl);
      if (!mounted) return;
      setState(() {
        _inBookshelf = BookMetadataPolicy.resolveInBookshelf(
          dbBook,
          widget.book,
        );
      });
    } catch (_) {
      // 查询失败视为未在架，避免误 refreshToc 落库
    }
    await _loadChapters();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // [UI-fix v2.0.7 | 2026-08-09] Task #26：订阅全局路由观察器，
    // 从阅读器返回本页（didPopNext）时刷新缓存云图标/当前章节
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  void _onPresentationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _cache.dispose();
    _filter.dispose();
    _tabController.dispose();
    _tocScrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// [UI-fix v2.0.7 | 2026-08-09] Task #26：页面重现（从阅读器返回）时刷新。
  /// 对齐原版 ChapterListFragment 经 EventBus.SAVE_CONTENT 增量刷新语义：
  /// 同步书籍进度（durChapterIndex/Title）使当前章高亮与标题不陈旧。
  /// [P2-28] 同时刷新已缓存章节 URL 集，使目录云图标状态在从阅读器/
  /// 缓存页返回后保持最新。
  @override
  void didPopNext() {
    _cache.start();
    _refreshOnReshow();
  }

  @override
  void didPushNext() => _cache.stop();

  Future<void> _refreshOnReshow() async {
    try {
      final fresh = await ref
          .read(bookshelfRepositoryProvider)
          .getBook(_book.bookUrl);
      if (!mounted) return;
      if (fresh != null) setState(() => _book = fresh);
      await _cache.refreshUrls();
    } catch (_) {
      // 刷新失败不阻断展示，保持旧状态
    }
  }

  /// 加载目录偏好，后续变更由共享订阅刷新。
  Future<void> _loadSettings() async {
    try {
      await ref.read(readerSettingsRepositoryProvider).load();
    } catch (error) {
      debugPrint('目录设置读取失败：$error');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('目录设置读取失败，请重试')));
      }
    }
  }

  /// 加载章节列表（经 ReadingRepository），完成后自动滚动定位当前章节
  Future<void> _loadChapters() async {
    setState(() {
      _chaptersLoading = true;
      _chaptersError = null;
    });
    try {
      var chapters = await ref
          .read(readingRepositoryProvider)
          .getChapters(_book.bookUrl);
      // [Task #21 | 2026-08-08] 自愈：本地库无目录的在线书籍（含换源后旧章节
      // 已清、或历史遗留未拉取过目录的书），自动经书源规则从网络刷新目录。
      // 与 reader_notifier.openBook 的回退保持一致，使打开目录页时也能触发
      // 目录获取，修复用户反馈的「目录也获取不到」。refresh_toc 内部以书籍
      // tocUrl 为抓取地址（换源后指向当前书源），tocUrl 空时回退 bookUrl。
      if (chapters.isEmpty && _book.origin.isNotEmpty) {
        if (_inBookshelf) {
          chapters = await ref
              .read(readingRepositoryProvider)
              .refreshToc(_book.bookUrl, _book.origin);
        } else {
          // 未入库：仅网络取目录展示，不落库（对齐 BookInfoScreen / 原版 !inBookshelf）
          chapters = await _fetchWebChaptersOnline();
        }
      }
      if (!mounted) return;
      await _cache.loadInitial();
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _chaptersLoading = false;
      });
      // 初次进入自动滚动定位当前章节（按 index 估算偏移）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToChapter(_book.durChapterIndex);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chaptersError = errorMessage(e);
        _chaptersLoading = false;
      });
    }
  }

  /// 加载标注列表（经 HighlightRepository.highlightListByBook，返回BookHighlight实体列表）
  Future<void> _loadHighlights() async {
    setState(() {
      _highlightsLoading = true;
      _highlightsError = null;
    });
    try {
      final highlights = await ref
          .read(highlightRepositoryProvider)
          .highlightListByBook(bookUrl: _book.bookUrl);
      if (!mounted) return;
      setState(() {
        _highlights = highlights;
        _highlightsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _highlightsError = errorMessage(e);
        _highlightsLoading = false;
      });
    }
  }

  /// 未入库在线书：webbookChapters 仅展示，不写 DB
  Future<List<BookChapter>> _fetchWebChaptersOnline() async {
    BookSource? source;
    try {
      final sources = await ref
          .read(bookSourceRepositoryProvider)
          .getBookSources();
      final o = _book.origin.trim().replaceAll(RegExp(r'/+$'), '');
      for (final s in sources) {
        final u = s.bookSourceUrl.trim().replaceAll(RegExp(r'/+$'), '');
        if (u == o || s.bookSourceUrl == _book.origin) {
          source = s;
          break;
        }
      }
    } catch (_) {
      return const [];
    }
    if (source == null) return const [];
    try {
      // [P2-8] 取址同详情页刷新：当前书源详情页（originBookUrl 优先、
      // 空回退 bookUrl）；章节归属仍传稳定主键 bookUrl
      return await ref
          .read(bookSourceQueryServiceProvider)
          .getChapters(
            source,
            BookMetadataPolicy.bookFetchUrl(_book),
            bookUrl: _book.bookUrl,
            tocUrl: _book.tocUrl,
            bookName: _book.name,
          );
    } catch (e) {
      debugPrint('webbookChapters 错误: ${errorMessage(e)}');
      return const [];
    }
  }

  // ===== 书籍类型判定（对齐原版 isLocal/isLocalTxt） =====

  /// 本地书（含 WebDAV 导入，对齐原版 Book.isLocal）
  bool get _isLocal =>
      _book.origin == BookType.localTag ||
      _book.origin.startsWith(BookType.webDavTag);

  /// 本地 TXT 书（对齐原版 Book.isLocalTxt，控制 TXT 目录规则/拆分长章节显隐）
  bool get _isLocalTxt =>
      _isLocal &&
      (_book.originName.toLowerCase().endsWith('.txt') ||
          _book.bookUrl.toLowerCase().endsWith('.txt'));

  /// 音频书（位标记判定，对齐原版 Book.isAudio = isType(BookType.audio)；
  /// bookType 为位标记，须用 `&` 而非 `==`，同 book_open_utils 分流先例）
  bool get _isAudioBook => (_book.bookType & BookType.audio) != 0;

  // ===== 目录展示列表（搜索过滤 + 倒序，保留原始章节 index 供跳转） =====

  /// 展示条目：(原始列表位置, 章节)
  List<MapEntry<int, BookChapter>> get _displayEntries =>
      _filter.entries(_chapters);

  /// 滚动定位到指定章节 index（按展示列表位置 * 行高估算偏移）
  void _scrollToChapter(int chapterIndex) {
    if (!_tocScrollController.hasClients) return;
    final entries = _displayEntries;
    final displayIndex = entries.indexWhere(
      (e) => e.value.index == chapterIndex,
    );
    if (displayIndex < 0) return;
    final offset = (displayIndex * _chapterRowExtent).clamp(
      0.0,
      _tocScrollController.position.maxScrollExtent,
    );
    _tocScrollController.jumpTo(offset);
  }

  // ===== 搜索（300ms 防抖） =====

  void _onSearchChanged(String text) => _filter.search(text);

  void _toggleSearch() {
    if (_searching) FocusScope.of(context).unfocus();
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchCtrl.clear();
        _filter.clear();
      }
    });
  }

  // ===== 溢出菜单（对齐 book_toc.xml 顺序 + TocActivity.onMenuOpened 条件显隐） =====

  Future<void> _handleMenu(String value) async {
    switch (value) {
      case 'tocRegex':
        // 跳转已有 TXT 目录规则页（对齐原版 menu_toc_regex → TxtTocRuleDialog）
        Navigator.pushNamed(context, AppRoutes.txtTocRules);
        break;
      case 'splitLongChapter':
        // 拆分长章节存于 ReadConfig（参照 book_info_screen 已有实现）
        final cfg = _book.readConfig ?? const ReadConfig();
        final updated = _book.copyWith(
          readConfig: cfg.copyWith(splitLongChapter: !cfg.splitLongChapter),
        );
        await _updateBook(updated);
        // 对齐原版 upBookAndToc：切换后需重载目录
        await _loadChapters();
        break;
      case 'reverseToc':
        // 纯 Dart 本地反转显示序（对齐原版 menu_reverse_toc 展示语义）
        _filter.toggleOrder();
        break;
      case 'useReplace':
        // 接 ReadConfig.useReplaceRule 字段经 BookshelfRepository 更新（对齐原版 menu_use_replace）
        final rc = _book.readConfig ?? const ReadConfig();
        await _updateBook(
          _book.copyWith(
            readConfig: rc.copyWith(
              useReplaceRule: !(rc.useReplaceRule ?? true),
            ),
          ),
        );
        break;
      case 'loadWordCount':
        try {
          await ref
              .read(readerSettingsRepositoryProvider)
              .update(tocLoadWordCount: !_loadWordCount);
        } catch (error) {
          debugPrint('目录字数设置保存失败：$error');
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('目录字数设置保存失败，请重试')));
          }
        }
        break;
      case 'exportBookmark':
        // [Task #40 | 2026-08-09] §5.11-5 接线：导出书签 JSON
        //（对齐原版 menu_export_bookmark → TocViewModel.saveBookmark） — Qoder
        await _exportBookmarks(asMarkdown: false);
        break;
      case 'exportMd':
        // [Task #40 | 2026-08-09] §5.11-5 接线：导出 Markdown
        //（对齐原版 menu_export_bookmark_md → saveBookmarkMd） — Qoder
        await _exportBookmarks(asMarkdown: true);
        break;
      case 'log':
        Navigator.pushNamed(context, AppRoutes.appLog);
        break;
    }
  }

  /// 导出书签（JSON / Markdown 双格式，对齐原版 TocViewModel.saveBookmark/
  /// saveBookmarkMd 交互流程：菜单触发 → 选目录 → 写文件 → Toast 结果）
  /// [Task #40 | 2026-08-09] §5.11-5 — Qoder
  Future<void> _exportBookmarks({required bool asMarkdown}) async {
    try {
      // 书签数据经 BookmarkRepository.getBookmarksByBook 获取（契约 §2.7，台账
      // §5.14-2 Task #65：按书名+作者查询，规避同名书混入）
      final bookmarks = await ref
          .read(bookmarkRepositoryProvider)
          .getBookmarksByBook(_book.name, _book.author);
      if (!mounted) return;
      if (bookmarks.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('暂无书签可导出')));
        return;
      }
      // 「默认书籍保存位置」已设置时作为目录选择器初始路径
      final initialDir =
          (await ref.read(generalSettingsRepositoryProvider).load())
              .defaultBookTreeUri;
      if (!mounted) return;
      final savedPath = asMarkdown
          ? await BookmarkExport.exportMarkdown(
              book: _book,
              bookmarks: bookmarks,
              initialDirectory: initialDir,
            )
          : await BookmarkExport.exportJson(
              book: _book,
              bookmarks: bookmarks,
              initialDirectory: initialDir,
            );
      if (!mounted) return;
      // 用户取消目录选择时静默返回（对齐原版 SAF 取消语义）
      if (savedPath == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出成功: $savedPath')));
    } catch (e) {
      // 写入失败给出可读错误（对齐原版 AppLog.put「导出失败」提示语义）
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败: ${errorMessage(e)}')));
    }
  }

  /// 经 BookshelfRepository 更新书籍并同步本页状态
  Future<void> _updateBook(Book updated) async {
    try {
      await ref.read(bookshelfRepositoryProvider).updateBook(updated);
      if (mounted) setState(() => _book = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('更新失败: ${errorMessage(e)}')));
      }
    }
  }

  // ===== 构建 =====

  @override
  Widget build(BuildContext context) {
    ref.watch(
      readerSettingsProvider.select((value) => value.value?.tocLoadWordCount),
    );
    final cs = Theme.of(context).colorScheme;
    // [PARITY C2 T3] 头部对齐参考版：章名大标题与「N / M」页码同行（参考为
    // 「章节名 + 页码」整体大标题，与右侧 🔍/⋮ 分离；此前为两行 Column 堆叠）。
    final currentChapterTitle = _book.durChapterTitle?.isNotEmpty == true
        ? _book.durChapterTitle!
        : '';
    final chapterProgressText =
        '${_book.durChapterIndex + 1} / ${_chapters.isNotEmpty ? _chapters.length : (_book.totalChapterNum > 0 ? _book.totalChapterNum : 0)}';
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => IgnorePointer(
            ignoring: child.key == const ValueKey('toc-search') && !_searching,
            child: ExcludeFocus(
              excluding:
                  child.key == const ValueKey('toc-search') && !_searching,
              child: FadeTransition(opacity: animation, child: child),
            ),
          ),
          child: _searching
              ? AppSearchField(
                  key: const ValueKey('toc-search'),
                  controller: _searchCtrl,
                  autoFocus: true,
                  hintText: context.l10n.debugKeywordLabel,
                  onChanged: _onSearchChanged,
                  onClear: () {
                    _filter.clear();
                  },
                )
              : currentChapterTitle.isNotEmpty
              // [PARITY C2 T3] 章名（主标题）+ 页码（小字）同行，整体作为
              // AppBar 标题区，与右侧 🔍/⋮ 动作分离（对齐参考大标题形态）。
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        currentChapterTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      chapterProgressText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : Text(_book.name.isNotEmpty ? _book.name : context.l10n.catalog),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _searching ? Symbols.close_rounded : Symbols.search_rounded,
            ),
            tooltip: _searching ? '关闭搜索' : context.l10n.search,
            onPressed: _toggleSearch,
          ),
          TocOverflowMenu(
            tab: _tabController.index,
            isLocalTxt: _isLocalTxt,
            readConfig: _book.readConfig,
            loadWordCount: _loadWordCount,
            onSelected: _handleMenu,
          ),
        ],
        // AppBar 内 TabBar 显式指定前景色，避免白底白字（项目规范）
        // [LAYOUT_PLAN P1] Tab 标准化：无分割线 + labelLargeEmphasized
        bottom: TabBar(
          controller: _tabController,
          // 固定宽度标签等宽铺满，各页面不依赖全局对齐策略。
          tabAlignment: TabAlignment.fill,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: cs.primary,
          dividerColor: Colors.transparent,
          labelStyle: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w500),
          unselectedLabelStyle: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: context.l10n.catalog),
            Tab(text: context.l10n.bookmarks),
            const Tab(text: '标注'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChapterTab(context),
          _buildBookmarkTab(context),
          _buildHighlightTab(context),
        ],
      ),
      // [PARITY C2 T4] 目录底栏「页码 + ↑↓」条已移除（参考无）：跳转顶部/底部与
      // 定位当前章能力保留于下方目录 FAB 展开菜单（_buildJumpFab）。
      // [UI_SYNC_REFACTOR S5 修 | 2026-09-08] 目录 FAB 展开菜单（对齐参考版）：
      // 定位至当前阅读 / 移至顶部 / 移至底部 / 一键缓存（自当前章入队）。
      // 仅目录 Tab 显示；AnimatedBuilder 保证切页签时显隐即时刷新 — Qoder
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) => _tabController.index == 0
            ? _buildJumpFab(context)
            : const SizedBox.shrink(),
      ),
    );
  }

  /// 目录 FAB：点击展开四项快捷操作（对齐参考版展开式菜单形态）
  Widget _buildJumpFab(BuildContext context) {
    final actions = [
      (
        Icons.my_location_rounded,
        context.l10n.readerLocateCurrentReading,
        _locateCurrentChapter,
      ),
      (
        Icons.vertical_align_top_rounded,
        context.l10n.readerMoveToTop,
        _scrollTocTop,
      ),
      (
        Icons.vertical_align_bottom_rounded,
        context.l10n.readerMoveToBottom,
        _scrollTocBottom,
      ),
      (
        Icons.cloud_download_rounded,
        context.l10n.readerDownloadAll,
        _cacheFromCurrent,
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_jumpMenuOpen)
          for (final (icon, label, onTap) in actions)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: FilledButton.tonalIcon(
                onPressed: () {
                  setState(() => _jumpMenuOpen = false);
                  onTap();
                },
                icon: Icon(icon, size: 20),
                label: Text(label),
              ),
            ),
        FloatingActionButton(
          onPressed: () => setState(() => _jumpMenuOpen = !_jumpMenuOpen),
          child: Icon(
            _jumpMenuOpen ? Icons.close_rounded : Icons.menu_open_rounded,
          ),
        ),
      ],
    );
  }

  /// 定位至当前阅读（复用进入目录时的定位逻辑）
  void _locateCurrentChapter() => _scrollToChapter(_book.durChapterIndex);

  void _scrollTocTop() {
    if (!_tocScrollController.hasClients) return;
    _tocScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollTocBottom() {
    if (!_tocScrollController.hasClients) return;
    _tocScrollController.animateTo(
      _tocScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// 一键缓存：自当前章到末章加入下载队列（对齐原版 download_after 语义）
  Future<void> _cacheFromCurrent() async {
    final total = _book.totalChapterNum;
    final start = _book.durChapterIndex;
    if (total <= 0 || start > total - 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无可缓存的章节')));
      return;
    }
    try {
      await ref
          .read(cacheDownloadServiceProvider)
          .cacheDownloadStart(_book.bookUrl, start, total - 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已从当前章加入缓存队列')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('缓存启动失败：$e')));
    }
  }

  /// [P2-29/P2-29c] 单章下载（NONE 态 ⬇ 点击）/ 单章重下（ERROR 态红色
  /// 重试图标点击）。对齐参考版 canDownload = NONE || ERROR 时点击状态图标
  /// （TocScreen.kt :879-881 + :958-965）→ TocIntent.DownloadChapter →
  /// TocViewModel.downloadChapter :863-869 按章索引单章下载；
  /// 复用 `CacheDownloadService.cacheDownloadStart`（契约 §2.43.3 闭区间语义 start==end
  /// 即单章；同书在途任务复用语义不变）启动下载；启动成功后 1s 轮询
  /// （P2-28b/c）自动把该行翻为下载中 16px 加载指示，完成后翻为对勾/
  /// 字数胶囊，失败翻为红色重试图标（失败集合经契约 §2.43.8
  /// listFailedChapters 轮询，取章重下即清、再失败重新记入）。
  /// [retry] 仅影响用户反馈文案：ERROR 重下 / NONE 首次下载。
  Future<void> _downloadChapter(int chapterIndex, {required bool retry}) async {
    try {
      await ref
          .read(cacheDownloadServiceProvider)
          .cacheDownloadStart(_book.bookUrl, chapterIndex, chapterIndex);
      if (!mounted) return;
      var title = '';
      for (final c in _chapters) {
        if (c.index == chapterIndex) {
          title = c.title;
          break;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            title.isNotEmpty
                ? '「$title」${retry ? '已加入重新下载队列' : '已加入缓存队列'}'
                : '第 ${chapterIndex + 1} 章${retry ? '已加入重新下载队列' : '已加入缓存队列'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${retry ? '重新下载' : '缓存'}启动失败：$e')),
      );
    }
  }

  // ===== 目录 Tab =====

  Widget _buildChapterTab(BuildContext context) {
    if (_chaptersLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_chaptersError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.error_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(_chaptersError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChapters,
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }
    if (_chapters.isEmpty) {
      return Center(child: Text(context.l10n.noChapters));
    }
    final entries = _displayEntries;
    if (entries.isEmpty) {
      return const Center(child: Text('未找到匹配的章节'));
    }
    // [UI_SYNC_REFACTOR R3] 千级章节列表快速滚动条（对齐原版 FastScroller）
    return Md3FastScroller(
      controller: _tocScrollController,
      child: ListView.builder(
        controller: _tocScrollController,
        itemExtent: _chapterRowExtent,
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final chapter = entries[i].value;
          return chapter.isVolume
              ? TocVolumeTile(chapter: chapter)
              : _buildChapterRow(context, chapter);
        },
      ),
    );
  }

  Widget _buildChapterRow(BuildContext context, BookChapter chapter) =>
      TocItemTile(
        chapter: chapter,
        isCurrent: chapter.index == _book.durChapterIndex,
        isLocal: _isLocal,
        isCached:
            !_isLocal &&
            (_isAudioBook
                ? _audioCachedIndices.contains(chapter.index)
                : _cachedUrls.contains(chapter.url)),
        isDownloading: _downloadingIndices.contains(chapter.index),
        isError: _failedIndices.contains(chapter.index),
        loadWordCount: _loadWordCount,
        wordCount: _polledWordCounts[chapter.url] ?? chapter.wordCount,
        onSelect: () => Navigator.of(context).pop(chapter.index),
        onDownload: () => _downloadChapter(chapter.index, retry: false),
        onRetry: () => _downloadChapter(chapter.index, retry: true),
      );

  // [PARITY C2 T4] 原「目录底栏：当前章节名 + 跳转顶部/底部」已移除（参考无底栏）；
  // 跳转顶部/底部与定位当前章能力保留于目录 FAB 展开菜单（_buildJumpFab）。

  // ===== 书签 Tab（对齐原版 BookmarkFragment，样式复用 bookmark_screen） =====

  Widget _buildBookmarkTab(BuildContext context) {
    final state = ref.watch(bookmarkNotifierProvider);
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.error_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(state.error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref
                  .read(bookmarkNotifierProvider.notifier)
                  .loadByBook(_book.name, _book.author),
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }
    final query = _searchKey.trim().toLowerCase();
    final bookmarks = query.isEmpty
        ? state.bookmarks
        : state.bookmarks
              .where(
                (b) =>
                    b.chapterName.toLowerCase().contains(query) ||
                    b.bookText.toLowerCase().contains(query) ||
                    b.content.toLowerCase().contains(query),
              )
              .toList();
    if (bookmarks.isEmpty) {
      // [UI_SYNC_REFACTOR S5 修 | 2026-09-07] 空态对齐参考版颜文字彩蛋
      // （(╮_╰) 暂无书签；颜文字空态为已授权口径）— Qoder
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '(╮_╰)',
              style: TextStyle(
                fontSize: 40,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Text(query.isEmpty ? context.l10n.readerNoBookmark : '未找到匹配的书签'),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        // 滑动删除（Dismissible）+ 长按删除双入口
        return Dismissible(
          key: ValueKey('bookmark_${bookmark.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Icon(
              Symbols.delete_rounded,
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
          confirmDismiss: (_) => _confirmDeleteBookmark(bookmark),
          onDismissed: (_) => ref
              .read(bookmarkNotifierProvider.notifier)
              .deleteBookmark(bookmark.id),
          child: _buildBookmarkTile(context, bookmark),
        );
      },
    );
  }

  /// 书签列表项（章节名/摘要/时间，复用 bookmark_screen 卡片样式）
  Widget _buildBookmarkTile(BuildContext context, Bookmark bookmark) {
    final theme = Theme.of(context);
    return AppMenuAnchor<String>(
      itemBuilder: (ctx) => [
        AppMenuItem(value: 'edit', child: Text(ctx.l10n.bookmarkEditNote)),
        AppMenuItem(
          value: 'delete',
          child: Text(ctx.l10n.readerDeleteBookmark),
        ),
      ],
      onSelected: (action) async {
        if (action == 'edit') await _editBookmarkNote(bookmark);
        if (action == 'delete') {
          final ok = await _confirmDeleteBookmark(bookmark);
          if (ok == true && mounted) {
            ref
                .read(bookmarkNotifierProvider.notifier)
                .deleteBookmark(bookmark.id);
          }
        }
      },
      builder: (ctx, controller, child) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          // 点击跳转对应章节（返回 index 走调用方阅读链路）
          onTap: () => Navigator.of(context).pop(bookmark.chapterIndex),
          onLongPress: controller.open,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Symbols.bookmark_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        bookmark.chapterName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // [Task #54 | 2026-08-10] 缺陷⑤修复：bookmark.time 已是
                    // epoch 毫秒，删除多余的 ×1000 换算 — Qoder
                    Text(
                      _formatTime(bookmark.time),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
                if (bookmark.bookText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    bookmark.bookText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (bookmark.content.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '备注: ${bookmark.content}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 编辑只改变备注，成功后更新当前列表。— Codex + UI
  Future<void> _editBookmarkNote(Bookmark bookmark) async {
    final notifier = ref.read(bookmarkNotifierProvider.notifier);
    final saved = await BookmarkNoteSheet.show(
      context: context,
      bookText: bookmark.bookText,
      chapterName: bookmark.chapterName,
      initialNote: bookmark.content,
      onSave: (note) => notifier.updateNote(bookmark, note),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.bookmarkNoteSaved)));
  }

  /// 删除书签确认框（复用 bookmark_screen 交互语义）
  Future<bool?> _confirmDeleteBookmark(Bookmark bookmark) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.readerDeleteBookmark),
        content: Text('确定删除「${bookmark.chapterName}」的书签吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.delete),
          ),
        ],
      ),
    );
  }

  // ===== 标注 Tab（对齐原版 HighlightFragment） =====

  Widget _buildHighlightTab(BuildContext context) {
    if (_highlightsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_highlightsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.error_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(_highlightsError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHighlights,
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }
    final query = _searchKey.trim().toLowerCase();
    final highlights = query.isEmpty
        ? _highlights
        : _highlights.where((h) {
            final chapterName = h.chapterName.toLowerCase();
            final bookText = h.bookText.toLowerCase();
            final note = h.note.toLowerCase();
            return chapterName.contains(query) ||
                bookText.contains(query) ||
                note.contains(query);
          }).toList();
    if (highlights.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.border_color_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(query.isEmpty ? '暂无标注' : '未找到匹配的标注'),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: highlights.length,
      itemBuilder: (context, index) =>
          _buildHighlightTile(context, highlights[index]),
    );
  }

  /// 标注列表项：章节名/标注内容/时间，点击跳转对应章节
  Widget _buildHighlightTile(BuildContext context, BookHighlight h) {
    final theme = Theme.of(context);
    final chapterName = h.chapterName;
    final bookText = h.bookText;
    final note = h.note;
    final time = h.time;
    final chapterIndex = h.chapterIndex;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(chapterIndex),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Symbols.border_color_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      chapterName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // BookHighlight.time 为 Unix 毫秒（对齐 Rust highlight.rs 契约）
                  Text(_formatTime(time), style: theme.textTheme.labelSmall),
                ],
              ),
              if (bookText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  bookText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '笔记: $note',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 毫秒时间戳 → "yyyy-MM-dd HH:mm"（与 bookmark_screen 显示格式一致）
  String _formatTime(int millis) {
    if (millis <= 0) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}
