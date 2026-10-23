/// 三视图统一的展示条目，原始会话ID保留用于准确删除。— Codex + UI
class ReadRecordListEntry {
  final String bookName, author, key;
  final String? date;
  final int durationMs, lastRead, startTime, chapterIndex;
  final String bookUrl;
  final List<int> sessionIds;
  const ReadRecordListEntry({
    required this.bookName,
    required this.author,
    required this.key,
    required this.durationMs,
    required this.lastRead,
    this.date,
    this.startTime = 0,
    this.bookUrl = '',
    this.chapterIndex = 0,
    this.sessionIds = const [],
  });
}

class ReadRecordListCalculator {
  static List<
    ({String date, List<ReadRecordListEntry> entries, int durationMs})
  >
  group(List<ReadRecordListEntry> rows) {
    final groups = <String, List<ReadRecordListEntry>>{};
    for (final row in rows) {
      groups.putIfAbsent(row.date ?? '', () => []).add(row);
    }
    return groups.entries
        .map(
          (g) => (
            date: g.key,
            entries: g.value,
            durationMs: g.value.fold<int>(0, (sum, e) => sum + e.durationMs),
          ),
        )
        .toList();
  }
}
