import 'bookshelf_repositories.dart';
import '../privacy/privacy_controller.dart';
import '../../l10n/app_localization.dart';
import '../../widgets/app_menu.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import 'bookshelf_notifier.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../utils/error_message.dart';

/// 分组排序方式
enum _GroupSort { order, name, bookCount }

/// 书籍分组管理页面
///
/// 支持分组的增删改、排序、封面设置、显示/隐藏，以及将书籍分配到分组。
class BookGroupScreen extends ConsumerStatefulWidget {
  const BookGroupScreen({super.key});

  @override
  ConsumerState<BookGroupScreen> createState() => _BookGroupScreenState();
}

class _BookGroupScreenState extends ConsumerState<BookGroupScreen> {
  List<BookGroup> _groups = [];
  bool _loading = true;
  String? _error;
  _GroupSort _sort = _GroupSort.order;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(bookGroupRepositoryProvider);
      final groups = await api.getBookGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _loading = false;
      });
    }
  }

  /// 某分组内的书籍数量
  int _bookCountOf(int groupId) {
    final books = ref.read(bookshelfNotifierProvider).books;
    return books.where((b) => b.group == groupId).length;
  }

  List<BookGroup> get _sortedGroups {
    final list = [..._groups];
    switch (_sort) {
      case _GroupSort.order:
        list.sort((a, b) => a.order.compareTo(b.order));
      case _GroupSort.name:
        list.sort((a, b) => a.groupName.compareTo(b.groupName));
      case _GroupSort.bookCount:
        list.sort(
          (a, b) => _bookCountOf(b.groupId).compareTo(_bookCountOf(a.groupId)),
        );
    }
    return list;
  }

  // ===== 增删改 =====

  Future<void> _showEditDialog({BookGroup? group}) async {
    final isEdit = group != null;
    final nameController = TextEditingController(text: group?.groupName ?? '');
    final coverController = TextEditingController(text: group?.cover ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? ctx.l10n.bookGroupEdit : ctx.l10n.bookGroupNew),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(labelText: ctx.l10n.groupName),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: coverController,
                decoration: const InputDecoration(labelText: '封面图片 URL（可选）'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.save),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    if (!mounted) return;

    final api = ref.read(bookGroupRepositoryProvider);
    try {
      if (isEdit) {
        await api.updateBookGroup(
          group.copyWith(
            groupName: name,
            cover: coverController.text.trim().isEmpty
                ? null
                : coverController.text.trim(),
          ),
        );
      } else {
        final nextOrder = _groups.isEmpty
            ? 0
            : _groups.map((g) => g.order).reduce((a, b) => a > b ? a : b) + 1;
        await api.addBookGroup(
          BookGroup(
            groupName: name,
            cover: coverController.text.trim().isEmpty
                ? null
                : coverController.text.trim(),
            order: nextOrder,
          ),
        );
      }
      await _loadGroups();
    } catch (e) {
      _showError('保存失败：$e');
    }
  }

  Future<void> _deleteGroup(BookGroup group) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.deleteGroup,
      content: '确定要删除分组「${group.groupName}」吗？分组内的书籍不会被删除。',
      confirmText: AppStrings.delete,
      isDestructive: true,
    );
    if (!confirmed) return;
    if (!mounted) return;
    try {
      final api = ref.read(bookGroupRepositoryProvider);
      await api.deleteBookGroup(group.groupId);
      await _loadGroups();
    } catch (e) {
      _showError('删除失败：$e');
    }
  }

  Future<void> _toggleShow(BookGroup group) async {
    try {
      final api = ref.read(bookGroupRepositoryProvider);
      await api.updateBookGroup(group.copyWith(show: !group.show));
      await _loadGroups();
    } catch (e) {
      _showError('更新失败：$e');
    }
  }

  /// 拖拽排序后持久化 order
  Future<void> _persistOrder(List<BookGroup> reordered) async {
    setState(() => _groups = reordered);
    final api = ref.read(bookGroupRepositoryProvider);
    try {
      for (var i = 0; i < reordered.length; i++) {
        final g = reordered[i];
        if (g.order != i) {
          final updated = g.copyWith(order: i);
          reordered[i] = updated;
          await api.updateBookGroup(updated);
        }
      }
      setState(() => _groups = [...reordered]);
    } catch (e) {
      _showError('排序失败：$e');
      await _loadGroups();
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    // [LAYOUT_PLAN P3] 状态色走 tonal
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: cs.onErrorContainer)),
        backgroundColor: cs.errorContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(
        title: Text(context.l10n.groupManagement),
        actions: [
          AppMenuButton<_GroupSort>(
            tooltip: context.l10n.bookGroupSortMode,
            icon: const Icon(Symbols.sort_rounded),
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              _sortItem(_GroupSort.order, '按排序值'),
              _sortItem(_GroupSort.name, context.l10n.sourceSortName),
              _sortItem(_GroupSort.bookCount, '按书籍数量'),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        tooltip: context.l10n.bookGroupNew,
        child: const Icon(Symbols.add_rounded),
      ),
    );
  }

  AppMenuItem<_GroupSort> _sortItem(_GroupSort value, String label) {
    return AppMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            _sort == value
                ? Symbols.radio_button_checked_rounded
                : Symbols.radio_button_unchecked_rounded,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return LoadingIndicator(message: context.l10n.bookGroupLoading);
    }
    if (_error != null) {
      return EmptyState(
        icon: Symbols.error_rounded,
        title: AppStrings.error,
        subtitle: _error,
        action: FilledButton(
          onPressed: _loadGroups,
          child: Text(AppStrings.retry),
        ),
      );
    }
    if (_groups.isEmpty) {
      return EmptyState(
        icon: Symbols.folder_special_rounded,
        title: context.l10n.bookGroupsEmpty,
        subtitle: '点击右下角按钮创建第一个分组',
      );
    }

    final groups = _sortedGroups;
    // 手动排序模式下支持拖拽
    if (_sort == _GroupSort.order) {
      return ReorderableListView.builder(
        // [LAYOUT_PLAN P3] 页面水平边距16dp
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        itemCount: groups.length,
        onReorderItem: (oldIndex, newIndex) {
          final list = [...groups];
          final item = list.removeAt(oldIndex);
          list.insert(newIndex, item);
          _persistOrder(list);
        },
        itemBuilder: (context, index) =>
            _buildGroupTile(groups[index], draggable: true),
      );
    }
    return ListView.builder(
      // [LAYOUT_PLAN P3] 页面水平边距16dp
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: groups.length,
      itemBuilder: (context, index) =>
          _buildGroupTile(groups[index], draggable: false),
    );
  }

  Widget _buildGroupTile(BookGroup group, {required bool draggable}) {
    final count = _bookCountOf(group.groupId);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // [LAYOUT_PLAN P3] 分组卡圆角16dp + 组内行 vertical12/horizontal8 + 字级走 M3 Type Scale
    return Card(
      key: ValueKey(group.groupId),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        leading: draggable
            ? ReorderableDragStartListener(
                index: _sortedGroups.indexOf(group),
                child: BookCover(
                  coverUrl: group.cover,
                  width: 40,
                  height: 54,
                  borderRadius: 4,
                  // [LAYOUT_PLAN P4] 补 heroTag（分组以 groupId 唯一，避免列表重复 tag）
                  heroTag: 'book-cover:group:${group.groupId}',
                ),
              )
            : BookCover(
                coverUrl: group.cover,
                width: 40,
                height: 54,
                borderRadius: 4,
                // [LAYOUT_PLAN P4] 补 heroTag（分组以 groupId 唯一，避免列表重复 tag）
                heroTag: 'book-cover:group:${group.groupId}',
              ),
        title: Text(
          group.groupName,
          // [LAYOUT_PLAN P3] 列表行字级走 M3 Type Scale
          style: textTheme.titleSmall?.copyWith(
            color: group.show ? null : cs.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          context.l10n.bookGroupBookCount(count),
          style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 显示/隐藏开关
            Tooltip(
              message: group.show
                  ? context.l10n.bookGroupShownOnShelf
                  : context.l10n.bookGroupHiddenOnShelf,
              child: Switch(
                value: group.show,
                onChanged: (_) => _toggleShow(group),
              ),
            ),
            AppMenuButton<String>(
              onSelected: (action) => _handleAction(action, group),
              itemBuilder: (_) => [
                AppMenuItem(value: 'assign', child: Text('分配书籍')),
                if (group.groupId > 0)
                  AppMenuItem(
                    value: 'private',
                    child: Text(group.isPrivate ? '取消私密' : '设为私密'),
                  ),
                AppMenuItem(value: 'edit', child: Text(AppStrings.edit)),
                AppMenuItem(
                  value: 'delete',
                  child: Text(
                    AppStrings.delete,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _assignBooks(group),
      ),
    );
  }

  Future<void> _setGroupPrivate(BookGroup group) async {
    try {
      await ref
          .read(privacyControllerProvider.notifier)
          .setGroupPrivate(group, !group.isPrivate);
      await _loadGroups();
      await ref.read(bookshelfNotifierProvider.notifier).refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('私密标记保存失败')));
      }
    }
  }

  void _handleAction(String action, BookGroup group) {
    switch (action) {
      case 'private':
        _setGroupPrivate(group);
      case 'assign':
        _assignBooks(group);
      case 'edit':
        _showEditDialog(group: group);
      case 'delete':
        _deleteGroup(group);
    }
  }

  /// 将书籍分配到分组（多选）
  Future<void> _assignBooks(BookGroup group) async {
    final books = ref.read(bookshelfNotifierProvider).books;
    if (books.isEmpty) {
      _showError('书架暂无书籍');
      return;
    }
    final selected = <String>{
      for (final b in books.where((b) => b.group == group.groupId)) b.bookUrl,
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('分配书籍到「${group.groupName}」'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: books.length,
              itemBuilder: (_, i) {
                final book = books[i];
                final checked = selected.contains(book.bookUrl);
                return CheckboxListTile(
                  dense: true,
                  value: checked,
                  title: Text(
                    book.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onChanged: (on) {
                    setDialogState(() {
                      if (on == true) {
                        selected.add(book.bookUrl);
                      } else {
                        selected.remove(book.bookUrl);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final api = ref.read(bookshelfRepositoryProvider);
    try {
      for (final book in books) {
        final shouldIn = selected.contains(book.bookUrl);
        final isIn = book.group == group.groupId;
        if (shouldIn && !isIn) {
          await api.setBookGroup(book.bookUrl, group.groupId);
        } else if (!shouldIn && isIn) {
          await api.setBookGroup(book.bookUrl, 0);
        }
      }
      await ref.read(bookshelfNotifierProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已更新「${group.groupName}」的书籍')));
      }
    } catch (e) {
      _showError('分配失败：$e');
    }
  }
}
