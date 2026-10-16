export 'reader_state.dart';
import '../../features/bookshelf/bookshelf_repositories.dart';
import '../chapter_cache_provider.dart';

import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:material_ui/material_ui.dart'
    show Brightness, ThemeMode, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../bridge/ffi.dart';
import '../../domain/models/reader_theme_mode.dart';
import '../../domain/models/reader_style.dart';
import '../../models/models.dart';
import '../../features/read_records/read_record_repository_provider.dart';
import '../read_record_settings_provider.dart';
import '../../services/reader_position_store.dart';
import '../../widgets/paragraph_layout_engine.dart';
import '../providers.dart';
import '../reading_provider.dart';
import '../theme/theme_notifier.dart';
import '../ui_settings/ui_settings_notifier.dart';
import 'reader_state.dart';
import 'reader_settings_provider.dart';

/// 阅读器 Riverpod Notifier
///
/// 职责严格限定（对齐 UI_RESTRUCTURE_PLAN.md §3.2 铁律）：
/// - 调用 ReadingRepository 加载章节、保存进度 → 更新 immutable State
/// - 管理 UI 状态（loading/error/data 三态、工具栏显隐）
/// - 管理阅读设置（字号/行距/背景/翻页模式）并持久化
/// - 禁止包含业务计算（文本解析/净化/替换由 Rust 完成）
class ReaderNotifier extends Notifier<ReaderState> {
  final ReaderPositionStore _positionStore = ReaderPositionStore();
  ReaderSourceAnchor? _sourceAnchor;
  String? _anchorBookUrl;

  static String chapterIdFor(BookChapter chapter, int index) =>
      chapter.url.isNotEmpty ? chapter.url : '$index:${chapter.title}';

