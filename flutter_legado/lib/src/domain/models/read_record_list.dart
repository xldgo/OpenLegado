/// Rust列表查询的单书投影，不带界面选中或时间线会话状态。— Codex + UI
final class ReadRecordBookEntry {
  const ReadRecordBookEntry({
    required this.bookName,
    required this.author,
    required this.durationMs,
    required this.lastRead,
    this.date,
  });
  final String bookName, author;
  final String? date;
  final int durationMs, lastRead;
}

final class ReadRecordListData {
  const ReadRecordListData({
    this.aggregate = const [],
    this.latest = const [],
    this.totalTimeMs = 0,
  });
  final List<ReadRecordBookEntry> aggregate, latest;
  final int totalTimeMs;
}
