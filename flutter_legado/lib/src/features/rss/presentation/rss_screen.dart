import '../../../app/routing/app_navigation.dart';
import '../../../app/routing/route_arguments.dart';
import '../../../widgets/app_menu.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localization.dart';
import '../../../models/models.dart';
import '../application/rss_notifier.dart';
import '../application/history/rss_history_notifier.dart';
import '../../../app/routing/route_names.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/app_scroll_view.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/dynamic_search_app_bar.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/loading_indicator.dart';
import 'rss_articles_screen.dart';
import 'rss_article_detail_screen.dart';

/// RSS 源列表页面
class RssScreen extends ConsumerStatefulWidget {
  const RssScreen({super.key});

  @override
  ConsumerState<RssScreen> createState() => _RssScreenState();
}

class _RssScreenState extends ConsumerState<RssScreen> {
  /// 顶栏搜索框（对齐安卓原版 fragment_rss.xml 的 view_search：
  /// 实时按名称/URL 过滤已启用订阅源）
  final _searchController = TextEditingController();
  String _searchKey = '';
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rssNotifierProvider.notifier).loadSources();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 在分组过滤基础上叠加搜索过滤（对标原版 flowEnabled(searchKey)）
  List<RssSource> _applySearch(List<RssSource> sources) {
    final key = _searchKey.trim().toLowerCase();
    if (key.isEmpty) return sources;
    return sources
        .where(
          (s) =>
              s.sourceName.toLowerCase().contains(key) ||
              s.sourceUrl.toLowerCase().contains(key),
        )
        .toList();
  }

  void _confirmDeleteSource(RssSource source) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.deleteRssSource),
        content: Text(
          dialogContext.l10n.confirmDeleteNamedSource(source.sourceName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref
                  .read(rssNotifierProvider.notifier)
                  .removeSource(source.sourceUrl);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(dialogContext.l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rssNotifierProvider);
    final notifier = ref.read(rssNotifierProvider.notifier);
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: DynamicSearchAppBar(
        title: context.l10n.rss,
        // [UI_SYNC_REFACTOR S1b 修正] subtitle=当前分组；搜索行默认收起
        subtitle: (state.selectedGroup?.isEmpty ?? true)
            ? context.l10n.allBooks
            : state.selectedGroup,
        expanded: _searchExpanded,
        onExpandedChanged: (value) => setState(() => _searchExpanded = value),
        // [UI_SYNC_REFACTOR S1b] Dynamic 搜索行顶栏（对齐参考
        // DynamicTopAppBar：标题+搜索切换钮+bottomContent 展开行）
        // 原嵌入式胶囊搜索框迁至 bottomContent（appBar 由 LegadoAppBar
        // 换 DynamicSearchAppBar，actions 原样保留）
        searchController: _searchController,
        searchHint: context.l10n.rss,
        onChanged: (value) => setState(() => _searchKey = value),
        onClear: () {
          _searchController.clear();
          setState(() => _searchKey = '');
        },
        actions: [
          // 安卓原版顶栏 4 个功能入口：阅读记录/收藏/分组/订阅源管理
          // （原版 menu_read_record 打开阅读记录对话框，非独立页面）
          // [FIX 2026-09-04] 顶栏图标用 filled 填充版 + onSurface 显式色：
          // Symbols 描边版在浅底上对比度不足，用户报“顶部看不清楚”
          IconButton(
            icon: Icon(
              Symbols.history_rounded,
              fill: 1,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: context.l10n.readingRecords,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _ReadRecordDialog(),
            ),
          ),
          IconButton(
            icon: Icon(
              Symbols.star_rounded,
              fill: 1,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: context.l10n.favorites,
            onPressed: () =>
                GoRouter.of(context).pushAppRoute(AppRoutes.rssFavorites),
          ),
          // 分组筛选：对齐原版 RssFragment 的分组菜单（ic_groups 图标，linkedSetOf 保序聚合）
          AppMenuButton<String?>(
            tooltip: context.l10n.group,
            icon: Icon(
              Symbols.groups_rounded,
              fill: 1,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onSelected: (group) => notifier.setGroup(group),
            itemBuilder: (context) => [
              AppMenuItem<String?>(
                value: null,
                child: Text(context.l10n.allBooks),
              ),
              for (final group in state.groups)
                AppMenuItem<String?>(value: group, child: Text(group)),
            ],
          ),
          // 原版 menu_rss_config：齿轮图标即订阅源管理入口，
          // 返回后刷新源列表
          IconButton(
            icon: Icon(
              Symbols.settings_rounded,
              fill: 1,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: context.l10n.rssSourceManagement,
            onPressed: () async {
              await GoRouter.of(context)
                  .pushAppRoute(AppRoutes.rssSourceManage);
              if (mounted) notifier.loadSources();
            },
          ),
        ],
      ),
      // 安卓原版无 FAB：添加订阅源入口在订阅源管理页（对标 RssSourceActivity 菜单）
      body: Builder(
        builder: (context) {
          if (state.isLoadingSources && state.sources.isEmpty) {
            return LoadingIndicator(message: context.l10n.loadingRssSources);
          }

          if (state.error != null && state.sources.isEmpty) {
            return ErrorView(
              message: state.error!,
              onRetry: () => notifier.loadSources(),
            );
          }

          // 「规则订阅」入口格常驻（对标原版 header）；空态时网格仍在，
          // tvEmptyMsg 叠在 RecyclerView 中央（fragment_rss.xml）
          final displaySources = _applySearch(state.filteredSources);
          final emptyMsg = state.isEmpty
              ? context.l10n.emptyRssSources
              : (displaySources.isEmpty
                    ? context.l10n.emptyGroupRssSources
                    : null);

          // 入口卡片与源网格共用页面留白，网格按剩余宽度自适应列数。
          return AppScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildEntryCard(
                        context,
                        Icons.subscriptions,
                        context.l10n.ruleSubscriptions,
                        () =>
                            GoRouter.of(context)
                                .pushAppRoute(AppRoutes.ruleSub),
                      ),
                      const SizedBox(width: 12),
                      _buildEntryCard(
                        context,
                        Icons.star,
                        context.l10n.favorites,
                        () =>
                            GoRouter.of(context)
                                .pushAppRoute(AppRoutes.rssFavorites),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 12.0;
                    const minItemWidth = 72.0;
                    final columns = math.max(
                      1,
                      ((constraints.crossAxisExtent + spacing) /
                              (minItemWidth + spacing))
                          .floor(),
                    );
                    final itemWidth =
                        (constraints.crossAxisExtent -
                            spacing * (columns - 1)) /
                        columns;
                    final rows = (displaySources.length / columns).ceil();
                    // 每行按最高内容占位，各项的反馈仍贴合自身自然高度。
                    return SliverList.builder(
                      itemCount: rows,
                      itemBuilder: (context, row) {
                        final start = row * columns;
                        final end = math.min(
                          start + columns,
                          displaySources.length,
                        );
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: row == rows - 1 ? 0 : spacing,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var index = start; index < end; index++) ...[
                                if (index > start)
                                  const SizedBox(width: spacing),
                                SizedBox(
                                  width: itemWidth,
                                  child: _buildSourceItem(
                                    context,
                                    displaySources[index],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (emptyMsg != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Symbols.rss_feed_rounded,
                      title: emptyMsg,
                      simple: true,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 打开订阅源（对标 RssFragment.openRss：singleUrl → 阅读页/外链，否则文章列表）
  Future<void> _openRss(RssSource source) async {
    if (!source.singleUrl) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RssArticlesScreen(source: source)),
      );
      return;
    }
    final url = source.sourceUrl.trim();
    if (url.toLowerCase().startsWith('http://') ||
        url.toLowerCase().startsWith('https://')) {
      if (!mounted) return;
      await GoRouter.of(context)
          .pushAppRoute(AppRoutes.browser, extra: BrowserRouteArgs(url: url));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // [UI_SYNC_REFACTOR S5 修 | 2026-09-07] 自定义 scheme（如 snssdk1128://）
      // 无应用处理时 launchUrl 抛异常，此前被 unawaited 吞掉表现为"点了没反应"，
      // 现给出失败反馈 — Qoder
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.cannotOpenLink(url))),
        );
      }
    }
  }

  /// [UI_SYNC_REFACTOR T1] 头部双卡（对齐参考 GlassCard 双卡：规则订阅|收藏，
  /// surfaceContainer 底 16dp 圆角、12dp padding、24dp 图标+强调文案居中）
  Widget _buildEntryCard(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: cs.onSurface),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 自然高度源图标项：48dp 图标、8dp 间距、最多两行名称。
  Widget _buildSourceItem(BuildContext context, RssSource source) {
    final cs = Theme.of(context).colorScheme;
    final hasIcon = source.sourceIcon.trim().isNotEmpty;
    return InkWell(
      key: ValueKey(source.sourceUrl),
      borderRadius: BorderRadius.circular(16),
      onTap: () => unawaited(_openRss(source)),
      onLongPress: () => _confirmDeleteSource(source),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: hasIcon
                  ? CachedNetworkImage(
                      imageUrl: source.sourceIcon,
                      fit: BoxFit.cover,
                      memCacheWidth: 48 * 3,
                      errorWidget: (_, _, _) =>
                          _buildPlaceholderIcon(context, source, cs),
                    )
                  : _buildPlaceholderIcon(context, source, cs),
            ),
            const SizedBox(height: 8),
            Text(
              source.sourceName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// 占位图标：显示源名称首字母（iOS 风格柔和填充底）
  Widget _buildPlaceholderIcon(
    BuildContext context,
    RssSource source,
    ColorScheme colorScheme,
  ) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          source.sourceName.isNotEmpty
              ? source.sourceName[0].toUpperCase()
              : 'R',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  /// 占位图标：显示源名称首字母（iOS 风格柔和填充底）
}

/// 阅读记录对话框（对标原版 ReadRecordDialog：
/// 标题「阅读记录」+ 清除菜单 + 记录列表；点击条目重读并关闭对话框）
class _ReadRecordDialog extends ConsumerStatefulWidget {
  const _ReadRecordDialog();

  @override
  ConsumerState<_ReadRecordDialog> createState() => _ReadRecordDialogState();
}

class _ReadRecordDialogState extends ConsumerState<_ReadRecordDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rssHistoryNotifierProvider.notifier).load();
    });
  }

  /// 清除确认（对标原版：sure_del + 记录数 + read_record）
  Future<void> _confirmClear() async {
    final count = ref.read(rssHistoryNotifierProvider).records.length;
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.notice,
      content: context.l10n.confirmDeleteReadingRecordCount(count),
      confirmText: context.l10n.delete,
      isDestructive: true,
    );
    if (confirmed && mounted) {
      await ref.read(rssHistoryNotifierProvider.notifier).clear();
    }
  }

  /// 点击记录重读（对标原版 ReadRss.readRss：打开文章阅读页）
  void _openRecord(RssReadRecordRow record) {
    Navigator.of(context).pop(); // 对标原版点击后 dismiss
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RssArticleDetailScreen(
          article: RssFeedArticle(title: record.title, url: record.link ?? ''),
          sourceName: _hostOf(record.origin),
        ),
      ),
    );
  }

  String _hostOf(String origin) {
    final uri = Uri.tryParse(origin);
    return uri?.host.isNotEmpty == true ? uri!.host : origin;
  }

  String _formatTime(int millis) {
    if (millis <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
        '${pad(dt.hour)}:${pad(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rssHistoryNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏（对标原版 toolBar：阅读记录 + 清除菜单）
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.readingRecords,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: (state.records.isEmpty || state.isClearing)
                        ? null
                        : _confirmClear,
                    child: Text(
                      context.l10n.clearAction,
                      style: TextStyle(
                        color: (state.records.isEmpty || state.isClearing)
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(child: _buildList(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(RssHistoryState state) {
    // 注意：空态/加载分支不能用 Center（Align 在 loose 约束下会撑满
    // 可用高度，导致对话框被拉至 maxHeight），用 Column(min) 收缩
    if (state.isLoading || state.isClearing) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [CircularProgressIndicator()],
        ),
      );
    }
    if (state.records.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.noReadingRecords, style: TextStyle(fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: state.records.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final record = state.records[index];
        final time = _formatTime(record.readTime);
        return InkWell(
          onTap: () => _openRecord(record),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title.isEmpty ? context.l10n.untitled : record.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  time.isEmpty
                      ? _hostOf(record.origin)
                      : '${_hostOf(record.origin)}  ·  $time',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
