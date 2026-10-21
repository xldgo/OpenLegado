import '../privacy/privacy_gate.dart';
import '../../widgets/dynamic_search_app_bar.dart';
import '../../l10n/app_localization.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/app_scaffold.dart';
import '../../widgets/md3_fast_scroller.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../models/models.dart';
import '../../widgets/app_menu.dart';
import 'bookmark_notifier.dart';
import 'bookmark_state.dart';
import 'widgets/bookmark_note_sheet.dart';

/// 书签管理页面
class BookmarkScreen extends ConsumerStatefulWidget {
  const BookmarkScreen({super.key});

  @override
  ConsumerState<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends ConsumerState<BookmarkScreen> {
  // [UI_SYNC_REFACTOR R3] 快速滚动条控制器
  final ScrollController _fsController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _searchExpanded = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookmarkNotifierProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: DynamicSearchAppBar(
        title: context.l10n.bookmarks,
        searchController: _searchController,
        searchHint: context.l10n.bookmarkSearchHint,
        expanded: _searchExpanded,
        onExpandedChanged: (value) => setState(() => _searchExpanded = value),
        onChanged: (_) {},
        onSubmitted: _searchBookmarks,
        onClear: () => _searchBookmarks(''),
      ),
      body: _buildBody(ref.watch(bookmarkNotifierProvider)),
    );
  }

  Widget _buildBody(BookmarkState state) {
    final notifier = ref.read(bookmarkNotifierProvider.notifier);
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
              onPressed: () => notifier.loadAll(),
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }
    if (state.bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.bookmark_border_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? context.l10n.readerNoBookmark
                  : context.l10n.bookmarkNoMatches,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }
    return _buildBookmarkList(context, state);
  }

  Widget _buildBookmarkList(BuildContext context, BookmarkState state) {
    // [UI_SYNC_REFACTOR R3] 书签列表快速滚动条
    return AppScrollBody(
      controller: _fsController,
      builder: (context, scrollController) => Md3FastScroller(
        controller: scrollController,
        child: ListView.builder(
          controller: scrollController,
          itemCount: state.bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = state.bookmarks[index];
            return _BookmarkTile(
              bookmark: bookmark,
              onTap: () => _navigateToChapter(context, bookmark),
              onDelete: () => _confirmDelete(context, bookmark),
              onEdit: () => _editNote(bookmark),
            );
          },
        ),
      ),
    );
  }

  void _navigateToChapter(BuildContext context, Bookmark bookmark) {
    // 返回书签信息给调用方，由 reader_screen 处理跳转
    Navigator.of(context).pop({
      'bookName': bookmark.bookName,
      'chapterIndex': bookmark.chapterIndex,
      'chapterPos': bookmark.chapterPos,
    });
  }

  Future<void> _editNote(Bookmark bookmark) async {
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

  void _confirmDelete(BuildContext context, Bookmark bookmark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.readerDeleteBookmark),
        content: Text(
          ctx.l10n.confirmDeleteChapterBookmark(bookmark.chapterName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref
                  .read(bookmarkNotifierProvider.notifier)
                  .deleteBookmark(bookmark.id);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(ctx.l10n.bookmarkDeleted)));
            },
            child: Text(ctx.l10n.delete),
          ),
        ],
      ),
    );
  }

  void _searchBookmarks(String query) {
    setState(() => _searchQuery = query);
    ref.read(bookmarkNotifierProvider.notifier).search(query);
  }
}

class _BookmarkTile extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _BookmarkTile({
    required this.bookmark,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // [Task #54 | 2026-08-10] 缺陷⑤修复：Rust 侧 bookmark.time 已是
    // epoch 毫秒，删除多余的 ×1000 换算（原导致年份 58575） — Qoder
    final time = DateTime.fromMillisecondsSinceEpoch(bookmark.time);
    final timeStr =
        '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return PrivacyMaskedContent(
      bookName: bookmark.bookName,
      author: bookmark.bookAuthor,
      onTap: onTap,
      child: AppMenuAnchor<String>(
        itemBuilder: (ctx) => [
          AppMenuItem(value: 'edit', child: Text(ctx.l10n.bookmarkEditNote)),
          AppMenuItem(
            value: 'delete',
            child: Text(ctx.l10n.readerDeleteBookmark),
          ),
        ],
        onSelected: (action) {
          if (action == 'edit') onEdit();
          if (action == 'delete') onDelete();
        },
        builder: (ctx, controller, child) => Card(
          color: theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // [LAYOUT_PLAN P1] 卡片边距统一 horizontal16（全局标尺），纵向 4 保留密度
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: InkWell(
            onTap: onTap,
            onLongPress: controller.open,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              // [LAYOUT_PLAN P1] 卡内统一 16dp
              padding: const EdgeInsets.all(16),
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
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(timeStr, style: theme.textTheme.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Symbols.menu_book_rounded,
                        size: 14,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          bookmark.bookName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            // [FIX 2026-09-04] 正文次要文字走 onSurfaceVariant（outline 仅用于边框/装饰图标）
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        context.l10n.bookmarkChapterNumber(
                          bookmark.chapterIndex + 1,
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          // [FIX 2026-09-04] 正文次要文字走 onSurfaceVariant（outline 仅用于边框/装饰图标）
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
                      context.l10n.bookmarkNoteText(bookmark.content),
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
      ),
    );
  }
}