  /// 页码只供当前布局翻页；保存与重排使用原文锚点。
  int? get currentSourceOffset {
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

  /// 跨章节连续分页器（维护全局页索引 ↔ 章节/页映射）
  final CrossChapterPaginator _paginator = CrossChapterPaginator();

  /// 获取分页器（供 UI 层查询全局页信息）
  CrossChapterPaginator get paginator => _paginator;

  /// 计时会话与尚未持久化时段；旧保存完成不得改写新会话。
  int _readRecordSession = 0;
  int? _pendingReadStartMs;

  /// 本次打开阅读器时累计起点（对标 ReadBook.readStartTime，毫秒）
  int _readStartMs = 0;

  /// 进入阅读器前已累计的阅读时长（毫秒，对标 ReadBook.readRecord.readTime）
  int _baseReadTimeMs = 0;

  // [F1-hunt F2 | 2026-09-24] 章节正文加载代际号：_loadChapterContent
  // 每次调用自增并捕获；异步结果返回时代际号已变化（快速连点翻页已
  // 发起更新的加载）则丢弃旧结果——防旧章正文覆盖新章（F2 缺陷）。
  // 不设「在途即跳过」硬重入守卫：连点两次仍应逐次推进章节，
  // 只是被取代的加载结果不得写回状态。
  int _loadSeq = 0;

  // [C1b-hunt | 2026-09-24] openBook 代际号：每次 openBook 自增并捕获；
  // 任一异步结果返回时若已有更新的 openBook 发起（并发开书 A 慢 / B 快），
  // 丢弃旧结果（不写目录/正文/索引、不写 error、不清 isLoading）——防 A
  // 的迟到结果覆盖已打开的 B（C1b 缺陷）。与 _loadSeq 粒度不同、可共存：
  // _openSeq 守「整次 openBook」（书级，并发开书），_loadSeq 守「单次正文
  // 加载」（章级，连点翻页）；openBook 内部触发的 _loadChapterContent 仍
  // 各自受 _loadSeq 守卫，两守卫互不替代。
  int _openSeq = 0;

  // [C5-hunt | 2026-09-24] 刷新正文重入守卫：refreshChapterContent 在途
  // 期间再次调用（UI 双入口：菜单面板 _refreshContentFlow / 顶栏刷新钮）
  // 直接返回原因、不重复清缓存与联网抓取（对齐换源流程
  // ChangeSourceNotifier.isApplying / _applying 的防重入形态，C5 缺陷：
  // N 次点击 = N 次整书清缓存 + N 次强制抓取）
  bool _refreshing = false;

  /// 刷新正文是否进行中（UI 入口据此提前返回，避免堆叠 SnackBar）
  bool get isRefreshing => _refreshing;

  // [SB-HUNT | 2026-09-25] 换源流程重入锁（provider/notifier 级，顶栏与
  // 菜单面板两入口共用——真机缺陷：两入口各自开换源页并各挂一条 10min
  // 「正在更换书源…」条，第二条/残留条）。两阶段使用：
  //   ① 导航阶段：UI 辅助（runChangeSourceFlow）tryBegin 后推换源页，
  //      pop 返回后 endChangeSourceFlow 释放——同步交接给重载阶段，
  //      中间无用户输入窗口；
  //   ② 重载阶段：reloadAfterSourceChange 内部再置位并 try/finally
  //      复位，作为兜底（其他调用方直接调 reload 时同样被挡住）。
  // 在途期间第二次触发被 UI 层静默忽略（进行中条即轻提示）。
  bool _changeSourceFlowActive = false;

  /// 换源流程是否进行中（导航或重载任一阶段）
  bool get isChangeSourceFlowActive => _changeSourceFlowActive;

  /// 尝试进入换源流程：已在途返回 false（调用方据此提前返回）
  bool tryBeginChangeSourceFlow() {
    if (_changeSourceFlowActive) return false;
    _changeSourceFlowActive = true;
    return true;
  }

  /// 结束换源流程（导航阶段结束；重载阶段由 finally 独立复位）
  void endChangeSourceFlow() {
    _changeSourceFlowActive = false;
  }

  @override
  ReaderState build() {
    final repository = ref.watch(readerSettingsRepositoryProvider);
    final subscription = repository.watch().listen((settings) {
      if (!ref.mounted) return;
      // 导入和恢复后的字体参数需要同步注入；初次配色投影不重复刷新。
      final typographyChanged =
          state.fontSize != settings.fontSize ||
          state.lineHeight != settings.lineHeight;
      _applyReadingSettings();
      if (typographyChanged) _pushReadBookConfig();
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
    final styles = ref.watch(readerStyleRepositoryProvider);
    final styleSubscription = styles.watch().listen((_) {
      if (ref.mounted) _applyReadingSettings();
    });
    ref.onDispose(() => unawaited(styleSubscription.cancel()));
    final session = ref.watch(readerThemeSessionProvider);
    final sessionSubscription = session.watch().listen((_) {
      if (ref.mounted && _applyReadingSettings()) _pushReadBookConfig();
    });
    ref.onDispose(() => unawaited(sessionSubscription.cancel()));
    // 延迟到 build() 返回后执行（state 初始化完成后才能访问）
    unawaited(
      Future.microtask(_loadSettings).catchError((Object error) {
        debugPrint('阅读设置读取失败，可重新加载：$error');
      }),
    );
    // 主题与纯黑开关即时影响默认背景和夜间预设，不覆盖自定义配色。
    ref.listen(themeNotifierProvider, (previous, next) {
      if (previous?.themeMode != next.themeMode) {
        // 传入监听值（next.themeMode）而非重读持久化：setThemeMode
        // 先更新内存状态（触发本监听）后异步落盘，此刻读 prefs 是旧值
        unawaited(reapplyBackgroundForCurrentTheme(themeMode: next.themeMode));
      }
    });
    ref.listen(uiSettingsProvider.select((settings) => settings.themeAmoled), (
      previous,
      next,
    ) {
      unawaited(reapplyBackgroundForCurrentTheme(themeAmoled: next));
    });
    final settings = repository.current;
    return ReaderState(
      pageTurnMode: settings.pageTurnMode,
      fontSize: settings.fontSize,
      lineHeight: settings.lineHeight,
    );
  }

  /// 从同源仓储加载持久化设置，再投影当前会话配色。
  Future<void> _loadSettings() async {
    if (!ref.mounted) return;
    await ref.read(readerSettingsRepositoryProvider).load();
    await ref.read(readerStyleRepositoryProvider).load();
    await _effectiveThemeBrightness();
    if (!ref.mounted) return;
    _applyReadingSettings();
  }

  /// 主题变化只重新选择日夜配色，不替换当前模板或修改保存颜色。
  Future<void> reapplyBackgroundForCurrentTheme({
    ThemeMode? themeMode,
    bool? themeAmoled,
  }) async {
    final brightness = await _effectiveThemeBrightness(mode: themeMode);
    if (!ref.mounted) return;
    _applyReadingSettings(appBrightness: brightness, themeAmoled: themeAmoled);
    _pushReadBookConfig();
  }

  /// 投影同源设置；仅字号、行距及翻页选择改变对应布局参数。
  bool _applyReadingSettings({Brightness? appBrightness, bool? themeAmoled}) {
    final settings = ref.read(readerSettingsRepositoryProvider).current;
    final night =
        ref.read(readerThemeSessionProvider).isNightOverride ??
        (appBrightness ??
                _themeBrightness(ref.read(themeNotifierProvider).themeMode)) ==
            Brightness.dark;
    final colors = ref
        .read(readerStyleRepositoryProvider)
        .current
        .selected
        .colors(night);
    final resolved = colors.resolve(
      isNight: night,
      amoled: themeAmoled ?? ref.read(uiSettingsProvider).themeAmoled,
    );
    final next = state.copyWith(
      pageTurnMode: settings.pageTurnMode,
      fontSize: settings.fontSize,
      lineHeight: settings.lineHeight,
      backgroundColor: Color(resolved.background),
      foregroundColor: Color(resolved.text),
      readingBrightness: night ? Brightness.dark : Brightness.light,
    );
    if (next == state) return false;
    state = next;
    return true;
  }

  Future<void> _saveReadingSettings(Future<void> Function() update) async {
    final saving = update();
    _applyReadingSettings();
    try {
      await saving;
    } finally {
      if (ref.mounted) {
        _applyReadingSettings();
        _pushReadBookConfig();
      }
    }
  }

  Future<void> updateReaderThemeMode(ReaderThemeMode mode) async {
    ref.read(readerThemeSessionProvider).setMode(mode);
    _applyReadingSettings();
    _pushReadBookConfig();
  }

  Future<void> selectReaderStyle(String id) => _saveReadingSettings(
    () => ref.read(readerStyleRepositoryProvider).select(id),
  );

  Future<void> updateCustomTextColor(Color? color) => _saveReadingSettings(
    () => ref
        .read(readerStyleRepositoryProvider)
        .updateColors(
          isNight: state.isNightMode,
          update: (colors) => ReaderColors(
            background: colors.background,
            text: color?.toARGB32(),
          ),
        ),
  );

  /// [M1 深色态默认修复] 解析当前主题的有效亮度
  ///
  /// light/dark 取显式主题模式；system 取平台亮度。无 WidgetsBinding
  /// （如纯单测环境 `WidgetsBinding.instance` 抛 FlutterError）时回退
  /// 亮色，保证解析始终有值。
  /// [mode]：已知的新主题模式（主题切换监听路径直接传入）；
  /// 省略时等待共享外观快照（加载路径）。
  Future<Brightness> _effectiveThemeBrightness({ThemeMode? mode}) async {
    if (mode == null) {
      try {
        await ref.read(themeNotifierProvider.notifier).load();
      } catch (error) {
        debugPrint('外观设置读取失败，阅读背景沿用当前主题：$error');
      }
    }
    if (!ref.mounted) return Brightness.light;
    final effectiveMode = mode ?? ref.read(themeNotifierProvider).themeMode;
    return _themeBrightness(effectiveMode);
  }

  Brightness _themeBrightness(ThemeMode mode) {
    Brightness platform;
    try {
      platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    } catch (_) {
      platform = Brightness.light;
    }
    return themeBrightnessFor(mode, platform);
  }

  /// 打开书籍：加载目录并定位到上次阅读章节
  ///
  /// [C1a-hunt | 2026-09-24] 换书（bookUrl 变化）时同步清空上一本书的
  /// 残留状态（目录/正文/章索引/章内位置/分页器/全局页数）——对齐原版
  /// ReadBook.resetData(book) → clearTextChapter() 并重置 chapterSize。
  /// 修复前打开 B 书目录抓取失败时，A 书目录/正文仍留在 State，
  /// reader_page_view 的「error 非空 && 正文为空」全屏错误页门槛失效，
  /// A 书正文冒充 B 书渲染且无任何错误提示（C1a 缺陷）。同书重开
  /// （ErrorView 重试 / 自动换源重载 openBook(currentBook)）不清空，
  /// 保留既有状态（F1b 重试不丢章节）。
  ///
  /// [C1b-hunt | 2026-09-24] 代际守卫（_openSeq）：每次调用自增并捕获，
  /// 任一 await 之后若已被更新的 openBook 取代（并发开书 A 慢 / B 快）
  /// 则丢弃旧结果（不写目录/正文/索引、不写 error、不清 isLoading）——
  /// 防 A 的迟到结果覆盖已打开的 B（C1b 缺陷）。
  Future<void> openBook(Book book) async {
    final openSeq = ++_openSeq;
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
      _paginator.clear();
      // 全局页数随清空归零（totalPages=0 → globalPageIndex 钳制到 0）
      _syncGlobalPageInfo();
    }
    await _beginReadRecordSession(book);

    try {
      var chapters = await ref
          .read(readingRepositoryProvider)
          .getChapters(book.bookUrl);
      if (openSeq != _openSeq) return; // [C1b-hunt] 已被更新的 openBook 取代，丢弃旧结果
      // 对齐原版：本地无目录的网络书籍（如刚从搜索结果加入书架，
      // 尚未拉取过目录），自动经书源规则从网络获取目录
      if (chapters.isEmpty && book.origin.isNotEmpty) {
        chapters = await ref
            .read(readingRepositoryProvider)
            .refreshToc(book.bookUrl, book.origin);
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
      if (openSeq != _openSeq || !ref.mounted) return;
      _sourceAnchor = anchor;
      state = state.copyWith(
        chapters: chapters,
        currentChapterIndex: chapterIndex,
        currentChapterPos: 0,
      );
      await _loadChapterContent();
    } catch (e) {
      // [C1b-hunt] 被取代的 openBook 的错误不得覆盖新状态（collection-if
      // 保持 HEAD 基线缩进列，避免 diff 引入纯空白行）
      if (openSeq == _openSeq) state = state.copyWith(error: _mapError(e));
    } finally {
      if (openSeq == _openSeq) state = state.copyWith(isLoading: false);
    }
  }

  /// 进入下一章
  Future<void> nextChapter() async {
    if (!state.hasNextChapter) return;
    await _saveProgress();
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

  /// 进入上一章（[UI_SYNC_REFACTOR T3 修] 跳到上一章最后一页：
  /// currentChapterPos=-1 为哨兵值，ReaderPageView 分页完成后跳末页）
  ///
  /// [F1-hunt F6 | 2026-09-24] -1 哨兵只存在于 state.currentChapterPos
  /// 供视图消费：进度回写（_syncCurrentBookProgress）与持久化
  /// （_saveProgress）前统一归一为 0，-1 不进入 currentBook / DB。
  Future<void> prevChapter() async {
    if (!state.hasPreviousChapter) return;
    await _saveProgress();
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

  /// [UI_SYNC_REFACTOR T3 修] 消费 -1 哨兵后重置（防后续重分页再次跳末页）
  ///
  /// [F1-hunt F1 | 2026-09-24] 同步回写进度（prevChapter 回写时哨兵已
  /// 归一为 0，此处通常命中无变化快路径，不产生额外 notify）
  void resetChapterPos() {
    state = state.copyWith(currentChapterPos: 0);
    _syncCurrentBookProgress();
  }

  /// 跳转到指定章节
  Future<void> goToChapter(int index, {int? sourceOffset}) async {
    if (index < 0 || index >= state.chapters.length) return;
    await _saveProgress();
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

  /// 云端记录没有原文锚点时，只恢复章节，不把历史页号套用到新布局。
  Future<void> applyBookProgress({required int chapterIndex}) async {
    if (chapterIndex < 0 || chapterIndex >= state.chapters.length) return;
    await _saveProgress();
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

  // ===== 工具栏交互 =====

  /// 切换工具栏显隐
  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }

  /// 隐藏工具栏
  void hideControls() {
    if (state.showControls) {
      state = state.copyWith(showControls: false);
    }
  }

  // ===== 阅读设置（更新并持久化） =====

  /// 更新字体大小
  Future<void> updateFontSize(double size) => _saveReadingSettings(
    () => ref
        .read(readerSettingsRepositoryProvider)
        .update(fontSize: size.clamp(12.0, 32.0)),
  );

  /// 更新行高
  // [UI-fix v2.0.4 | 2026-08-08] 上限 2.5 → 3.0（界面 Sheet 行距连续
  // 滑条 1.0-3.0，对标原版 dsbLineSize 范围）— Qoder
  Future<void> updateLineHeight(double height) => _saveReadingSettings(
    () => ref
        .read(readerSettingsRepositoryProvider)
        .update(lineHeight: height.clamp(1.0, 3.0)),
  );

  /// 颜色更新始终进入当前样式的当前日夜配色。
  Future<void> updateBackgroundColor(Color color) =>
      updateCustomBackgroundColor(color);

  /// 设置变更后通过注入接口刷新 JS 可见快照；Mock 保持空操作。
  void _pushReadBookConfig() {
    try {
      unawaited(
        ref
            .read(readingConfigSyncProvider)
            .refreshReadBookConfig()
            .catchError((Object _) {}),
      );
    } catch (_) {}
  }

  Future<void> updateCustomBackgroundColor(Color color) => _saveReadingSettings(
    () => ref
        .read(readerStyleRepositoryProvider)
        .updateColors(
          isNight: state.isNightMode,
          update: (colors) =>
              ReaderColors(background: color.toARGB32(), text: colors.text),
        ),
  );

  /// 更新翻页模式
  Future<void> updatePageTurnMode(PageTurnMode mode) async {
    final repository = ref.read(readerSettingsRepositoryProvider);
    final saving = repository.update(pageTurnMode: mode);
    state = state.copyWith(pageTurnMode: repository.current.pageTurnMode);
    try {
      await saving;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(pageTurnMode: repository.current.pageTurnMode);
      }
    }
  }

  /// 更新当前阅读位置（由 UI 层滚动/翻页时调用）
  void updatePosition(int position, {int? sourceOffset}) {
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
    // [UI-fix v2.0.3 | 2026-08-06] 翻页/滑动后同步全局页索引，
    // 保证点击翻页与滑动手势翻页时全局页码指示器实时更新（此前仅
    // updateChapterPageCount 才刷新，导致章内翻页指示器停滞） — Qoder
    _syncGlobalPageInfo();
  }

  // ===== 跨章节连续分页导航 =====

  /// 更新章节分页信息（由 UI 层分页完成后调用）
  ///
  /// 当某章分页完成时，UI 层调用此方法注册该章的页数，
  /// 分页器据此维护全局页索引映射。
  void updateChapterPageCount(int chapterIndex, int pageCount) {
    _paginator.addChapter(chapterIndex, pageCount);
    _syncGlobalPageInfo();
  }

  /// 同步全局页信息到 State
  void _syncGlobalPageInfo() {
    final total = _paginator.totalPages();
    final globalStart = _paginator.globalIndexForChapterStart(
      state.currentChapterIndex,
    );
    final globalIndex = globalStart >= 0
        ? globalStart + state.currentChapterPos
        : state.globalPageIndex;
    state = state.copyWith(
      totalPages: total,
      globalPageIndex: globalIndex.clamp(0, total > 0 ? total - 1 : 0),
    );
  }

  /// 跳转到全局页索引
  ///
  /// 自动解析对应的章节和章内页，如果章节变化则加载新章节内容。
  Future<void> goToGlobalPage(int globalIndex) async {
    if (!_paginator.isValidGlobalIndex(globalIndex)) return;

    final resolved = _paginator.resolve(globalIndex);
    if (resolved == null) return;

    final targetChapter = resolved.chapterIndex;
    final targetPage = resolved.pageIndex;

    if (targetChapter != state.currentChapterIndex) {
      // 章节变化：加载新章节
      await _saveProgress();
      _sourceAnchor = null;
      state = state.copyWith(
        currentChapterIndex: targetChapter,
        currentChapterPos: targetPage,
        globalPageIndex: globalIndex,
        isLoading: true,
      );
      _syncCurrentBookProgress();
      final applied = await _loadChapterContent();
      if (!applied) return;
      state = state.copyWith(isLoading: false);
      await _saveProgress();
    } else {
      // 同章内翻页
      _sourceAnchor = null;
      state = state.copyWith(
        currentChapterPos: targetPage,
        globalPageIndex: globalIndex,
      );
      _syncCurrentBookProgress();
    }
  }

  /// 下一页（跨章节无缝）
  Future<void> nextGlobalPage() async {
    final next = state.globalPageIndex + 1;
    if (_paginator.isValidGlobalIndex(next)) {
      await goToGlobalPage(next);
    }
  }

  /// 上一页（跨章节无缝）
  Future<void> prevGlobalPage() async {
    final prev = state.globalPageIndex - 1;
    if (prev >= 0 && _paginator.isValidGlobalIndex(prev)) {
      await goToGlobalPage(prev);
    }
  }

  /// 保存当前阅读进度到后端
  Future<void> saveProgress() => _saveProgress();

  // [UI-fix v2.0.2 | 2026-08-06] 重新加载当前章正文（替换规则开关/重新分段/
  // 图片样式/繁简转换等书籍配置变更后由 UI 层调用，对标原版
  // ReadBook.loadContent(false)） — Qoder
  // [F1-hunt F4 | 2026-09-24] 成功加载会清 error（_loadChapterContent
  // 内代际守卫 + 清错），被取代的加载静默返回，不影响设置变更流程
  Future<void> reloadChapterContent() async {
    await _loadChapterContent();
  }

  // [UI-fix v2.0.2 | 2026-08-06] 同步已持久化的书对象到 State
  // （readConfig 变更经 BookshelfRepository.updateBook 落库后回写 UI 状态） — Qoder
  void updateCurrentBook(Book book) {
    state = state.copyWith(currentBook: book);
  }

  // [P2-9 | 2026-09-24] 强制刷新当前章正文（绕过缓存，重新联网抓取）
  // [STAGE3-C2B | 2026-09-28] 对齐上游原版 refreshContentDur（用户已裁决）：
  // delContent + loadContent = 先失效当前章缓存 → 再联网重抓。
  // 现已具备章级失效 FFI（clearChapterCache ≡ 上游 BookHelp.delContent，
  // 仅删当前章缓存行、不触碰章级开关键），C2 期自创的「先抓取、成功后才
  // 失效」与「成功后 clearBookCache 整书清缓存」一并移除——缓存优先 ×
  // fetch-first 的组合正是「已缓存章刷新不生效且误清整书离线缓存」的
  // 根因（STAGE3-C2B 裁决前形态）。
  //
  // 新语义（对齐上游）：
  // - 刷新必发网络请求（失效当前章缓存后，缓存优先不再拦截）；
  // - 成功：新内容持久化并更新 State（fetch 自动回写缓存行，无需再
  //   整书清缓存）；
  // - 失败（异常/空正文）：当前章缓存行已在「先失效」步骤删除（失败
  //   保留旧缓存的持久层语义按用户裁决对齐上游后不再保留），UI 保留
  //   旧正文并显示失败原因，同书他章缓存原样保留（无整书清理）。
  // [C5-hunt | 2026-09-24] 重入守卫（_refreshing）：在途期间重复调用
  // 直接返回原因，N 次点击不再触发 N 次失效 + N 次强制抓取
  // （对齐换源流程 isApplying/_applying 的防重入形态）。
  //
  // 成功返回 null；失败返回错误原因（保留旧正文，不清空 chapterContent）。
  // 本地书（origin 为空 / loc_book / dav:）与无书籍/目录/非法索引时
  // 直接返回说明性原因，不触碰 state 数据（对齐原版：本地书不显示
  // 换源/刷新菜单，此守卫兜底面板侧入口）。
  Future<String?> refreshChapterContent() async {
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
    final chapter = state.chapters[idx];
    state = state.copyWith(isLoading: true, error: null);
    try {
      // [STAGE3-C2B] 1) 先失效当前章缓存（≡ 上游 delContent：只删本章
      // 行，同书他章缓存不受影响）
      await ref
          .read(chapterCacheRepositoryProvider)
          .clearChapterCache(book.bookUrl, idx);
      // 2) 联网抓取（缓存已失效，缓存优先不再拦截，必取站点新内容）
      final content = await ref
          .read(readingRepositoryProvider)
          .fetchChapterContent(book.bookUrl, chapter.url, book.origin);
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
      // [STAGE3-C2B] 失败保留旧正文并显示原因；仅当前章缓存行丢失
      // （对齐上游，不做整书清理）
      final msg = _mapError(e);
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    } finally {
      _refreshing = false; // [C5-hunt]
    }
  }

  // [P2-9 | 2026-09-24] 换书源后重载（换源路由 await 返回、确认发生切换后调用）
  //
  // 顺序（与 openBook 的目录加载/定位语义对齐，勿误重置阅读进度）：
  // 1) getBook 重读书籍记录（Rust 换源事务已更新 origin/originName/
  //    tocUrl/originBookUrl 并清该书缓存）→ updateCurrentBook 同步对象；
  // 2) 重载目录：getChapters 优先本地库，空则 refreshToc 联网取（对齐 openBook）；
  // 3) 章节定位：旧章标题 精确 → 宽松（互含）→ 原索引（范围内）→ 0
  //    （对齐单章换源浮层 _matchChapterIndex 逻辑）；
  // 4) 位置保留：仅当命中章节与旧章同题时保留 currentChapterPos，
  //    否则归 0；随后持久化进度；
  // 5) 强制刷新命中章正文（同 refreshChapterContent 路径）。
  //
  // bookUrl 稳定性：Rust 换源事务保持 bookUrl 为稳定主键不变
  // （P2-8：originBookUrl 写入新源详情页地址）。即使 bookUrl 前后相同，
  // 缓存键（bookUrl+chapterUrl）可能未变，仍必须走强制路径清缓存，
  // 保证旧正文不残留（换源事务已清缓存，此处为防御性双保险）。
  //
  // 成功返回 null；失败返回错误原因（已完成的步骤不回滚：目录已更新则
  // 保留，旧正文保留，error 置位供 UI 反馈）。
  Future<String?> reloadAfterSourceChange(String bookUrl) async {
    final book = state.currentBook;
    if (book == null) return '没有书籍';
    // [SB-HUNT | 2026-09-25] 重入兜底：重载阶段在途（或导航阶段
    // 进行中）时直接返回，不重复 getBook/重载目录/清缓存
    if (_changeSourceFlowActive) return '更换书源进行中';
    _changeSourceFlowActive = true;
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
      final newBook = await ref
          .read(bookshelfRepositoryProvider)
          .getBook(bookUrl);
      if (newBook == null) {
        throw StateError('读取书籍记录失败');
      }
      // 2) 同步书籍对象（bookUrl 稳定，源相关字段为新值）
      state = state.copyWith(currentBook: newBook);
      // 3) 重载目录（对齐 openBook：本地库优先，空则联网）
      var chapters = await ref
          .read(readingRepositoryProvider)
          .getChapters(bookUrl);
      if (chapters.isEmpty && newBook.origin.isNotEmpty) {
        chapters = await ref
            .read(readingRepositoryProvider)
            .refreshToc(bookUrl, newBook.origin);
      }
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
      if (err != null) {
        // 正文抓取失败：目录已是新源，保留旧正文，错误显式返回
        state = state.copyWith(isLoading: false, error: err);
        return '正文刷新失败：$err';
      }
      // 持久化换源后的新进度（新章节索引/位置）
      await _saveProgress();
      state = state.copyWith(isLoading: false);
      return null;
    } catch (e) {
      final msg = _mapError(e);
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    } finally {
      // [SB-HUNT | 2026-09-25] 重载阶段锁必复位（含异常/取消路径）
      _changeSourceFlowActive = false;
    }
  }

  /// 换源重载目录后的章节定位（对齐 change_chapter_source_sheet 的
  /// _matchChapterIndex：精确标题 → 宽松互含 → 原索引（范围内）→ 0）
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

  // ===== 内部工具 =====

  Future<void> _saveProgress() async {
    final book = state.currentBook;
    if (book == null) return;
    try {
      // [F1-hunt F6 | 2026-09-24] 哨兵归一：prevChapter 的 -1（跳末页
      // 哨兵）只存在于 state.currentChapterPos 供视图消费，落库前归 0，
      // -1 不得持久化（修复前 -1 随 updateReadingProgress 写入
      // durChapterPos，下次 openBook 按非法位置定位）
      final pos = state.currentChapterPos < 0 ? 0 : state.currentChapterPos;
      final anchor = currentSourceOffset == null ? null : _sourceAnchor;
      await ref
          .read(readingRepositoryProvider)
          .updateReadingProgress(
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
      await _upReadTime(book);
    } catch (_) {
      // 保存失败不阻断阅读流程
    }
  }

  /// [F1-hunt F1 | 2026-09-24] 把当前阅读进度回写到 state.currentBook
  ///
  /// 修复前 currentBook 的 durChapterIndex/durChapterPos/durChapterTitle
  /// 永远停留在 openBook 时的快照，四个下游消费者均从 currentBook 读取
  /// 陈旧进度：ErrorView 重试（openBook(currentBook)）、设置保存
  /// （updateBook(currentBook.copyWith(...))）、自动换源重载
  /// （openBook(updated)）、目录高亮/定位。此处在每处章节/位置迁移点
  /// 把活进度回写 currentBook（仅三个进度字段，其余字段原样保留），
  /// 全行 updateBook 以此活快照写入，顺带中和 P2-8 陈旧快照覆写风险。
  ///
  /// openBook 不是回写点：以调用方传入的 book 为权威快照（既有测试
  /// 断言 openBook 不改写 currentBook）。
  ///
  /// [F1-hunt F6 | 2026-09-24] 哨兵归一：currentChapterPos < 0（-1 =
  /// 「跳上一章末页」哨兵）回写前归 0，-1 只存在于 state.currentChapterPos
  /// 供视图消费，不进入 currentBook / DB。
  void _syncCurrentBookProgress() {
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

  /// 进入阅读会话：加载已有时长并重置计时起点（对标 ReadBook.resetData）
  Future<void> _beginReadRecordSession(Book book) async {
    final session = ++_readRecordSession;
    _pendingReadStartMs = null;
    _readStartMs = DateTime.now().millisecondsSinceEpoch;
    _baseReadTimeMs = 0;
    try {
      final enable =
          (await ref.read(readRecordSettingsRepositoryProvider).load())
              .enableRecord;
      if (!enable) return;
      final records = await ref
          .read(readRecordRepositoryProvider)
          .getReadRecords();
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

  /// 累计并写入阅读时长（对标 ReadBook.upReadTime）
  Future<void> _upReadTime(Book book) async {
    final session = _readRecordSession;
    try {
      final enable =
          (await ref.read(readRecordSettingsRepositoryProvider).load())
              .enableRecord;
      if (!enable || session != _readRecordSession) return;
      final now = DateTime.now().millisecondsSinceEpoch;
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
      await ref
          .read(readRecordRepositoryProvider)
          .putReadRecord(
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

  /// 加载当前章节正文
  ///
  /// 统一调用 getChapterContentFull：本地书籍直接解析返回，在线书籍自动
  /// 从网络抓取并返回净化后的正文，始终返回纯正文字符串（无 JSON 元数据）。
  ///
  /// [F1-hunt F2 | 2026-09-24] 代际守卫（_loadSeq）：快速连点翻页时
  /// 多个加载并发在途，旧加载的结果返回时若已有更新的加载发起，则丢弃
  /// 旧结果（不覆盖新章正文、不写 error），返回 false，由调用方跳过
  /// 「清 isLoading / 保存进度」收尾——防旧章内容覆盖新章（F2 缺陷）。
  /// [F1-hunt F4 | 2026-09-24] 成功加载清 error（粘性错误随下一次成功
  /// 加载解除；失败置 error 并清空正文，视图层仅在正文为空时全屏降级，
  /// 见 ReaderPageView ErrorView 分支）。
  Future<bool> _loadChapterContent() async {
    final book = state.currentBook;
    if (book == null || state.chapters.isEmpty) return true;
    final seq = ++_loadSeq;
    // await 前捕获目标章：连点翻页后旧加载仍按自己捕获的索引取内容，
    // 完成后因代际过期被丢弃，不会误取/误写新章
    final index = state.currentChapterIndex;
    try {
      final content = await ref
          .read(readingRepositoryProvider)
          .getChapterContentFull(book.bookUrl, index);
      if (seq != _loadSeq) return false; // 已被更新的加载取代，丢弃旧结果
      state = state.copyWith(chapterContent: content, error: null);
      return true;
    } catch (e) {
      if (seq != _loadSeq) return false; // 被取代加载的错误同样不得覆盖新状态
      state = state.copyWith(error: _mapError(e), chapterContent: '');
      return true;
    }
  }

  /// 统一错误映射
  String _mapError(Object e) {
    if (e is BridgeError) return e.message;
    return e.toString();
  }
}

/// 阅读器 Notifier 全局 Provider
///
/// 使用方式：
/// ```dart
/// final state = ref.watch(readerNotifierProvider);
/// ref.read(readerNotifierProvider.notifier).openBook(book);
/// ```
final readerNotifierProvider = NotifierProvider<ReaderNotifier, ReaderState>(
  ReaderNotifier.new,
);
