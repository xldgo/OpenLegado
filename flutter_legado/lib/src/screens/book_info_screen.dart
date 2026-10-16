import '../features/book_detail/book_detail_notifier.dart';
import '../features/book_detail/book_detail_state.dart';

import 'package:flutter_legado/src/domain/services/book_metadata_policy.dart';
import 'package:flutter_legado/src/domain/services/book_type_policy.dart';

import '../providers/backup_provider.dart';
import '../features/book_sources/book_source_repository_provider.dart';
import '../providers/reading_provider.dart';
import '../providers/source_action_provider.dart';
import '../providers/chapter_cache_provider.dart';
import '../features/privacy/privacy_controller.dart';
import '../widgets/app_menu.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../providers/auto_task/auto_task_notifier.dart';
import '../features/bookshelf/bookshelf.dart';
import '../providers/reader/reader_notifier.dart';
import '../providers/sync/sync_notifier.dart';
import '../routes.dart';
import '../providers/ui_settings/ui_settings_notifier.dart';
import '../widgets/legado_app_bar.dart';
import '../widgets/top_bar_button.dart';
import '../services/cover_palette_service.dart';
import '../services/cache_service.dart';
import '../services/local_book_store.dart'; // [iOS 视角F C1] 本地书相对标识解析
import '../services/platform_bridge_service.dart';
import '../providers/bookshelf_settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/book_info_utils.dart';
import '../utils/book_open_utils.dart';
import '../utils/meaningful_text_guard.dart'; // [U4 | 台账 0917] 详情页渲染层模板残留守卫
// [08 元信息区对齐 | 台账 0922 修订] book_progress_utils 导入已随「目录：已读 X%」
// 行移除而不再使用（工具本身保留：book_list_item 仍用，单测保留）
import '../utils/source_login_entry.dart';
import '../utils/source_login_prompt.dart';
import '../widgets/book_cover.dart';
import '../widgets/ui_settings_scope.dart';
import '../widgets/custom_refresh_indicator.dart'; // [LAYOUT_PLAN P4 收尾] 详情下拉 M3 化
import '../widgets/error_view.dart';
import '../widgets/skeleton.dart'; // [LAYOUT_PLAN P4] 首屏 Skeleton 接线
import '../widgets/list_footer.dart';
part 'book_info_screen_load.part.dart';
part 'book_info_screen_builders.part.dart';
part 'book_info_screen_dialogs.part.dart';

// ↑ 分域 part 文件（体检 §三.16 超长文件拆分）：非生命周期方法按域拆入 extension，
// 零行为变更（同 library 私有成员可访问）。

/// 书籍详情页面
class BookInfoScreen extends ConsumerStatefulWidget {
  /// 书籍对象（路由参数规范化：优先使用 Book 对象）
  final Book? book;

  /// 书籍 URL（向后兼容，当未传入 Book 对象时使用）
  final String bookUrl;

  /// [A4 对齐 B | 2026-09-21 裁决] 进入后目录就绪即自动打开阅读器
  ///（等价重构版 `BookInfoPage(openReaderImmediately: true)`：书架未读书
  ///单击入口）；目录不可用则停留在详情页，仍可经「阅读」FAB 手动开读。
  /// 默认 false，既有入口（长按封面/书名、阅读记录、搜索等）行为不变。
  final bool openReaderImmediately;

  const BookInfoScreen({
    super.key,
    this.book,
    this.bookUrl = '',
    this.openReaderImmediately = false,
  });

  /// 获取有效的 bookUrl：优先从 Book 对象取值
  String get effectiveBookUrl => book?.bookUrl ?? bookUrl;

  @override
  ConsumerState<BookInfoScreen> createState() => _BookInfoScreenState();
}

class _BookInfoScreenState extends ConsumerState<BookInfoScreen> {
  final ScrollController _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Object? _coverThemeKey;
  ThemeData? _coverTheme;

  /// 位于局部主题内的页面上下文，弹层操作不依赖已经关闭的菜单。
  BuildContext get _pageContext => _scaffoldKey.currentContext ?? context;

  /// [UI_SYNC_REFACTOR B4] 顶栏折叠进度（对齐参考仓 collapsedFraction：
  /// 封面区滚动归一化，驱动透明→玻璃色插值）
  final ValueNotifier<double> _topCollapse = ValueNotifier<double>(0);

