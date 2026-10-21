part of 'search_screen.dart';

/// 搜索范围确认结果；分组与书源互斥，空集合表示全部书源。— Codex + UI
final class _SearchScopeSelection {
  _SearchScopeSelection({
    required Set<String> groups,
    required Set<String> sourceUrls,
  }) : groups = Set.unmodifiable(groups),
       sourceUrls = Set.unmodifiable(sourceUrls);

  final Set<String> groups;
  final Set<String> sourceUrls;
}

/// 对照上游ScopeSelectSheet：本地草稿、统一筛选、两类范围多选。— Codex + UI
class _SearchScopeSheet extends StatefulWidget {
  const _SearchScopeSheet({
    required this.sources,
    required this.initialGroups,
    required this.initialSourceUrls,
  });

  final List<BookSource> sources;
  final Set<String> initialGroups;
  final Set<String> initialSourceUrls;

  @override
  State<_SearchScopeSheet> createState() => _SearchScopeSheetState();
}

class _SearchScopeSheetState extends State<_SearchScopeSheet> {
  late bool _sourceMode;
  late Set<String> _checkedGroups;
  late Set<String> _selectedUrls;
  late final List<String> _groups;
  final _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sourceMode = widget.initialSourceUrls.isNotEmpty;
    _checkedGroups = _sourceMode ? {} : {...widget.initialGroups};
    _selectedUrls = {...widget.initialSourceUrls};
    _groups = {
      for (final source in widget.sources)
        for (final group in (source.bookSourceGroup ?? '').split(
          _splitGroupRegex,
        ))
          if (group.trim().isNotEmpty) group.trim(),
    }.toList();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _selectAll() => setState(() {
    _checkedGroups.clear();
    _selectedUrls.clear();
  });

  void _toggleGroup(String group) => setState(() {
    _selectedUrls.clear();
    if (!_checkedGroups.remove(group)) _checkedGroups.add(group);
  });

  void _toggleSource(String url) => setState(() {
    _checkedGroups.clear();
    if (!_selectedUrls.remove(url)) _selectedUrls.add(url);
  });

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim().toLowerCase();
    final groups = _groups
        .where((group) => group.toLowerCase().contains(query))
        .toList();
    final sources = widget.sources
        .where(
          (source) =>
              source.bookSourceName.toLowerCase().contains(query) ||
              (source.bookSourceGroup ?? '').toLowerCase().contains(query) ||
              source.bookSourceUrl.toLowerCase().contains(query),
        )
        .toList();
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialSourceUrls.isNotEmpty ? 1 : 0,
      child: AppBottomSheet.content(
        title: context.l10n.searchScope,
        scrollable: false,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        trailing: FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _SearchScopeSelection(
              groups: _checkedGroups,
              sourceUrls: _selectedUrls,
            ),
          ),
          child: Text(context.l10n.confirm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSearchRow(
              field: AppSearchField(
                controller: _queryController,
                hintText: context.l10n.filter,
                onChanged: (_) => setState(() {}),
              ),
            ),
            CheckboxListTile(
              title: Text(context.l10n.allBookSources),
              value: _checkedGroups.isEmpty && _selectedUrls.isEmpty,
              onChanged: (_) => _selectAll(),
            ),
            TabBar(
              tabAlignment: TabAlignment.fill,
              onTap: (index) => setState(() => _sourceMode = index == 1),
              tabs: [
                Tab(text: context.l10n.group),
                Tab(text: context.l10n.sources),
              ],
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 480),
                child: _sourceMode
                    ? _sourceList(sources)
                    : _groupList(groups, filtered: query.isNotEmpty),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceList(List<BookSource> sources) {
    if (sources.isEmpty) return _empty(context.l10n.noMatchingBookSources);
    return ListView.builder(
      key: const ValueKey('scope-sources'),
      primary: false,
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: sources.length,
      itemBuilder: (_, index) {
        final source = sources[index];
        final group = source.bookSourceGroup?.trim();
        return CheckboxListTile(
          key: ValueKey(source.bookSourceUrl),
          value: _selectedUrls.contains(source.bookSourceUrl),
          title: Text(source.bookSourceName),
          subtitle: group == null || group.isEmpty ? null : Text(group),
          onChanged: (_) => _toggleSource(source.bookSourceUrl),
        );
      },
    );
  }

  Widget _groupList(List<String> groups, {required bool filtered}) {
    if (groups.isEmpty) {
      return _empty(
        filtered
            ? context.l10n.noMatchingGroups
            : context.l10n.noGroupedBookSources,
      );
    }
    return ListView.builder(
      key: const ValueKey('scope-groups'),
      primary: false,
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: groups.length,
      itemBuilder: (_, index) {
        final group = groups[index];
        return CheckboxListTile(
          value: _checkedGroups.contains(group),
          title: Text(group),
          onChanged: (_) => _toggleGroup(group),
        );
      },
    );
  }

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}
