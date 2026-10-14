/// 书架分组展示方式，原枚举值与编码保持。
enum GroupMode { none, bySource, byGroup }

/// BookshelfSettings 普通偏好，不包含存储与加载状态。— Codex + UI
final class BookshelfSettings {
  const BookshelfSettings({
    this.isGridView = false,
    this.gridColumns = 3,
    this.groupMode = GroupMode.none,
    this.selectedGroupIndex = 0,
    this.openBookInfoByClickTitle = false,
    this.deleteBookAlert = true,
  });
  final bool isGridView;
  final int gridColumns;
  final GroupMode groupMode;
  final int selectedGroupIndex;
  final bool openBookInfoByClickTitle;
  final bool deleteBookAlert;

  BookshelfSettings copyWith({
    bool? isGridView,
    int? gridColumns,
    GroupMode? groupMode,
    int? selectedGroupIndex,
    bool? openBookInfoByClickTitle,
    bool? deleteBookAlert,
  }) => BookshelfSettings(
    isGridView: isGridView ?? this.isGridView,
    gridColumns: gridColumns ?? this.gridColumns,
    groupMode: groupMode ?? this.groupMode,
    selectedGroupIndex: selectedGroupIndex ?? this.selectedGroupIndex,
    openBookInfoByClickTitle:
        openBookInfoByClickTitle ?? this.openBookInfoByClickTitle,
    deleteBookAlert: deleteBookAlert ?? this.deleteBookAlert,
  );

  @override
  bool operator ==(Object other) =>
      other is BookshelfSettings &&
      isGridView == other.isGridView &&
      gridColumns == other.gridColumns &&
      groupMode == other.groupMode &&
      selectedGroupIndex == other.selectedGroupIndex &&
      openBookInfoByClickTitle == other.openBookInfoByClickTitle &&
      deleteBookAlert == other.deleteBookAlert;

  @override
  int get hashCode => Object.hashAll([
    isGridView,
    gridColumns,
    groupMode,
    selectedGroupIndex,
    openBookInfoByClickTitle,
    deleteBookAlert,
  ]);
}
