import '../../domain/models/read_record_settings.dart'
    show ReadRecordDisplayMode, ReadRecordSortMode;
export '../../domain/models/read_record_settings.dart'
    show ReadRecordDisplayMode, ReadRecordSortMode;
import '../../models/models.dart';
import '../../domain/models/read_record_settings.dart';

/// 阅读记录页状态（对齐原版 ReadRecordActivity）
class ReadRecordState {
  /// 当前展示列表（已按搜索/排序过滤）
  final List<ReadRecordShow> records;

  /// 全部阅读时长合计（毫秒，对齐原版 allTime）
  final int totalReadTimeMs;

  /// 搜索关键词
  final String searchQuery;

  /// 排序模式
  final ReadRecordSortMode sortMode;
  final ReadRecordDisplayMode displayMode;

  /// 是否启用阅读时长记录（对齐 AppConfig.enableReadRecord）
  final bool enableRecord;

  /// 加载中
  final bool isLoading;

  /// 错误信息
  final String? error;

  const ReadRecordState({
    this.records = const [],
    this.totalReadTimeMs = 0,
    this.searchQuery = '',
    this.sortMode = ReadRecordSortMode.name,
    this.displayMode = ReadRecordDisplayMode.aggregate,
    this.enableRecord = true,
    this.isLoading = false,
    this.error,
  });

  ReadRecordState copyWith({
    List<ReadRecordShow>? records,
    int? totalReadTimeMs,
    String? searchQuery,
    ReadRecordSortMode? sortMode,
    ReadRecordDisplayMode? displayMode,
    bool? enableRecord,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ReadRecordState(
      records: records ?? this.records,
      totalReadTimeMs: totalReadTimeMs ?? this.totalReadTimeMs,
      searchQuery: searchQuery ?? this.searchQuery,
      sortMode: sortMode ?? this.sortMode,
      displayMode: displayMode ?? this.displayMode,
      enableRecord: enableRecord ?? this.enableRecord,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