  /// [UI_SYNC_REFACTOR B4] 封面取色 seed（null=未取/关闭开关）
  Color? _coverSeed;
  bool _isLoading = false;

  late final _detailProvider = bookDetailProvider((
    bookUrl: widget.effectiveBookUrl,
    book: widget.book,
  ));
  BookDetailState get _detail => ref.read(_detailProvider);
  BookDetailNotifier get _detailNotifier => ref.read(_detailProvider.notifier);
  Book? get _loadedBook => _detail.data.book;
  List<BookChapter> get _chapters => _detail.data.chapters;
  BookSource? get _bookSource => _detail.data.source;
  bool get _inBookshelf => _detail.data.inBookshelf;
  bool get _pageLoading => _detail.pageLoading;
  bool get _tocLoading => _detail.tocLoading;
  bool get _networkLoading => _detail.networkLoading;
  String? get _loadError => _detail.error;

  // [A4 对齐 B | 2026-09-21 裁决；2026-09-22 review 硬化] 自动开读机会
  // 是否已消费：首轮全量加载完成时无条件置位（机会只属于首入——目录非空
  // 才真正自动开读，目录为空则停留详情页）；此后 _reload / 桥接刷新 /
  // 菜单刷新不再触发（对标重构版 BookInfoPage._autoStartScheduled）。
  // postFrame 回调内另有 ModalRoute 栈顶校验，防用户抢先导航后二次压栈。
  bool _autoStartScheduled = false;
  // [UI-FIX v2.0.3 | 2026-08-08] 删除提醒开关（对齐原版 LocalConfig.deleteBookAlert，本地持久化） — Qoder
  bool get _deleteBookAlert =>
      ref.read(bookshelfSettingsRepositoryProvider).current.deleteBookAlert;

  @override
  void initState() {
    super.initState();
    // 发现/搜索带入的 Book 立刻上屏（对齐原版 bookData.postValue 先于网络）
    ref.listenManual(_detailProvider, _onDetailChanged);
    Future.microtask(_loadData);
    _loadDeleteBookAlert();
    PlatformBridgeService.refreshSignal.addListener(_onBridgeRefresh);
    // [UI_SYNC_REFACTOR B4] 封面区滚动 → 顶栏折叠进度（对齐参考仓
    // exitUntilCollapsed 的 collapsedFraction，120px 归一区间）
    _scrollController.addListener(() {
      final offset = _scrollController.hasClients
          ? _scrollController.offset
          : 0.0;
      final fraction = (offset / 120).clamp(0.0, 1.0);
      if ((fraction - _topCollapse.value).abs() > 0.01) {
        _topCollapse.value = fraction;
      }
    });
    if (_loadedBook != null) {
      unawaited(_extractCoverSeed(_loadedBook!));
    }
  }

  @override
  void dispose() {
    PlatformBridgeService.refreshSignal.removeListener(_onBridgeRefresh);
    _scrollController.dispose();
    _topCollapse.dispose();
    super.dispose();
  }

  /// [UI_SYNC_REFACTOR B4] 封面取色（跟随封面换肤开关开启时生效）
  Future<void> _extractCoverSeed(Book book) async {
    final ui = ref.read(uiSettingsProvider);
    if (!ui.bookInfoFollowCoverColor) return;
    final coverUrl = book.customCoverUrl ?? book.coverUrl;
    if (coverUrl == null || coverUrl.isEmpty) return;
    final seed = await CoverPaletteService.extractSeed(coverUrl);
    if (!mounted) return;
    setState(() => _coverSeed = seed);
  }

