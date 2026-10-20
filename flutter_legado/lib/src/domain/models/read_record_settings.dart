/// 展示方式与排序继续使用原枚举值。
enum ReadRecordDisplayMode { aggregate, timeline, latest }

enum ReadRecordSortMode { name, readTime, lastRead }

/// ReadRecordSettings 普通偏好，不包含存储与加载状态。— Codex + UI
final class ReadRecordSettings {
  const ReadRecordSettings({
    this.enableRecord = true,
    this.sortMode = ReadRecordSortMode.name,
    this.displayMode = ReadRecordDisplayMode.aggregate,
  });
  final bool enableRecord;
  final ReadRecordSortMode sortMode;
  final ReadRecordDisplayMode displayMode;

  ReadRecordSettings copyWith({
    bool? enableRecord,
    ReadRecordSortMode? sortMode,
    ReadRecordDisplayMode? displayMode,
  }) => ReadRecordSettings(
    enableRecord: enableRecord ?? this.enableRecord,
    sortMode: sortMode ?? this.sortMode,
    displayMode: displayMode ?? this.displayMode,
  );

  @override
  bool operator ==(Object other) =>
      other is ReadRecordSettings &&
      enableRecord == other.enableRecord &&
      sortMode == other.sortMode &&
      displayMode == other.displayMode;

  @override
  int get hashCode => Object.hashAll([enableRecord, sortMode, displayMode]);
}
