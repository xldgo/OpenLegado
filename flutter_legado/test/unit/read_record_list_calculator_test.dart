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
}
