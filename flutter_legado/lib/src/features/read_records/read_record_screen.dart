import '../privacy/privacy_gate.dart';
import '../../widgets/app_search_transition.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../l10n/app_localization.dart';
import '../bookshelf/bookshelf.dart';
import '../../routes.dart';
import '../../utils/book_open_utils.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_menu.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/md3_fast_scroller.dart';
import '../../widgets/custom_refresh_indicator.dart';
import 'read_record_repository_provider.dart';
import 'read_record_notifier.dart';
import 'read_record_state.dart';
import 'read_record_dataset.dart';
import 'read_record_list_provider.dart';
import 'read_record_list_calculator.dart';

/// 对齐上游阅读记录三视图；统计/合并位于计算器，持久化位于Repository。— Codex + UI
class ReadRecordScreen extends ConsumerStatefulWidget {
  const ReadRecordScreen({super.key});
  @override
  ConsumerState<ReadRecordScreen> createState() => _ReadRecordScreenState();
}

class _ReadRecordScreenState extends ConsumerState<ReadRecordScreen> {
  final _listController = ScrollController();
  final _searchController = TextEditingController();
  bool _showSearch = false;
  final Set<String> _selected = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(readRecordNotifierProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _listController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _modeLabel(ReadRecordDisplayMode mode) => switch (mode) {
    ReadRecordDisplayMode.aggregate => context.l10n.readRecordViewAggregate,
    ReadRecordDisplayMode.timeline => context.l10n.readRecordViewTimeline,
    ReadRecordDisplayMode.latest => context.l10n.readRecordViewLatest,
  };
  Future<void> _refresh() async {
    ref.invalidate(readRecordDatasetProvider);
    ref.invalidate(readRecordSessionsProvider);
    await ref.read(readRecordNotifierProvider.notifier).load();
    await ref.read(readRecordDatasetProvider.future);
  }

  void _switchMode() {
    final current = ref.read(readRecordNotifierProvider).displayMode;
    final next = ReadRecordDisplayMode.values[(current.index + 1) % 3];
    setState(_selected.clear);
    ref
        .read(readRecordNotifierProvider.notifier)
        .setDisplayMode(next)
        .catchError((Object e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(e.toString())));
          }
        });
  }

  Future<void> _open(ReadRecordListEntry entry) async {
    if (_selected.isNotEmpty) {
      setState(
        () => _selected.contains(entry.key)
            ? _selected.remove(entry.key)
            : _selected.add(entry.key),
      );
      return;
    }
    final books = ref.read(bookshelfNotifierProvider).books;
    final book = books
        .where(
          (b) =>
              b.name == entry.bookName &&
              (entry.author.isEmpty || b.author == entry.author),
        )
        .where((b) => entry.bookUrl.isEmpty || b.bookUrl == entry.bookUrl)
        .firstOrNull;
    if (book != null) {
      await BookOpenUtils.openBook(context, ref, book);
    } else if (mounted) {
      await Navigator.pushNamed(
        context,
        AppRoutes.search,
        arguments: entry.bookName,
      );
    }
  }

  Future<bool> _confirmDelete({bool clearAll = false, int count = 1}) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.delete),
          content: Text(
            clearAll
                ? ctx.l10n.confirmClearReadingRecords
                : ctx.l10n.confirmDeleteReadingRecordCount(count),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.confirm),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _delete(List<ReadRecordListEntry> entries) async {
    if (!await _confirmDelete(count: entries.length) || !mounted) return;
    try {
      final repo = ref.read(readRecordRepositoryProvider);
      final mode = ref.read(readRecordNotifierProvider).displayMode;
      if (mode == ReadRecordDisplayMode.timeline) {
        await repo.deleteReadRecordSessions([
          for (final e in entries) ...e.sessionIds,
        ]);
      } else {
        for (final e in entries) {
          if (mode == ReadRecordDisplayMode.aggregate) {
            await repo.deleteReadRecordDetail(e.bookName, e.author, e.date!);
          } else {
            await repo.deleteReadRecord(e.bookName, author: e.author);
          }
        }
      }
      if (mounted) setState(_selected.clear);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _clearAll() async {
    if (!await _confirmDelete(clearAll: true) || !mounted) return;
    try {
      await ref.read(readRecordRepositoryProvider).clearReadRecords();
      if (mounted) setState(_selected.clear);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controls = ref.watch(readRecordNotifierProvider);
    final rows = ref.watch(readRecordListProvider);
    final data = ref.watch(readRecordDatasetProvider);
    final summary = data.asData == null
        ? null
        : ReadRecordListCalculator.summary(
            records: data.asData!.value.records,
            details: data.asData!.value.details,
            query: controls.searchQuery,
          );
    final selection = _selected.isNotEmpty;
    return PopScope(
      canPop: !selection,
      onPopInvokedWithResult: (popped, result) {
        if (!popped && selection) setState(_selected.clear);
      },
      child: AppScaffold(
        topBar: LegadoAppBar(
          showBack: true,
          leading: selection
              ? IconButton(
                  icon: const Icon(Symbols.close_rounded),
                  onPressed: () => setState(_selected.clear),
                )
              : null,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selection ? '${_selected.length}' : context.l10n.readingRecords,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!selection)
                Text(
                  _modeLabel(controls.displayMode),
                  style: Theme.of(context).textTheme.labelMedium,
                  maxLines: 1,
                ),
            ],
          ),
          actions: selection
              ? [
                  IconButton(
                    tooltip: context.l10n.delete,
                    icon: const Icon(Symbols.delete_rounded),
                    onPressed: () => _delete(
                      (rows.asData?.value ?? [])
                          .where((e) => _selected.contains(e.key))
                          .toList(),
                    ),
                  ),
                ]
              : [
                  IconButton(
                    tooltip: context.l10n.switchReadRecordView,
                    icon: Icon(switch (controls.displayMode) {
                      ReadRecordDisplayMode.aggregate =>
                        Symbols.timeline_rounded,
                      ReadRecordDisplayMode.timeline =>
                        Symbols.schedule_rounded,
                      ReadRecordDisplayMode.latest => Symbols.list_rounded,
                    }),
                    onPressed: _switchMode,
                  ),
                  IconButton(
                    tooltip: context.l10n.search,
                    icon: const Icon(Symbols.search_rounded),
                    onPressed: () {
                      setState(() => _showSearch = !_showSearch);
                      if (!_showSearch) {
                        _searchController.clear();
                        ref
                            .read(readRecordNotifierProvider.notifier)
                            .setSearchQuery('');
                      }
                    },
                  ),
                  AppMenuButton<String>(
                    tooltip: context.l10n.readingRecordOptions,
                    onSelected: (value) {
                      if (value == 'enable') {
                        ref
                            .read(readRecordNotifierProvider.notifier)
                            .toggleEnableRecord()
                            .catchError((Object error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.l10n.loginSaveFailed),
                                  ),
                                );
                              }
                            });
                      }
                      if (value == 'clear') _clearAll();
                    },
                    itemBuilder: (_) => [
                      AppMenuItem(
                        value: 'enable',
                        checked: controls.enableRecord,
                        child: Text(context.l10n.readingRecordEnabled),
                      ),
                      AppMenuItem(
                        value: 'clear',
                        child: Text(context.l10n.clear),
                      ),
                    ],
                  ),
                ],
        ),
        body: Column(
          children: [
            AppSearchTransition(
              expanded: _showSearch,
              builder: (context, progress) => AppSearchReveal(
                progress: progress,
                expanded: _showSearch,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: AppSearchField(
                    controller: _searchController,
                    hintText: context.l10n.searchBookOrAuthor,
                    onChanged: (q) {
                      setState(_selected.clear);
                      ref
                          .read(readRecordNotifierProvider.notifier)
                          .setSearchQuery(q);
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: rows.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error.toString()),
                      TextButton(
                        onPressed: _refresh,
                        child: Text(context.l10n.retry),
                      ),
                    ],
                  ),
                ),
                data: (entries) => CustomRefreshIndicator(
                  onRefresh: _refresh,
                  child: Md3FastScroller(
                    controller: _listController,
                    child: CustomScrollView(
                      controller: _listController,
                      slivers: [
                        if (summary != null && summary.books.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: _summaryCard(
                                summary.books,
                                summary.durationMs,
                              ),
                            ),
                          ),
                        if (entries.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(context.l10n.noReadingRecords),
                            ),
                          ),
                        if (controls.displayMode ==
                            ReadRecordDisplayMode.latest)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList.builder(
                              itemCount: entries.length,
                              itemBuilder: (_, index) => Consumer(
                                builder: (_, tileRef, _) => _tile(
                                  entries[index],
                                  controls.displayMode,
                                  tileRef,
                                ),
                              ),
                            ),
                          )
                        else
                          _groupedSliver(entries, controls.displayMode),
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 对齐上游：汇总和时间线每天一个外层卡片，共用日期头。
  Widget _groupedSliver(
    List<ReadRecordListEntry> entries,
    ReadRecordDisplayMode mode,
  ) {
    final groups = ReadRecordListCalculator.group(entries);
    final cs = Theme.of(context).colorScheme;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return Card(
            key: ValueKey(
              '${mode == ReadRecordDisplayMode.aggregate ? 'read-record-day' : 'read-record-timeline-day'}-${group.date}',
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 0,
            color: cs.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _friendlyDate(context, group.date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      if (mode == ReadRecordDisplayMode.aggregate) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                context.l10n.readRecordDayDuration(
                                  formatDuring(group.durationMs),
                                ),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: cs.surface),
                for (var i = 0; i < group.entries.length; i++) ...[
                  if (mode == ReadRecordDisplayMode.aggregate && i > 0)
                    Divider(height: 1, thickness: 1, color: cs.surface),
                  Consumer(
                    builder: (_, tileRef, _) =>
                        _tile(group.entries[i], mode, tileRef),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryCard(List<ReadRecordListEntry> entries, int duration) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final books = ref.watch(bookshelfNotifierProvider.select((s) => s.books));
    final covers = entries.take(5).toList();
    return Tooltip(
      message: context.l10n.readRecordOverview,
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerLow,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.readRecordOverview),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.readRecordTotalAchievement,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.readRecordSummaryBooks(entries.length),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.readRecordSummaryTime(
                          formatDuring(duration),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44 + 14.0 * (covers.length - 1),
                  height: 64,
                  child: Stack(
                    children: [
                      for (var i = 0; i < covers.length; i++)
                        Positioned(
                          left: i * 14.0,
                          top: 0,
                          width: 44,
                          height: 64,
                          child: BookCover(
                            coverUrl: books
                                .where(
                                  (b) =>
                                      b.name == covers[i].bookName &&
                                      b.author == covers[i].author,
                                )
                                .firstOrNull
                                ?.coverUrl,
                            borderRadius: 6,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(
    ReadRecordListEntry entry,
    ReadRecordDisplayMode mode,
    WidgetRef tileRef,
  ) {
    final selected = _selected.contains(entry.key);
    final book = tileRef
        .watch(bookshelfNotifierProvider.select((s) => s.books))
        .where((b) => b.name == entry.bookName && b.author == entry.author)
        .firstOrNull;
    final clock = DateTime.fromMillisecondsSinceEpoch(entry.lastRead);
    final time =
        '${clock.hour.toString().padLeft(2, '0')}:${clock.minute.toString().padLeft(2, '0')}';
    final chapter = mode == ReadRecordDisplayMode.timeline
        ? tileRef
              .watch(
                readRecordChapterTitleProvider((
                  entry.bookUrl,
                  entry.chapterIndex,
                )),
              )
              .asData
              ?.value
        : null;
    final content = mode == ReadRecordDisplayMode.aggregate
        ? InkWell(
            onTap: () => _open(entry),
            onLongPress: () => setState(
              () => selected
                  ? _selected.remove(entry.key)
                  : _selected.add(entry.key),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 62,
                    child: selected
                        ? const Icon(Symbols.check_circle_rounded)
                        : BookCover(coverUrl: book?.coverUrl, borderRadius: 6),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.bookName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          entry.author.isEmpty
                              ? context.l10n.readRecordUnknownAuthor
                              : entry.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.readRecordBookDuration(
                            formatDuring(entry.durationMs),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        : mode == ReadRecordDisplayMode.timeline
        ? Semantics(
            label: formatDuring(entry.durationMs),
            child: InkWell(
              onTap: () => _open(entry),
              onLongPress: () => setState(
                () => selected
                    ? _selected.remove(entry.key)
                    : _selected.add(entry.key),
              ),
              child: CustomPaint(
                painter: _TimelineRailPainter(
                  lineColor: Theme.of(context).colorScheme.surface,
                  nodeColor: Theme.of(context).colorScheme.primary,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 12, 16, 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          time,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 62,
                        child: BookCover(
                          coverUrl: book?.coverUrl,
                          borderRadius: 6,
                        ),
                      ),
                      if (_selected.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(
                          selected
                              ? Symbols.check_circle_rounded
                              : Symbols.radio_button_unchecked_rounded,
                          size: 20,
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.bookName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              entry.author.isEmpty
                                  ? context.l10n.readRecordUnknownAuthor
                                  : entry.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              chapter ??
                                  context.l10n.readRecordChapter(
                                    entry.chapterIndex + 1,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : InkWell(
            onTap: () => _open(entry),
            onLongPress: () => setState(
              () => selected
                  ? _selected.remove(entry.key)
                  : _selected.add(entry.key),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 62,
                    child: BookCover(coverUrl: book?.coverUrl, borderRadius: 6),
                  ),
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(
                      selected
                          ? Symbols.check_circle_rounded
                          : Symbols.radio_button_unchecked_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                  ] else
                    const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.bookName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          entry.author.isEmpty
                              ? context.l10n.readRecordUnknownAuthor
                              : entry.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${formatDuring(entry.durationMs)} • ',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '${clock.year}-${clock.month.toString().padLeft(2, '0')}-${clock.day.toString().padLeft(2, '0')} $time',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
    final tile = PrivacyMaskedContent(
      bookName: entry.bookName,
      author: entry.author,
      onTap: () => _open(entry),
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : Colors.transparent,
        child: content,
      ),
    );
    if (_selected.isNotEmpty) return tile;
    return PrivacyMaskedContent(
      bookName: entry.bookName,
      author: entry.author,
      onTap: () => _open(entry),
      child: Dismissible(
        key: ValueKey(entry.key),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.all(16),
          child: const Icon(Symbols.delete_rounded),
        ),
        confirmDismiss: (_) async {
          await _delete([entry]);
          return false;
        },
        child: tile,
      ),
    );
  }
}

/// 对齐上游时间线几何：横坐标16、线宽2、节点半径4，按条目实际高度连接。
class _TimelineRailPainter extends CustomPainter {
  final Color lineColor, nodeColor;
  const _TimelineRailPainter({
    required this.lineColor,
    required this.nodeColor,
  });
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      const Offset(16, 0),
      Offset(16, size.height),
      Paint()
        ..color = lineColor
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(16, size.height / 2),
      4,
      Paint()..color = nodeColor,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelineRailPainter oldDelegate) =>
      lineColor != oldDelegate.lineColor || nodeColor != oldDelegate.nodeColor;
}

/// 以日历日期计算天数，避免夏令时导致24小时差值偏移。
String _friendlyDate(BuildContext context, String date) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;
  final now = DateTime.now();
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(parsed.year, parsed.month, parsed.day)).inDays;
  return switch (days) {
    0 => context.l10n.readRecordToday,
    1 => context.l10n.readRecordYesterday,
    >= 2 && <= 5 => context.l10n.readRecordDaysAgo(days),
    _ => date,
  };
}

String formatDuring(int mss) {
  if (mss <= 0) return '0秒';
  final days = mss ~/ (1000 * 60 * 60 * 24);
  final hours = (mss % (1000 * 60 * 60 * 24)) ~/ (1000 * 60 * 60);
  final minutes = (mss % (1000 * 60 * 60)) ~/ (1000 * 60);
  final seconds = (mss % (1000 * 60)) ~/ 1000;
  final buf = StringBuffer();
  if (days > 0) buf.write('$days天');
  if (hours > 0) buf.write('$hours小时');
  if (minutes > 0) buf.write('$minutes分钟');
  if (seconds > 0) buf.write('$seconds秒');
  final time = buf.toString();
  return time.isEmpty ? '0秒' : time;
}
