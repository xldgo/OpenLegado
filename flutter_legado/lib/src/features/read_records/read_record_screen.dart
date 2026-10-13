import '../../l10n/app_localization.dart';
import '../../widgets/app_menu.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'widgets/read_record_daily_view.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';
import '../../widgets/app_search_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider;

import '../../models/models.dart';
import 'read_record_repository_provider.dart';
import 'read_record_notifier.dart';
import 'read_record_state.dart';
import '../../routes.dart';
import '../../utils/book_open_utils.dart';
import '../../widgets/custom_refresh_indicator.dart';
import '../../widgets/md3_fast_scroller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_indicator.dart';

/// 阅读记录页（对齐原版 `ReadRecordActivity`）
///
/// 功能：总时长、可搜索书单、按书名/时长/最后阅读排序、
/// 启用记录开关、清空单本/全部；点击进阅读或搜索。
/// UI 仅渲染与交互；数据经 [ReadRecordNotifier] → ReadRecordRepository。
/// — Auto + UI
class ReadRecordScreen extends ConsumerStatefulWidget {
  const ReadRecordScreen({super.key});

  @override
  ConsumerState<ReadRecordScreen> createState() => _ReadRecordScreenState();
}

class _ReadRecordScreenState extends ConsumerState<ReadRecordScreen> {
  // [UI_SYNC_REFACTOR R3] 快速滚动条控制器
  final ScrollController _listController = ScrollController();
  final _searchController = TextEditingController();

  /// 列表视图模式（0=按书 现状，1=按天 差异清单 C5）
  int _viewMode = 0;

  /// 每日时长数据（readRecordDailyList 既有契约；null=未加载）
  List<Map<String, dynamic>>? _daily;

