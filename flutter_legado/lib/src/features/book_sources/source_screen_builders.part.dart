// source_screen.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// extension _SourceBuilders 承载：工具栏/批量栏/列表/源项构建。
// 同 library 内可访问 State 私有字段；生命周期（initState/dispose/build）留在主类。
part of 'source_screen.dart';

// ConsumerState.ref 为 protected 成员，extension 分区无法继承其访问域；
// 本文件所有方法均运行于 State 自身（this），受保护访问语义安全。
// ignore_for_file: invalid_use_of_protected_member

extension _SourceBuilders on _SourceScreenState {
  PreferredSizeWidget _buildAppBar(BuildContext context, SourceState state) {
    return DynamicSearchAppBar(
      leading: state.batchMode
          ? IconButton(
              icon: const Icon(Symbols.close_rounded),
              tooltip: context.l10n.sourceExitSelection,
              onPressed: () =>
                  ref.read(sourceNotifierProvider.notifier).exitBatchMode(),
            )
          : null,
      title: context.l10n.sourceManagement,
      searchController: _searchCtrl,
      searchHint: context.l10n.searchBookSources,
      expanded: _searchExpanded,
      onExpandedChanged: (value) => setState(() => _searchExpanded = value),
      onChanged: (v) => ref.read(sourceNotifierProvider.notifier).setFilter(v),
      onClear: () => ref.read(sourceNotifierProvider.notifier).clearFilter(),
      actions: [
        // 安卓原版 book_source.xml：排序按钮常驻顶栏（action_sort）
        AppMenuButton<String>(
          icon: const Icon(Symbols.sort_rounded),
          tooltip: context.l10n.sourceSort,
          // 菜单在顶栏下方展开，不覆盖顶栏
          onSelected: (value) => _handleSortAction(context, value),
          itemBuilder: (_) => _buildSortMenuItems(context),
        ),
        // 安卓原版：分组按钮常驻顶栏（menu_group 子菜单）
        SourceGroupMenuButton(
          onSelected: (value) => _handleGroupAction(context, value),
          selectedValue: state.selectedGroup,
          filters: [
            (value: SourceSpecialGroup.enabled, label: context.l10n.enabled),
            (value: SourceSpecialGroup.disabled, label: context.l10n.disabled),
            (
              value: SourceSpecialGroup.login,
              label: context.l10n.loginRequired,
            ),
            (value: '未分组', label: context.l10n.ungrouped),
            (
              value: SourceSpecialGroup.exploreOn,
              label: context.l10n.sourceDiscoveryEnabled,
            ),
            (
              value: SourceSpecialGroup.exploreOff,
              label: context.l10n.sourceDiscoveryDisabled,
            ),
            for (final group in state.groups.where((g) => g != '未分组'))
              (value: group, label: group),
          ],
        ),
        AppMenuButton<String>(
          // 原版无 tooltip 时系统默认提示 Show menu（长按被误读为
          // "shou menu"），此处显式指定中文提示
          tooltip: context.l10n.moreOptions,
          // 菜单在顶栏下方展开，不覆盖顶栏（默认 over 会盖住搜索栏）
          onSelected: (value) => _handleAction(context, value),
          itemBuilder: (_) => [
            // 对标原版 book_source.xml 溢出菜单（JS 书源编辑器未移植前隐藏入口，避免假菜单）
            AppMenuItem(
              value: 'new',
              child: _MenuRow(
                icon: Symbols.add_rounded,
                label: context.l10n.newBookSource,
              ),
            ),
            const AppMenuItem(
              value: 'new_js',
              child: _MenuRow(icon: Symbols.code_rounded, label: '新建 JS 书源'),
            ),
            AppMenuItem(
              value: 'import_file',
              child: _MenuRow(
                icon: Symbols.download_rounded,
                label: context.l10n.importLocal,
              ),
            ),
            AppMenuItem(
              value: 'import_url',
              child: _MenuRow(
                icon: Symbols.cloud_download_rounded,
                label: context.l10n.importOnline,
              ),
            ),
            AppMenuItem(
              value: 'import_qr',
              child: _MenuRow(
                icon: Symbols.qr_code_rounded,
                label: context.l10n.importQrCode,
              ),
            ),
            AppMenuItem(
              value: 'select_mode',
              child: _MenuRow(
                icon: Symbols.checklist_rounded,
                label: state.batchMode
                    ? context.l10n.sourceExitSelection
                    : context.l10n.selectionMode,
              ),
            ),
            AppMenuItem(
              value: 'group_by_domain',
              child: _MenuRow(
                icon: Symbols.domain_rounded,
                label: _groupByDomain
                    ? '${context.l10n.sourceGroupSourcesByDomain} ✓'
                    : context.l10n.sourceGroupSourcesByDomain,
              ),
            ),
            AppMenuItem(
              value: 'help',
              child: _MenuRow(
                icon: Symbols.help_rounded,
                label: context.l10n.help,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 两种源管理复用同一多选操作栏，页面只提供各自的操作。
  Widget _buildBatchBottomBar(BuildContext context, SourceState state) {
    final notifier = ref.read(sourceNotifierProvider.notifier);
    return SourceSelectionBar(
      selectedCount: state.selectedCount,
      totalCount: state.filteredSources.length,
      allSelected: state.isAllSelected,
      onToggleAll: () {
        if (state.isAllSelected) {
          notifier.deselectAll();
        } else {
          notifier.selectAll();
        }
      },
      onInvert: notifier.revertSelection,
      onDelete: () => _handleBatchAction(context, 'delete'),
      onMenuSelected: (value) => _handleBatchAction(context, value),
      menuItems: [
        // 对标原版 book_source_sel.xml 12 项选择操作
        AppMenuItem(
          value: 'enable',
          child: Text(context.l10n.sourceEnableSelection),
        ),
        AppMenuItem(
          value: 'disable',
          child: Text(context.l10n.sourceDisableSelection),
        ),
        AppMenuItem(value: 'add_group', child: Text(context.l10n.addGroup)),
        AppMenuItem(
          value: 'remove_group',
          child: Text(context.l10n.removeGroup),
        ),
        AppMenuItem(
          value: 'enable_explore',
          child: Text(context.l10n.sourceEnableExplore),
        ),
        AppMenuItem(
          value: 'disable_explore',
          child: Text(context.l10n.sourceDisableExplore),
        ),
        AppMenuItem(
          value: 'top',
          child: Text(context.l10n.sourceSelectionToTop),
        ),
        AppMenuItem(
          value: 'bottom',
          child: Text(context.l10n.sourceSelectionToBottom),
        ),
        AppMenuItem(
          value: 'export',
          child: Text(context.l10n.sourceExportSelection),
        ),
        AppMenuItem(
          value: 'share',
          child: Text(context.l10n.sourceShareSelectedSource),
        ),
        AppMenuItem(
          value: 'check',
          child: Text(context.l10n.sourceCheckSelectSource),
        ),
        AppMenuItem(
          value: 'select_range',
          child: Text(context.l10n.sourceCheckSelectedInterval),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final state = ref.watch(sourceNotifierProvider);

    if (state.loading && state.sources.isEmpty) {
      return const LoadingIndicator(message: '加载书源...');
    }

    if (state.error != null && state.sources.isEmpty) {
      return ErrorView(
        message: state.error!,
        onRetry: () => ref.read(sourceNotifierProvider.notifier).loadSources(),
      );
    }

    // 原版仅单一列表；分组/启用状态筛选均在顶栏分组菜单（无 Tab/Chip 行）
    // 校验进行中/结束后顶部展示进度/结果横幅（对标原版 snackbar 持续进度）
    final checkState = ref.watch(checkSourceNotifierProvider);
    final showCheckBanner =
        checkState.checking || (checkState.hasSession && !_checkToastShown);
    final previousChecking = _checkingForToast;
    _checkingForToast = checkState.checking;
    if (previousChecking && !checkState.checking && checkState.hasSession) {
      _checkToastShown = true;
      final invalid = checkState.invalidCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              checkState.cancelled
                  ? '已取消校验（完成 $invalid 个失效）'
                  : (invalid > 0
                        ? '校验完成：$invalid 个失效源已归入「失效」分组'
                        : '校验完成：全部书源可用'),
            ),
          ),
        );
      });
    }

    return Column(
      children: [
        if (showCheckBanner) _buildCheckBanner(checkState),
        Expanded(
          child: _buildSourceList(
            context,
            _displaySources(state.filteredSources),
          ),
        ),
      ],
    );
  }

  /// 展示用列表：开启域名分组时按二级域名排序（对标 upBookSource）
  List<BookSource> _displaySources(List<BookSource> sources) {
    if (!_groupByDomain) return sources;
    final list = List<BookSource>.of(sources);
    list.sort((a, b) {
      final ha = _sourceHost(a.bookSourceUrl);
      final hb = _sourceHost(b.bookSourceUrl);
      final aHash = ha == '#' ? 1 : 0;
      final bHash = hb == '#' ? 1 : 0;
      final byHash = aHash.compareTo(bHash);
      if (byHash != 0) return byHash;
      final byHost = ha.compareTo(hb);
      if (byHost != 0) return byHost;
      return b.lastUpdateTime.compareTo(a.lastUpdateTime);
    });
    return list;
  }

  /// 从书源 URL 取二级域名（对标 NetworkUtils.getSubDomainOrNull，失败为 `#`）
  String _sourceHost(String origin) {
    final trimmed = origin.trim();
    if (trimmed.isEmpty) return '#';
    try {
      final uri = Uri.parse(
        trimmed.contains('://') ? trimmed : 'http://$trimmed',
      );
      final host = uri.host;
      if (host.isEmpty) return '#';
      final parts = host.split('.').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        return parts.sublist(parts.length - 2).join('.');
      }
      return host;
    } catch (_) {
      return '#';
    }
  }

  /// 校验进度/结果横幅（对标原版持续 Snackbar：进度 n/total + 当前源名）
  Widget _buildCheckBanner(CheckSourceState checkState) {
    final colorScheme = Theme.of(context).colorScheme;
    final checking = checkState.checking;
    return Material(
      color: checking
          ? colorScheme.primary.withValues(alpha: 0.08)
          : colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (checking)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (checking) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  checking
                      ? '校验中 ${checkState.done}/${checkState.total}：'
                            '${checkState.currentName}'
                      : '校验结束：${checkState.done}/${checkState.total}'
                            '，失效 ${checkState.invalidCount} 个',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                ),
              ),
              if (checking)
                TextButton(
                  onPressed: () =>
                      ref.read(checkSourceNotifierProvider.notifier).cancel(),
                  child: Text(context.l10n.cancel),
                )
              else
                IconButton(
                  icon: const Icon(Symbols.close_rounded, size: 18),
                  tooltip: '关闭校验结果',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _checkToastShown = false);
                    ref
                        .read(checkSourceNotifierProvider.notifier)
                        .clearMessages();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceList(BuildContext context, List<BookSource> sources) {
    if (sources.isEmpty) {
      return const EmptyState(
        icon: Symbols.library_books_rounded,
        title: '暂无书源',
        subtitle: '点击右上角菜单「新建书源」新建，或导入书源',
      );
    }

    final state = ref.watch(sourceNotifierProvider);

    // 域名分组：插入域名头行（对标 adapter.isItemHeader / getHeaderText）
    if (_groupByDomain) {
      final rows = <_SourceListRow>[];
      String? lastHost;
      for (final source in sources) {
        final host = _sourceHost(source.bookSourceUrl);
        if (host != lastHost) {
          rows.add(_SourceListRow.header(host));
          lastHost = host;
        }
        rows.add(_SourceListRow.item(source));
      }
      // [快速滚动条] 千级书源列表右侧拖拽定位（对齐原版 FastScroller）
      return AppScrollBody(
        controller: _listController,
        builder: (context, scrollController) => Md3FastScroller(
          controller: scrollController,
          child: ListView.builder(
            controller: scrollController,
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              if (row.isHeader) {
                return _buildDomainHeader(context, row.header!);
              }
              final source = row.source!;
              return _buildSourceItem(context, source, state);
            },
          ),
        ),
      );
    }

    if (state.sort == SourceSort.manual && !state.batchMode) {
      return AppScrollBody(
        controller: _listController,
        builder: (context, scrollController) => Md3FastScroller(
          controller: scrollController,
          child: ReorderableListView.builder(
            scrollController: scrollController,
            buildDefaultDragHandles: false,
            proxyDecorator: ManagementListCard.dragProxy,
            itemCount: sources.length,
            onReorderItem: (oldIndex, newIndex) async {
              final saved = await ref
                  .read(sourceNotifierProvider.notifier)
                  .reorderSources(oldIndex, newIndex);
              if (!mounted || saved) return;
              final error = ref.read(sourceNotifierProvider).error;
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('保存排序失败：$error')));
              }
            },
            itemBuilder: (context, index) => KeyedSubtree(
              key: ValueKey(sources[index].bookSourceUrl),
              child: _buildSourceItem(
                context,
                sources[index],
                state,
                dragIndex: index,
              ),
            ),
          ),
        ),
      );
    }

    return AppScrollBody(
      controller: _listController,
      builder: (context, scrollController) => Md3FastScroller(
        controller: scrollController,
        child: ListView.builder(
          controller: scrollController,
          itemCount: sources.length,
          itemBuilder: (context, index) {
            final source = sources[index];
            return _buildSourceItem(context, source, state);
          },
        ),
      ),
    );
  }

