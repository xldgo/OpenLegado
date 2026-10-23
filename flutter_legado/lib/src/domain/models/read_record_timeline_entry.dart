/// Rust归并的只读时间线；展示跨度不作为累计计时。— Codex + UI
final class ReadRecordTimelineEntry {
  const ReadRecordTimelineEntry({
    required this.bookName,
    required this.author,
    required this.date,
    required this.bookUrl,
    required this.startTime,
    required this.endTime,
    required this.chapterIndex,
    required this.sessionIds,
  });

  final String bookName, author, date, bookUrl;
  final int startTime, endTime, chapterIndex;
  final List<int> sessionIds;
  int get durationMs => endTime - startTime;
}