  /// 加载每日时长（按天视图数据源；失败保持 null 走空态）
  Future<void> _loadDailyForView() async {
    try {
      final list = await ref
          .read(readRecordRepositoryProvider)
          .readRecordDailyList(DateTime.now().year);
      if (!mounted) return;
      setState(() => _daily = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _daily = const []);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(readRecordNotifierProvider.notifier).load();
      // 按天视图数据（懒加载一次；切到按天时立即可用）
      _loadDailyForView();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(int ms) {
    if (ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readRecordNotifierProvider);

    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(
        title: AppSearchField(
          controller: _searchController,
          hintText: context.l10n.readingRecordSearchHint,
          onChanged: (q) =>
              ref.read(readRecordNotifierProvider.notifier).setSearchQuery(q),
        ),
        actions: [
          AppMenuButton<String>(
            tooltip: context.l10n.readingRecordOptions,
            onSelected: _onMenuSelected,
            itemBuilder: (_) => [
              AppMenuItem(
                value: 'sort_name',
                checked: state.sortMode == ReadRecordSortMode.name,
                child: Text(context.l10n.readingRecordSortName),
              ),
              AppMenuItem(
                value: 'sort_read_long',
                checked: state.sortMode == ReadRecordSortMode.readTime,
                child: Text(context.l10n.readingRecordSortDuration),
              ),
              AppMenuItem(
                value: 'sort_last_read',
                checked: state.sortMode == ReadRecordSortMode.lastRead,
                child: Text(context.l10n.readingRecordSortLastRead),
              ),
              const AppMenuDivider(),
              AppMenuItem(
                value: 'enable_record',
                checked: state.enableRecord,
                child: Text(context.l10n.readingRecordEnabled),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 差异清单 C5：累计成就卡（已读 N 本 / 累计 X）+ 清空入口
          ReadAchievementCard(
            readBooks: state.records.where((r) => r.readTime > 0).length,
            totalDurationText: formatDuring(state.totalReadTimeMs),
            onClearAll: state.records.isEmpty && state.totalReadTimeMs == 0
                ? null
                : () => _confirmClearAll(context),
          ),
          // 视图切换（按书=现状 / 按天=时间线）
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('按书')),
                  ButtonSegment(value: 1, label: Text('按天')),
                ],
                selected: {_viewMode},
                onSelectionChanged: (sel) =>
                    setState(() => _viewMode = sel.first),
              ),
            ),
          ),
          // [LAYOUT_PLAN P3] 分隔线走 tonal 舍 outlineVariant（对齐 file_manage/offline_cache 样板）
          const Divider(height: 1, indent: 16, endIndent: 16),
          Expanded(
            child: _viewMode == 1
                ? ReadRecordDailyView(
                    daily: _daily,
                    formatSeconds: (sec) => formatDuring(sec * 1000),
                    onRetry: _loadDailyForView,
                  )
                : _buildBody(context, state),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ReadRecordState state) {
    if (state.isLoading && state.records.isEmpty) {
      return LoadingIndicator(message: context.l10n.readingRecordLoading);
    }
    if (state.error != null && state.records.isEmpty) {
      return ErrorView(
        message: state.error!,
        onRetry: () => ref.read(readRecordNotifierProvider.notifier).load(),
      );
    }
    if (state.records.isEmpty) {
      return EmptyState(
        icon: Symbols.history_rounded,
        title: state.searchQuery.isEmpty
            ? context.l10n.noReadingRecords
            : context.l10n.readingRecordNoMatches,
      );
    }
    // [LAYOUT_PLAN P4 收尾] 下拉 M3 化：裸 RefreshIndicator → CustomRefreshIndicator
    // [UI_SYNC_REFACTOR R3] 千级记录快速滚动条
    return CustomRefreshIndicator(
      onRefresh: () => ref.read(readRecordNotifierProvider.notifier).load(),
      child: Md3FastScroller(
        controller: _listController,
        child: ListView.separated(
          controller: _listController,
          // [LAYOUT_PLAN P3] 页面水平边距 16dp；纵向留白 8dp
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: state.records.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            // [LAYOUT_PLAN P3] 分隔线走 tonal 舍 outlineVariant（对齐 file_manage/offline_cache 样板）
            indent: 16,
            endIndent: 16,
          ),
          itemBuilder: (context, index) {
            final item = state.records[index];
            return _ReadRecordTile(
              item: item,
              lastReadText: _formatDate(item.lastRead),
              durationText: formatDuring(item.readTime),
              onTap: () => _openRecord(context, item),
              onClear: () => _confirmDelete(context, item),
            );
          },
        ),
      ),
    );
  }

  Future<void> _onMenuSelected(String value) async {
    final notifier = ref.read(readRecordNotifierProvider.notifier);
    switch (value) {
      case 'sort_name':
        await notifier.setSortMode(ReadRecordSortMode.name);
      case 'sort_read_long':
        await notifier.setSortMode(ReadRecordSortMode.readTime);
      case 'sort_last_read':
        await notifier.setSortMode(ReadRecordSortMode.lastRead);
      case 'enable_record':
        await notifier.toggleEnableRecord();
    }
  }

  Future<void> _openRecord(BuildContext context, ReadRecordShow item) async {
    final notifier = ref.read(readRecordNotifierProvider.notifier);
    final book = await notifier.findBookByName(item.bookName);
    if (!context.mounted) return;
    if (book == null) {
      // 对齐原版：书架无书 → 带书名打开搜索
      await Navigator.pushNamed(
        context,
        AppRoutes.search,
        arguments: item.bookName,
      );
      return;
    }
    await _openBook(context, book);
  }

  /// 对齐原版 startActivityForBook（分流编排统一在 BookOpenUtils.openBook）
  Future<void> _openBook(BuildContext context, Book book) async {
    await BookOpenUtils.openBook(context, ref, book);
  }

  Future<void> _confirmDelete(BuildContext context, ReadRecordShow item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.delete),
        content: Text(ctx.l10n.confirmDeleteNamedReadingRecord(item.bookName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.confirm),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref
          .read(readRecordNotifierProvider.notifier)
          .deleteByName(item.bookName);
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.delete),
        content: Text(ctx.l10n.confirmClearReadingRecords),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.confirm),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(readRecordNotifierProvider.notifier).clearAll();
    }
  }
}

/// 时长格式化（对齐原版 formatDuring，单位毫秒）
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

class _ReadRecordTile extends StatelessWidget {
  final ReadRecordShow item;
  final String durationText;
  final String lastReadText;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _ReadRecordTile({
    required this.item,
    required this.durationText,
    required this.lastReadText,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondary = colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.bookName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.readingRecordDurationText(durationText),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: secondary),
                  ),
                  if (lastReadText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.readingRecordLastReadText(lastReadText),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: secondary),
                    ),
                  ],
                ],
              ),
            ),
            TextButton(onPressed: onClear, child: Text(context.l10n.clear)),
          ],
        ),
      ),
    );
  }
}
