/// 搜索普通偏好的不可变投影，编码与默认值只有一个来源。— Codex + UI
final class SearchSettings {
  const SearchSettings({
    this.precisionSearch = false,
    this.resultFilter = '',
    this.scope = '',
    this.searchGroup = '',
    this.showReadRecord = false,
  });

  final bool precisionSearch;
  final String resultFilter;
  final String scope;
  final String searchGroup;
  final bool showReadRecord;

  SearchSettings copyWith({
    bool? precisionSearch,
    String? resultFilter,
    String? scope,
    String? searchGroup,
    bool? showReadRecord,
  }) => SearchSettings(
    precisionSearch: precisionSearch ?? this.precisionSearch,
    resultFilter: resultFilter ?? this.resultFilter,
    scope: scope ?? this.scope,
    searchGroup: searchGroup ?? this.searchGroup,
    showReadRecord: showReadRecord ?? this.showReadRecord,
  );

  @override
  bool operator ==(Object other) =>
      other is SearchSettings &&
      precisionSearch == other.precisionSearch &&
      resultFilter == other.resultFilter &&
      scope == other.scope &&
      searchGroup == other.searchGroup &&
      showReadRecord == other.showReadRecord;

  @override
  int get hashCode => Object.hash(
    precisionSearch,
    resultFilter,
    scope,
    searchGroup,
    showReadRecord,
  );
}
