import '../../models/models.dart';
import 'read_record_state.dart';
import 'read_record_overview_calculator.dart';

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
  ReadRecordListEntry merge(ReadRecordListEntry next) => ReadRecordListEntry(
    bookName: bookName,
    author: author,
    key: key,
    date: date,
    startTime: startTime,
    lastRead: lastRead > next.lastRead ? lastRead : next.lastRead,
    durationMs:
        (lastRead > next.lastRead ? lastRead : next.lastRead) - startTime,
    bookUrl: bookUrl,
    chapterIndex: chapterIndex,
    sessionIds: [...sessionIds, ...next.sessionIds],
  );
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

  static ({List<ReadRecordListEntry> books, int durationMs}) summary({
    required List<ReadRecord> records,
    required List<ReadRecordDetail> details,
    String query = '',
  }) {
    final books = build(
      mode: ReadRecordDisplayMode.latest,
      records: records,
      details: details,
      query: query,
    );
    return (
      books: books,
      durationMs: records.fold<int>(0, (sum, r) => sum + r.readTime),
    );
  }

  static List<ReadRecordListEntry> build({
    required ReadRecordDisplayMode mode,
    required List<ReadRecord> records,
    required List<ReadRecordDetail> details,
    List<ReadRecordSession> sessions = const [],
    String query = '',
  }) {
    final needle = query.trim().toLowerCase();
    bool matches(String name, String author) =>
        needle.isEmpty ||
        name.toLowerCase().contains(needle) ||
        author.toLowerCase().contains(needle);
    if (mode == ReadRecordDisplayMode.timeline) {
      final ordered =
          sessions
              .where((s) => s.durationMs > 0 && matches(s.bookName, s.author))
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
      final merged = <ReadRecordListEntry>[];
      final seen = <Object>{};
      for (final session in ordered) {
        if (!seen.add((
          session.bookName,
          session.author,
          session.bookUrl,
          session.startTime,
          session.endTime,
          session.chapterIndex,
        ))) {
          continue;
        }
        final date = ReadRecordOverviewCalculator.dateKey(
          DateTime.fromMillisecondsSinceEpoch(session.startTime),
        );
        final row = ReadRecordListEntry(
          bookName: session.bookName,
          author: session.author,
          key: 'session:${session.id}',
          date: date,
          durationMs: session.durationMs,
          lastRead: session.endTime,
          startTime: session.startTime,
          bookUrl: session.bookUrl,
          chapterIndex: session.chapterIndex,
          sessionIds: [session.id],
        );
        final last = merged.lastOrNull;
        if (last != null &&
            last.date == date &&
            last.bookName == row.bookName &&
            last.author == row.author &&
            row.startTime - last.lastRead <= 20 * 60 * 1000) {
          merged[merged.length - 1] = last.merge(row);
        } else {
          merged.add(row);
        }
      }
      return merged.reversed.toList();
    }
    final groups = <(String, String, String?), ReadRecordListEntry>{};
    for (final detail in details) {
      if (detail.readTime <= 0 ||
          ReadRecordOverviewCalculator.parseDate(detail.date) == null ||
          !matches(detail.bookName, detail.author)) {
        continue;
      }
      final date = mode == ReadRecordDisplayMode.aggregate ? detail.date : null;
      final key = (detail.bookName, detail.author, date);
      final old = groups[key];
      groups[key] = ReadRecordListEntry(
        bookName: detail.bookName,
        author: detail.author,
        key: 'detail:${key.toString()}',
        date: date,
        durationMs: (old?.durationMs ?? 0) + detail.readTime,
        lastRead: (old?.lastRead ?? 0) > detail.lastRead
            ? old!.lastRead
            : detail.lastRead,
      );
    }
    if (mode == ReadRecordDisplayMode.latest) {
      // 只有累计记录的书仍可展示最后阅读；不据此虚构每日或会话数据。
      final withDetails = details.map((d) => d.bookName).toSet();
      for (final record in records) {
        if (withDetails.contains(record.bookName) ||
            !matches(record.bookName, record.author)) {
          continue;
        }
        final key = (record.bookName, record.author, null);
        final old = groups[key];
        groups[key] = ReadRecordListEntry(
          bookName: record.bookName,
          author: record.author,
          key: 'latest:${key.toString()}',
          durationMs: (old?.durationMs ?? 0) + record.readTime,
          lastRead: (old?.lastRead ?? 0) > record.lastRead
              ? old!.lastRead
              : record.lastRead,
        );
      }
    }
    final rows = groups.values.toList()
      ..sort((a, b) {
        final date = (b.date ?? '').compareTo(a.date ?? '');
        return date != 0 ? date : b.lastRead.compareTo(a.lastRead);
      });
    return rows;
  }
}