  /// 域名分组头（轻量列表分组，对齐原版 sticky 域名条信息架构）
  Widget _buildDomainHeader(BuildContext context, String host) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Text(
        host,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// 名称和分组共用可用宽度，从名称开头显示，超长时省略尾部。
  Widget _buildSourceName(BuildContext context, BookSource source) {
    final theme = Theme.of(context);
    final group = (source.bookSourceGroup ?? '').trim();
    return Text.rich(
      TextSpan(
        text: source.bookSourceName,
        children: [
          if (group.isNotEmpty)
            TextSpan(
              text: ' ($group)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  /// 点击卡片编辑，手柄拖动排序，长按进入批量选择。— Codex + UI
  Widget _buildSourceItem(
    BuildContext context,
    BookSource source,
    SourceState state, {
    int? dragIndex,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasExplore =
        source.exploreUrl != null && source.exploreUrl!.isNotEmpty;
    // 校验结果消息（对标原版列表项 checkSourceMessage：绿=通过，红=失效）
    final checkMessage = ref
        .watch(checkSourceNotifierProvider)
        .messages[source.bookSourceUrl];
    return AbsorbPointer(
      absorbing: state.loading,
      child: ManagementListCard(
        dragIndex: dragIndex,
        batchMode: state.batchMode,
        selected: state.isSelected(source.bookSourceUrl),
        isEnabled: source.enabled,
        onEnabledChanged: (_) => ref
            .read(sourceNotifierProvider.notifier)
            .toggleSource(source.bookSourceUrl),
        onEdit: () =>
            Navigator.of(context)
                .push(sourceEditRoute(sourceUrl: source.bookSourceUrl)),
        onSelect: () => ref
            .read(sourceNotifierProvider.notifier)
            .toggleSelection(source.bookSourceUrl),
        onLongPress: () => ref
            .read(sourceNotifierProvider.notifier)
            .toggleSelection(source.bookSourceUrl),
        information: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSourceName(context, source),
            if (checkMessage != null)
              Text(
                checkMessage.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: checkMessage.ok
                      ? colorScheme.primary
                      : colorScheme.error,
                ),
              ),
          ],
        ),
        menu: Stack(
          children: [
            IconButton(
              icon: const Icon(Symbols.more_vert_rounded, size: 20),
              tooltip: context.l10n.sourceMoreMenu,
              onPressed: () => _showSourceMenu(context, source),
            ),
            if (hasExplore)
              Positioned(
                top: 6,
                right: 6,
                child: Semantics(
                  label: source.enabledExplore
                      ? context.l10n.sourceTagExploreEnabled
                      : '标志:发现未启用',
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: source.enabledExplore
                          ? colorScheme.primary
                          : colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 书源更多按钮菜单（对标原版 BookSourceAdapter.showMenu）：
  /// 置顶/置底（仅手动排序）、登录（有 loginUrl）、搜索、调试、删除、
  /// 启用|禁用发现（有 exploreUrl，按 enabledExplore 切换文案）
  Future<void> _showSourceMenu(BuildContext context, BookSource source) async {
    final state = ref.read(sourceNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final manualSort = state.sort == SourceSort.manual;
    final hasLoginUrl = (source.loginUrl ?? '').trim().isNotEmpty;
    final hasExplore = (source.exploreUrl ?? '').trim().isNotEmpty;

    // [统一壳 B2a] 自造壳（SheetDragHandle+滚动列）迁移统一 AppBottomSheet
    // （对齐参考版 AppModalBottomSheet 语义；把手由主题统一提供），
    // 标题=书源名（操作对象语义）
    final action = await AppBottomSheet.show<String>(
      context: context,
      title: source.bookSourceName,
      children: [
        ListTile(
          leading: const Icon(Symbols.vertical_align_top_rounded),
          title: Text(context.l10n.pinToTop),
          enabled: manualSort,
          onTap: () => Navigator.pop(context, 'top'),
        ),
        ListTile(
          leading: const Icon(Symbols.vertical_align_bottom_rounded),
          title: Text(context.l10n.moveToBottom),
          enabled: manualSort,
          onTap: () => Navigator.pop(context, 'bottom'),
        ),
        if (hasLoginUrl)
          ListTile(
            leading: const Icon(Symbols.person_rounded),
            title: Text(context.l10n.login),
            onTap: () => Navigator.pop(context, 'login'),
          ),
        ListTile(
          leading: const Icon(Symbols.search_rounded),
          title: Text(context.l10n.search),
          onTap: () => Navigator.pop(context, 'search'),
        ),
        ListTile(
          leading: const Icon(Symbols.bug_report_rounded),
          title: Text(context.l10n.debugAction),
          onTap: () => Navigator.pop(context, 'debug'),
        ),
        ListTile(
          leading: Icon(Symbols.delete_rounded, color: colorScheme.error),
          title: Text(
            context.l10n.delete,
            style: TextStyle(color: colorScheme.error),
          ),
          onTap: () => Navigator.pop(context, 'delete'),
        ),
        if (hasExplore)
          ListTile(
            leading: Icon(
              source.enabledExplore
                  ? Symbols.explore_off_rounded
                  : Symbols.explore_rounded,
            ),
            title: Text(
              source.enabledExplore
                  ? context.l10n.sourceDisableExplore
                  : context.l10n.sourceEnableExplore,
            ),
            onTap: () => Navigator.pop(context, 'toggle_explore'),
          ),
      ],
    );

    if (action == null || !context.mounted) return;

    final notifier = ref.read(sourceNotifierProvider.notifier);
    switch (action) {
      case 'top':
        await notifier.moveSource(source.bookSourceUrl, toTop: true);
      case 'bottom':
        await notifier.moveSource(source.bookSourceUrl, toTop: false);
      case 'login':
        SourceLoginScreen.open(
          context,
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
          loginUrl: source.loginUrl,
        );
      case 'search':
        // 对标原版 BookSourceActivity → SearchActivity.start(this, bookSource)
        final search = ref.read(searchNotifierProvider.notifier);
        search.clearAllFilter();
        search.toggleSource(source.bookSourceUrl);
        GoRouter.of(context).pushAppRoute(AppRoutes.search);
      case 'debug':
        GoRouter.of(context)
            .pushAppRoute(AppRoutes.sourceDebug, extra: source.bookSourceUrl);
      case 'delete':
        final confirmed = await showConfirmDialog(
          context,
          title: '删除书源',
          content: '确定要删除书源「${source.bookSourceName}」吗？',
          confirmText: context.l10n.delete,
          isDestructive: true,
        );
        if (confirmed && context.mounted) {
          notifier.deleteSource(source.bookSourceUrl);
        }
      case 'toggle_explore':
        await notifier.toggleExplore(source.bookSourceUrl);
    }
  }

  /// 书源管理帮助页（对标原版 showHelp("SourceMBookHelp")）
}
