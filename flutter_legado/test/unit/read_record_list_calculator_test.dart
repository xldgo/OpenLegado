import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/read_records/read_record_state.dart';
import 'package:flutter_legado/src/features/read_records/read_record_list_calculator.dart';

void main() {
  const details = [
    ReadRecordDetail(
      bookName: '同名',
      author: '甲',
      date: '2026-10-13',
      readTime: 1000,
      lastRead: 2,
    ),
    ReadRecordDetail(
      bookName: '同名',
      author: '甲',
      date: '2026-10-13',
      readTime: 2000,
      lastRead: 3,
    ),
    ReadRecordDetail(
      bookName: '同名',
      author: '乙',
      date: '2026-10-13',
      readTime: 4000,
      lastRead: 4,
    ),
    ReadRecordDetail(
      bookName: '早期',
      author: '甲',
      date: '2025-12-31',
      readTime: 5000,
      lastRead: 1,
    ),
  ];
  test('汇总合并同日单书、区分作者，按日期与最后阅读排序', () {
    final rows = ReadRecordListCalculator.build(
      mode: ReadRecordDisplayMode.aggregate,
      records: [],
      details: details,
    );
    expect(rows.length, 3);
    expect(rows[0].author, '乙');
    expect(rows[1].durationMs, 3000);
    final groups = ReadRecordListCalculator.group(rows);
    expect(groups.length, 2);
    expect(groups[0].durationMs, 7000);
    final selected = ReadRecordListCalculator.build(
      mode: ReadRecordDisplayMode.aggregate,
      records: [],
      details: details,
      query: '甲',
    );
    expect(selected.map((r) => r.bookName), ['同名', '早期']);
  });
  test('最后阅读合并跨日期时长，可按作者搜索', () {
    final rows = ReadRecordListCalculator.build(
      mode: ReadRecordDisplayMode.latest,
      records: [],
      details: details,
      query: '乙',
    );
    expect(rows.single.author, '乙');
    expect(rows.single.date, isNull);
  });
  test('时间线按开始日期分组，同书20分钟内合并展示并保留全部ID', () {
    final base = DateTime(2026, 10, 13, 12).millisecondsSinceEpoch;
    final rows = ReadRecordListCalculator.build(
      mode: ReadRecordDisplayMode.timeline,
      records: [],
      details: [],
      sessions: [
        ReadRecordSession(
          id: 1,
          bookName: '甲',
          author: '作者',
          bookUrl: 'u',
          startTime: base,
          endTime: base + 60000,
          chapterIndex: 2,
        ),
        ReadRecordSession(
          id: 2,
          bookName: '甲',
          author: '作者',
          bookUrl: 'u',
          startTime: base + 5 * 60000,
          endTime: base + 6 * 60000,
          chapterIndex: 3,
        ),
        ReadRecordSession(
          id: 3,
          bookName: '甲',
          author: '作者',
          bookUrl: 'u',
          startTime: base + 30 * 60000,
          endTime: base + 31 * 60000,
          chapterIndex: 4,
        ),
      ],
    );
    expect(rows.length, 2);
    expect(rows.first.sessionIds, [3]);
    expect(rows.last.sessionIds, [1, 2]);
    expect(rows.last.startTime, base);
    expect(rows.last.lastRead, base + 6 * 60000);
    expect(rows.last.chapterIndex, 2);
  });
  test('时间线不跨作者或日期合并，无效时段过滤', () {
    final end = DateTime(2026, 10, 14).millisecondsSinceEpoch;
    final rows = ReadRecordListCalculator.build(
      mode: ReadRecordDisplayMode.timeline,
      records: [],
      details: [],
      sessions: [
        ReadRecordSession(
          id: 1,
          bookName: '甲',
          author: '甲',
          startTime: end - 1000,
          endTime: end,
        ),
        ReadRecordSession(
          id: 2,
          bookName: '甲',
          author: '甲',
          startTime: end,
          endTime: end + 1000,
        ),
        ReadRecordSession(
          id: 3,
          bookName: '甲',
          author: '乙',
          startTime: end + 1000,
          endTime: end + 2000,
        ),
        ReadRecordSession(
          id: 4,
          bookName: '甲',
          author: '乙',
          startTime: end + 2000,
          endTime: end + 2000,
        ),
      ],
    );
    expect(rows.length, 3);
    expect(ReadRecordListCalculator.group(rows).length, 2);
  });
}
