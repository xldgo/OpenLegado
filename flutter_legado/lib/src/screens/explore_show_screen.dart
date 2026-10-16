library;

export '../providers/explore/explore_show_notifier.dart' show ExploreShowArgs;
import '../features/bookshelf/bookshelf_repositories.dart';

/// 发现分类书籍浏览页面（ExploreShowScreen）
///
/// 参考 Android 原版 ExploreShowActivity.kt 实现：
/// 1. 标题 = 分类名 - 书源名（对标 titleBar.title = exploreName）
/// 2. 顶栏页码控件 + 「加入书架」（已加载书籍批量入架，对标 menuAddLoadedBooks）
/// 3. 下拉刷新 + 上滑翻页加载（ExploreBookList）
/// 4. 点击书籍跳转书籍详情页
///
/// 列表渲染与分页逻辑抽取至 [ExploreBookList]，供平板双栏右栏复用。

import '../l10n/app_localization.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../models/models.dart';
import '../providers/explore/explore_show_notifier.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/explore_book_list.dart';
import '../widgets/explore_page_control.dart';
import '../widgets/legado_app_bar.dart';

/// 路由参数类型转发（routes.dart / explore_screen.dart 依赖）— 保留原导出

/// 发现分类书籍浏览页
class ExploreShowScreen extends ConsumerStatefulWidget {
  final ExploreShowArgs? args;

  const ExploreShowScreen({super.key, this.args});

  @override
  ConsumerState<ExploreShowScreen> createState() => _ExploreShowScreenState();
}

class _ExploreShowScreenState extends ConsumerState<ExploreShowScreen> {
  /// [A1 对齐 | Qoder UI] 筛选关键字（匹配书名/作者；空=不过滤）
  String _filterKeyword = '';

  /// [A1 对齐 | Qoder UI] 紧凑密度（参考版 ☰ 列表切换语义）
  bool _compact = false;

  ExploreShowArgs? get args => widget.args;

  /// 将已加载书籍批量加入书架（对齐原版 addLoadedBooksToShelf）— 发现页修复 R5
  ///
  /// 经 LocalBookService.importBooks 批量导入（Rust RoomImporter 判重），
  /// 返回成功数量后提示；无已加载书籍时提示。
  Future<void> _addLoadedBooksToShelf(
    BuildContext context,
    WidgetRef ref,
    ExploreShowArgs args,
  ) async {
    final state = ref.read(exploreShowNotifierProvider(args));
    final books = state.books;
    if (books.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.noLoadedBooks)));
      return;
    }
    try {
      final jsonArray = jsonEncode([
        for (final b in books)
          Book(
            bookUrl: b.bookUrl,
            tocUrl: b.tocUrl,
            origin: b.origin,
            originName: b.originName,
            name: b.name,
            author: b.author,
            kind: b.kind,
            coverUrl: b.coverUrl,
            intro: b.intro,
            bookType: b.bookType,
            latestChapterTitle: b.latestChapterTitle,
            wordCount: b.wordCount,
          ).toJson(),
      ]);
      final added = await ref
          .read(bookshelfRepositoryProvider)
          .importBooks(jsonArray);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.addedToShelfCount(added))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.addToShelfFailed(e.toString()))),
      );
    }
  }

  /// [A1 对齐 | Qoder UI] 打开筛选关键字弹层（提交后返回关键字；取消返回 null）
  Future<void> _showFilterDialog() async {
    final keyword = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ExploreFilterDialog(initial: _filterKeyword),
    );
    if (!mounted) return;
    setState(() => _filterKeyword = keyword ?? _filterKeyword);
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final args = this.args;
    // 参数缺失兜底（正常路径由 routes.dart 保证非空）
    if (args == null) {
      // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
      return AppScaffold(
        topBar: LegadoAppBar(title: const Text('')),
        body: EmptyState(
          icon: Symbols.explore_rounded,
          title: context.l10n.invalidArguments,
          subtitle: context.l10n.missingDiscoveryCategory,
        ),
      );
    }

    // 标题：分类名 - 书源名（对标 Android titleBar.title = exploreName）
    final title = ref.watch(
      exploreShowNotifierProvider(args).select((s) => s.title),
    );

    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(
        title: Text(title),
        actions: [
          // [B2-C1 2-5 | full-stack-engineer + UI] 筛选漏斗按开启态着色
          // （默认非实心色）：默认态 = 深色中性漏斗（对齐参考版 06 顶栏
          // 像素核验：深色 onSurface、无 off 斜杠），开启态 = 实心 + 主题色
          IconButton(
            tooltip: _filterKeyword.isEmpty
                ? context.l10n.filter
                : context.l10n.activeKeywordFilter(_filterKeyword),
            onPressed: _showFilterDialog,
            icon: Icon(
              _filterKeyword.isEmpty
                  ? Symbols.filter_alt
                  : Symbols.filter_alt_rounded,
              color: _filterKeyword.isEmpty
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          // [A1 对齐 | Qoder UI] ☰ 列表切换：书卡密度 舒适/紧凑
          IconButton(
            tooltip: _compact
                ? context.l10n.switchComfortableLayout
                : context.l10n.switchCompactLayout,
            onPressed: () => setState(() => _compact = !_compact),
            icon: Icon(
              _compact ? Symbols.density_medium_rounded : Symbols.reorder,
            ),
          ),
          // 批量加入书架（对标原版 menuAddLoadedBooks；apple-ui-designer
          // 系统图标按钮，次级层级）— 发现页修复 R5
          IconButton(
            tooltip: context.l10n.addToBookshelf,
            icon: const Icon(Symbols.playlist_add_rounded),
            onPressed: () => _addLoadedBooksToShelf(context, ref, widget.args!),
          ),
          ExplorePageControl(args: args),
        ],
      ),
      body: ExploreBookList(
        args: args,
        filterKeyword: _filterKeyword,
        compact: _compact,
      ),
    );
  }
}

/// 发现书单筛选关键字弹层（有状态：controller 随弹层 State 建/销）
///
/// [A1 对齐 | Qoder UI] 生命周期与弹层子树严格一致（对齐 2.0.243 D1 修复
/// 模式：controller 不得建在 showDialog 外随 future dispose）。
class _ExploreFilterDialog extends StatefulWidget {
  final String initial;

  const _ExploreFilterDialog({required this.initial});

  @override
  State<_ExploreFilterDialog> createState() => _ExploreFilterDialogState();
}

class _ExploreFilterDialogState extends State<_ExploreFilterDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.filter),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.loadedBooksFilterHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: context.l10n.filterKeywordHint,
              isDense: true,
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(context.l10n.confirm),
        ),
      ],
    );
  }
}
