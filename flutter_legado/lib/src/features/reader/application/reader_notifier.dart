export 'reader_state.dart';
import 'reader_session_controller.dart';
import 'reader_session_host.dart';
import '../../bookshelf/bookshelf_repositories.dart';
import '../../../providers/chapter_content_provider.dart';

import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:material_ui/material_ui.dart'
    show Brightness, ThemeMode, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../domain/models/reader_theme_mode.dart';
import '../../../domain/models/reader_style.dart';
import '../../../models/models.dart';
import '../../read_records/read_record_repository_provider.dart';
import '../../../providers/read_record_settings_provider.dart';
import '../../../services/reader_position_store.dart';
import '../layout/paragraph_layout_engine.dart';
import '../../../providers/providers.dart';
import '../../../providers/reading_provider.dart';
import '../../../providers/theme/theme_notifier.dart';
import '../../../providers/ui_settings/ui_settings_notifier.dart';
import 'reader_state.dart';
import 'reader_settings_provider.dart';

/// 阅读器状态与表现层协调；会话编排委托显式依赖的控制器。— Codex + UI
class ReaderNotifier extends Notifier<ReaderState> {
  ReaderSessionController? _sessionController;

  static String chapterIdFor(BookChapter chapter, int index) =>
      ReaderSessionController.chapterIdFor(chapter, index);

  int? get currentSourceOffset => _sessionController?.currentSourceOffset;
  bool get isRefreshing => _sessionController?.isRefreshing ?? false;
  bool get isChangeSourceFlowActive =>
      _sessionController?.isChangeSourceFlowActive ?? false;

  final CrossChapterPaginator _paginator = CrossChapterPaginator();
  CrossChapterPaginator get paginator => _paginator;

  bool tryBeginChangeSourceFlow() => _session.tryBeginChangeSourceFlow();
  void endChangeSourceFlow() => _sessionController?.endChangeSourceFlow();

  /// 首次会话操作时装配；设置与纯表现宿主不提前请求内容依赖。
  ReaderSessionController get _session {
    final current = _sessionController;
    if (current != null) return current;
    final session = ReaderSessionController(
      host: ReaderSessionHost(
        readState: () => state,
        writeState: (next) => state = next,
        resetPagination: () {
          _paginator.clear();
          _syncGlobalPageInfo();
        },
      ),
      reading: ref.read(readingRepositoryProvider),
      bookshelf: ref.read(bookshelfRepositoryProvider),
      content: ref.read(chapterContentServiceProvider),
      records: ref.read(readRecordRepositoryProvider),
      recordSettings: ref.read(readRecordSettingsRepositoryProvider),
      positionStore: ReaderPositionStore(),
    );
    _sessionController = session;
    ref.onDispose(() {
      session.dispose();
      if (identical(_sessionController, session)) _sessionController = null;
    });
    return session;
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
    final themeSession = ref.watch(readerThemeSessionProvider);
    final sessionSubscription = themeSession.watch().listen((_) {
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

  Future<void> openBook(Book book) => _session.openBook(book);

  Future<void> nextChapter() => _session.nextChapter();

  Future<void> prevChapter() => _session.prevChapter();

  void resetChapterPos() => _session.resetChapterPos();

  Future<void> goToChapter(int index, {int? sourceOffset}) =>
      _session.goToChapter(index, sourceOffset: sourceOffset);

  Future<void> applyBookProgress({required int chapterIndex}) =>
      _session.applyBookProgress(chapterIndex: chapterIndex);

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

  void updatePosition(int position, {int? sourceOffset}) {
    _session.updatePosition(position, sourceOffset: sourceOffset);
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
    await _session.goToPage(
      chapterIndex: resolved.chapterIndex,
      pageIndex: resolved.pageIndex,
      globalIndex: globalIndex,
    );
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

  Future<void> saveProgress() => _session.saveProgress();

  Future<void> reloadChapterContent() => _session.reloadChapterContent();

  void updateCurrentBook(Book book) => _session.updateCurrentBook(book);

  Future<String?> refreshChapterContent() => _session.refreshChapterContent();

  Future<String?> reloadAfterSourceChange(String bookUrl) =>
      _session.reloadAfterSourceChange(bookUrl);
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