  /// [PARITY C1 D3] 右下「阅读」胶囊 FAB（对齐参考 08 量化：
  /// 阅读按钮的容器和前景使用当前局部主题；位置与阅读跳转行为保持原样。
  /// 标签固定「阅读」（原「继续阅读」文案移除，参考即固定「阅读」）；
  /// 阅读跳转链路 _openReader 行为不变，续读位置仍取 durChapterIndex，
  /// 加书架/移出书架入口保留在操作区第一卡）
  Widget _buildReadFab(BuildContext context) {
    final book = _loadedBook;
    if (book == null) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      icon: const Icon(Symbols.menu_book_rounded),
      label: const Text('阅读'),
      onPressed: () => _openReader(context, book, book.durChapterIndex),
    );
  }

  /// [UI_SYNC_REFACTOR B4] 顶栏 actions（原 appBar actions 原样迁移，
  /// 由折叠 SliverAppBar 经 TopBarActionStyler 统一注入样式）
  List<Widget> _buildTopBarActions(BuildContext context) {
    return [
      // 编辑：仅在架书籍显示（对标原版 editMenuItem.isVisible = inBookshelf）
      if (_inBookshelf)
        IconButton(
          icon: const Icon(Symbols.edit_rounded),
          tooltip: '编辑书籍信息',
          onPressed: () async {
            try {
              final book = _loadedBook;
              if (book == null) return;
              if (!mounted) return;
              // [fix Task#24 | 2026-08-08] 去掉 <bool> 泛型，避免 routes 表
              // MaterialPageRoute<dynamic> 运行时强转崩溃 — Qoder
              final saved = await Navigator.pushNamed(
                context,
                AppRoutes.editBookInfo,
                arguments: book,
              );
              // 编辑保存成功后重新加载书籍信息
              if (saved == true && mounted) {
                _reload();
              }
            } catch (e) {
              // [审计修复 §4.1] 不再静默吞异常，向用户提示 — Qoder
              debugPrint('编辑书籍信息失败: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('书籍信息暂不可用，请稍后重试')));
              }
            }
          },
        ),
      IconButton(
        icon: const Icon(Symbols.ios_share_rounded),
        tooltip: '分享',
        onPressed: () async {
          try {
            final book = _loadedBook;
            if (book == null) return;
            // 对齐原版 menu_share_it：bookUrl#bookJson + SourceCallBack
            // — Cursor UI
            final shareStr = '${book.bookUrl}#${jsonEncode(book.toJson())}';
            final r = await ref
                .read(sourceActionServiceProvider)
                .sourceCallBackBtn(
                  event: 'clickShareBook',
                  bookUrl: book.bookUrl,
                  bookType: book.bookType,
                  result: shareStr,
                );
            if (!r.handled) {
              await SharePlus.instance.share(ShareParams(text: shareStr));
            }
          } catch (e) {
            // [审计修复 §4.1] 不再静默吞异常，向用户提示 — Qoder
            debugPrint('分享书籍失败: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('书籍信息暂不可用，请稍后重试')));
            }
          }
        },
      ),
      if (_bookSource?.customButton == true)
        IconButton(
          icon: const Icon(Symbols.extension_rounded),
          tooltip: '自定义',
          onPressed: _onCustomButton,
        ),
      // 安卓原版三点菜单；P2-2 自定义按钮已接通 callBackBtn 中途 UI 桥
      AppMenuButton<String>(
        tooltip: '更多',
        onSelected: _handleMenu,
        itemBuilder: (_) {
          final book = _loadedBook;
          final source = _bookSource;
          final hasSource = source != null;
          final isLocal = book != null && !_isOnlineBook(book);
          final isLocalTxt = book != null && _isLocalTxt(book);
          final hasLogin = (source?.loginUrl ?? '').isNotEmpty;
          final canUpd = book?.canUpdate ?? true;
          final cs = Theme.of(context).colorScheme;
          // [U1 | 台账 0917] 勾选项尾部化：CheckboxListTile 式右侧 ✓
          //（对齐参考 08 勾选项尾样式；原 AppMenuItem 为 leading ✓）
          AppMenuItem<String> checkedItem(
            String value,
            String label,
            bool checked,
          ) {
            return AppMenuItem<String>(
              value: value,
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  if (checked)
                    Icon(Symbols.check_rounded, size: 18, color: cs.primary),
                ],
              ),
            );
          }

          return [
            // ── 前段：对齐参考 08 菜单项序（U1 | 台账 0917）──
            const AppMenuItem(value: 'refresh', child: Text('刷新')),
            // 设置源变量（Task #63 冻结 / #64-65 实现，§5.11-3 已接通）/
            // 设置书籍变量（[Task #39 §5.11-4] 已接通变量对话框 + updateBook）
            if (hasSource)
              const AppMenuItem(value: 'sourceVariable', child: Text('设置源变量')),
            if (hasSource)
              const AppMenuItem(value: 'bookVariable', child: Text('设置书籍变量')),
            const AppMenuItem(value: 'copyBookUrl', child: Text('拷贝书籍URL')),
            const AppMenuItem(value: 'copyTocUrl', child: Text('拷贝目录URL')),
            const AppMenuItem(value: 'top', child: Text('置顶')),
            // 允许更新（书源存在；勾选态尾部 ✓）
            if (hasSource)
              checkedItem('canUpdate', '允许更新', book?.canUpdate ?? true),
            // [UI-fix v2.0.3] 删除提醒接通本地持久化（对齐原版
            // LocalConfig.deleteBookAlert；勾选态尾部 ✓）
            checkedItem('deleteAlert', '删除提醒', _deleteBookAlert),
            const AppMenuItem(value: 'clearCache', child: Text('清理缓存')),
            // ── 分隔线后：本端独有项（双基准 + 红线：功能不删除）──
            // [GLOBALCOMP B5] 自造 disabled AppMenuItem+Divider 换统一
            // AppMenuDivider（对齐 B1 批 8 处弹窗菜单分隔形态）
            const AppMenuDivider<String>(),
            if (source?.customButton == true)
              const AppMenuItem(value: 'customBtn', child: Text('自定义')),
            if (isLocal)
              const AppMenuItem(value: 'upload', child: Text('上传至远程')),
            // 创建书籍更新任务（在架 + 书源 + 非本地 + 允许更新；
            // [Task #39 §5.11-2] 已接通 AutoTaskScreen 编辑/创建流程）
            if (_inBookshelf && hasSource && !isLocal && canUpd)
              const AppMenuItem(value: 'updateTask', child: Text('创建书籍更新任务')),
            // 登录（书源支持登录时）
            if (hasLogin) const AppMenuItem(value: 'login', child: Text('登录')),
            // [B1 形态对齐]「分组」由操作宫格收纳进 ⋮ 菜单（复用 _showChangeGroup）
            const AppMenuItem(value: 'group', child: Text('设置分组')),
            if (book != null && _inBookshelf)
              AppMenuItem(
                value: 'private',
                child: Text(book.isPrivate ? '取消私密' : '设为私密'),
              ),
            // 拆分长章节（仅本地 txt；勾选态尾部 ✓；
            // isLocalTxt 已隐含 book != null，Dart 3 提升生效）
            if (isLocalTxt)
              checkedItem(
                'splitLongChapter',
                '拆分长章节',
                book.readConfig?.splitLongChapter ?? true,
              ),
            const AppMenuItem(value: 'cacheDownloads', child: Text('缓存下载队列')),
            const AppMenuItem(value: 'log', child: Text('日志')),
          ];
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_detailProvider);
    ref.watch(bookshelfSettingsProvider);
    final baseTheme = Theme.of(context);
    ref.listen(
      uiSettingsProvider.select(
        (settings) => settings.bookInfoFollowCoverColor,
      ),
      (_, enabled) {
        final book = _loadedBook;
        if (enabled && _coverSeed == null && book != null) {
          unawaited(_extractCoverSeed(book));
        }
      },
    );
    final followCover = ref.watch(
      uiSettingsProvider.select(
        (settings) => settings.bookInfoFollowCoverColor,
      ),
    );
    final seed = followCover ? _coverSeed : null;
    final themeKey = (baseTheme, seed);
    // 输入变化时计算目标主题；动画帧只插值，不重复从封面生成色板。
    if (_coverThemeKey != themeKey) {
      _coverThemeKey = themeKey;
      _coverTheme = seed == null
          ? baseTheme
          : AppTheme.withColorScheme(
              baseTheme,
              ColorScheme.fromSeed(
                seedColor: seed,
                brightness: baseTheme.brightness,
              ),
            );
    }

    // 保留 400ms 封面换肤动画，所有组件和页面弹层共用完整局部主题。
    return AnimatedTheme(
      data: _coverTheme!,
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      child: Builder(
        builder: (pageContext) => Scaffold(
          key: _scaffoldKey,
          floatingActionButton: _pageLoading || _loadedBook == null
              ? null
              : _buildReadFab(pageContext),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          body: _pageLoading
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 4,
                  itemBuilder: (_, _) => const ListSkeletonItem(),
                )
              : _loadError != null && _loadedBook == null
              ? ErrorView(message: _loadError!, onRetry: _reload)
              : _loadedBook == null
              ? const ErrorView(message: '书籍不存在')
              : _buildPage(pageContext, _loadedBook!, _chapters),
        ),
      ),
    );
  }
}
