import '../../models/source_match.dart';

/// 一批已排序的完整候选快照，不能作为增量追加。— Codex + Bridge
final class SourceSwitchBatch {
  SourceSwitchBatch({
    this.sourceIndex = 0,
    this.sourceUrl = '',
    this.sourceName = '',
    this.error,
    this.finishedCount = 0,
    this.totalCount = 0,
    this.isLast = false,
    List<SourceMatch> matches = const [],
  }) : matches = List.unmodifiable(matches);
  final int sourceIndex;
  final String sourceUrl;
  final String sourceName;
  final String? error;
  final int finishedCount;
  final int totalCount;
  final bool isLast;
  final List<SourceMatch> matches;
}
