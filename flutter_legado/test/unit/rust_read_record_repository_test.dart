import 'package:flutter_legado/src/bridge/transfer_dto.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_read_record_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show Int64List;
import 'package:flutter_legado/src/bridge/statistics_dto.dart' as statistics;
import 'package:flutter_legado/src/domain/models/read_record_statistics.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  final repository = RustReadRecordRepository();
  late _Bridge bridge;

  setUpAll(() => registerFallbackValue(Int64List.fromList([])));

  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('小时查询原样传递本地边界，仅映射秒数并保留错误', () async {
    final boundaries = List.generate(
      25,
      (hour) => 1779235200000 + hour * 3600000,
    );
    final seconds = List.generate(24, (hour) => hour + 1);
    when(
      () => bridge.crateFfiFfiReadRecordHourly(
        boundaries: any(named: 'boundaries'),
      ),
    ).thenAnswer((_) async => Int64List.fromList(seconds));
    expect(await repository.getReadRecordHourly(boundaries), seconds);
    final captured =
        verify(
              () => bridge.crateFfiFfiReadRecordHourly(
                boundaries: captureAny(named: 'boundaries'),
              ),
            ).captured.single
            as Int64List;
    expect(captured.map((value) => value.toInt()).toList(), boundaries);
    final failure = StateError('小时查询失败');
    when(
      () => bridge.crateFfiFfiReadRecordHourly(
        boundaries: any(named: 'boundaries'),
      ),
    ).thenAnswer((_) async => throw failure);
    await expectLater(
      repository.getReadRecordHourly(boundaries),
      throwsA(same(failure)),
    );
  });

  test('周期与日期只传查询参数，统计图与日历投影直接映射，明细查询错误上抛', () async {
    const book = statistics.ReadBookRankingDto(
      bookName: '书',
      author: '作者',
      readTimeMs: 1200,
      coverUrl: '封面',
    );
    when(
      () => bridge.crateFfiFfiReadRecordOverview(
        period: statistics.ReadRecordPeriodDto.month,
        referenceDate: '2026-02-10',
      ),
    ).thenAnswer(
      (_) async => const statistics.ReadRecordStatisticsDto(
        totalTimeMs: 1200,
        readingDays: 1,
        totalBooks: 1,
        readingBooks: 1,
        finishedBooks: 0,
        topBooks: [book],
        days: [
          statistics.ReadDayStatDto(
            date: '2026-02-10',
            seconds: 1,
            bookCount: 1,
            topBook: book,
          ),
        ],
        chart: [statistics.ReadChartPointDto(date: '2026-02-10', seconds: 1)],
      ),
    );
    final result = await repository.getReadRecordOverview(
      ReadPeriod.month,
      DateTime(2026, 2, 10, 15),
    );
    expect(result.totalTimeMs, 1200);
    expect(
      result.topBooks.single,
      const ReadBookRanking(
        bookName: '书',
        author: '作者',
        readTimeMs: 1200,
        coverUrl: '封面',
      ),
    );
    expect(result.allDailyTimes, {'2026-02-10': 1});
    expect(result.dailyTopBook['2026-02-10']?.coverUrl, '封面');
    expect(result.dailyTimeData, [(date: DateTime(2026, 2, 10), seconds: 1)]);
    final failure = StateError('明细查询失败');
    when(() => bridge.crateFfiFfiReadRecordBooksForDay(date: '2026-02-10'))
        .thenAnswer((_) async => throw failure);
    await expectLater(
      repository.getReadRecordBooksForDay(DateTime(2026, 2, 10)),
      throwsA(same(failure)),
    );
  });

  test('时间线只传查询词，保留Rust原始ID和上下文，查询失败上抛', () async {
    when(() => bridge.crateFfiFfiReadRecordTimeline(query: '作者')).thenAnswer(
      (_) async => [
        ReadRecordTimelineDto(
          bookName: '书',
          author: '作者',
          date: '2026-10-13',
          bookUrl: 'u',
          startTime: 1000,
          endTime: 7000,
          chapterIndex: 2,
          sessionIds: Int64List.fromList([9007199254740993, 2]),
        ),
      ],
    );
    final row = (await repository.getReadRecordTimeline('作者')).single;
    expect(
      (row.bookName, row.author, row.date, row.bookUrl, row.chapterIndex),
      ('书', '作者', '2026-10-13', 'u', 2),
    );
    expect(row.sessionIds, [9007199254740993, 2]);
    expect(row.durationMs, 6000);
    final failure = StateError('查询失败');
    when(() => bridge.crateFfiFfiReadRecordTimeline(query: '作者'))
        .thenAnswer((_) async => throw failure);
    await expectLater(
      repository.getReadRecordTimeline('作者'),
      throwsA(same(failure)),
    );
    verify(() => bridge.crateFfiFfiReadRecordTimeline(query: '作者')).called(2);
    verifyNoMoreInteractions(bridge);
  });

  test('类型化记录保留毫秒和原字段，不缓存查询结果', () async {
    when(() => bridge.crateFfiFfiReadRecordList()).thenAnswer(
      (_) async => [
        const ReadRecordDto(
          bookName: '测试',
          author: '',
          readTime: 4999,
          lastRead: 123,
          deviceId: '设备',
        ),
      ],
    );
    expect(await repository.getReadRecords(), [
      const ReadRecord(
        bookName: '测试',
        readTime: 4999,
        lastRead: 123,
        deviceId: '设备',
      ),
    ]);
    when(() => bridge.crateFfiFfiReadRecordList()).thenAnswer((_) async => []);
    expect(await repository.getReadRecords(), isEmpty);
    verify(() => bridge.crateFfiFfiReadRecordList()).called(2);
    verifyNoMoreInteractions(bridge);
  });

  test('写入传递作者和有效时段，设备归属由 Rust 决定', () async {
    when(
      () => bridge.crateFfiFfiReadRecordRecordTime(
        bookName: '测试',
        author: '真实作者',
        readTimeMs: 4999,
        startTimeMs: 1000,
        endTimeMs: 5999,
        bookUrl: '',
        chapterIndex: 0,
      ),
    ).thenAnswer((_) async => 4999);
    await repository.putReadRecord(
      const ReadRecord(
        bookName: '测试',
        author: '真实作者',
        startTime: 1000,
        readTime: 4999,
        lastRead: 5999,
        deviceId: '不注入',
      ),
    );
    verify(
      () => bridge.crateFfiFfiReadRecordRecordTime(
        bookName: '测试',
        author: '真实作者',
        readTimeMs: 4999,
        startTimeMs: 1000,
        endTimeMs: 5999,
        bookUrl: '',
        chapterIndex: 0,
      ),
    ).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('删除与清空沿用原 void 语义，不重写布尔返回值', () async {
    when(() => bridge.crateFfiFfiReadRecordDelete(bookName: '不存在'))
        .thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiReadRecordClear())
        .thenAnswer((_) async => true);
    await repository.deleteReadRecord('不存在');
    await repository.clearReadRecords();
    verify(() => bridge.crateFfiFfiReadRecordDelete(bookName: '不存在')).called(1);
    verify(() => bridge.crateFfiFfiReadRecordClear()).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('每日查询传递年份，保持日期顺序及整秒单位', () async {
    when(() => bridge.crateFfiFfiReadRecordDailyList(year: 2026)).thenAnswer(
      (_) async => [
        const ReadRecordDailyDto(date: '2026-01-01', seconds: 5),
        const ReadRecordDailyDto(date: '2026-01-02', seconds: 8),
      ],
    );
    expect(await repository.readRecordDailyList(2026), [
      {'date': '2026-01-01', 'seconds': 5},
      {'date': '2026-01-02', 'seconds': 8},
    ]);
    verify(() => bridge.crateFfiFfiReadRecordDailyList(year: 2026)).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('五项底层错误原样上抛，不降级为空列表或成功', () async {
    final failure = StateError('数据库读取失败');
    when(() => bridge.crateFfiFfiReadRecordList())
        .thenAnswer((_) async => throw failure);
    when(
      () => bridge.crateFfiFfiReadRecordRecordTime(
        bookName: '测试',
        author: '',
        readTimeMs: 1,
        startTimeMs: null,
        endTimeMs: null,
        bookUrl: '',
        chapterIndex: 0,
      ),
    ).thenAnswer((_) async => throw failure);
    when(() => bridge.crateFfiFfiReadRecordDelete(bookName: '测试'))
        .thenAnswer((_) async => throw failure);
    when(() => bridge.crateFfiFfiReadRecordClear())
        .thenAnswer((_) async => throw failure);
    when(() => bridge.crateFfiFfiReadRecordDailyList(year: 2026))
        .thenAnswer((_) async => throw failure);
    await expectLater(repository.getReadRecords(), throwsA(same(failure)));
    await expectLater(
      repository.putReadRecord(const ReadRecord(bookName: '测试', readTime: 1)),
      throwsA(same(failure)),
    );
    await expectLater(
      repository.deleteReadRecord('测试'),
      throwsA(same(failure)),
    );
    await expectLater(repository.clearReadRecords(), throwsA(same(failure)));
    await expectLater(
      repository.readRecordDailyList(2026),
      throwsA(same(failure)),
    );
  });

  test('按年和全量明细使用 DTO，保留作者与大毫秒数，失败不缓存', () async {
    final details = [
      ReadRecordDetailDto(
        bookName: '同名😀',
        author: '作者',
        date: '2026-01-01',
        readTime: 9007199254740993,
        lastRead: 9223372036854775806,
      ),
    ];
    when(() => bridge.crateFfiFfiReadRecordDetailList(year: 2026))
        .thenAnswer((_) async => details);
    when(() => bridge.crateFfiFfiReadRecordAllDetailList())
        .thenAnswer((_) async => details);
    final yearly = await repository.getReadRecordDetails(2026);
    expect(yearly.single.bookName, '同名😀');
    expect(yearly.single.author, '作者');
    expect(yearly.single.readTime, 9007199254740993);
    expect(yearly.single.lastRead, 9223372036854775806);
    expect(await repository.getAllReadRecordDetails(), yearly);
    final failure = StateError('明细查询失败');
    when(() => bridge.crateFfiFfiReadRecordAllDetailList())
        .thenAnswer((_) async => throw failure);
    await expectLater(
      repository.getAllReadRecordDetails(),
      throwsA(same(failure)),
    );
    when(() => bridge.crateFfiFfiReadRecordDetailList(year: 2027))
        .thenAnswer((_) async => []);
    expect(await repository.getReadRecordDetails(2027), isEmpty);
    when(() => bridge.crateFfiFfiReadRecordDetailList(year: 2026))
        .thenAnswer((_) async => throw failure);
    await expectLater(
      repository.getReadRecordDetails(2026),
      throwsA(same(failure)),
    );
  });

  test('只有成功写入才发送变更通知', () async {
    var events = 0;
    final subscription = repository.changes.listen((_) => events++);
    addTearDown(subscription.cancel);
    when(
      () => bridge.crateFfiFfiReadRecordRecordTime(
        bookName: '通知',
        author: '',
        readTimeMs: 1,
        startTimeMs: null,
        endTimeMs: null,
        bookUrl: '',
        chapterIndex: 0,
      ),
    ).thenAnswer((_) async => 1);
    await repository.putReadRecord(
      const ReadRecord(bookName: '通知', readTime: 1),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events, 1);
    when(() => bridge.crateFfiFfiReadRecordClear())
        .thenAnswer((_) async => throw StateError('写入失败'));
    await expectLater(repository.clearReadRecords(), throwsStateError);
    await Future<void>.delayed(Duration.zero);
    expect(events, 1);
  });

  test('会话快照保持大整数、作者、章节和查询错误，不缓存结果', () async {
    when(() => bridge.crateFfiFfiReadRecordSessionList()).thenAnswer(
      (_) async => [
        const ReadRecordSessionDto(
          id: 9007199254740993,
          deviceId: '设备😀',
          bookName: '同名',
          author: '真实作者',
          bookUrl: 'book://1',
          startTime: 9007199254740993,
          endTime: 9007199254743992,
          chapterIndex: 7,
        ),
      ],
    );
    final session = (await repository.getReadRecordSessions()).single;
    expect(session.id, 9007199254740993);
    expect(session.deviceId, '设备😀');
    expect(session.bookName, '同名');
    expect(session.author, '真实作者');
    expect(session.bookUrl, 'book://1');
    expect(session.startTime, 9007199254740993);
    expect(session.endTime, 9007199254743992);
    expect(session.durationMs, 2999);
    expect(session.chapterIndex, 7);
    when(() => bridge.crateFfiFfiReadRecordSessionList())
        .thenAnswer((_) async => []);
    expect(await repository.getReadRecordSessions(), isEmpty);
    final failure = StateError('会话查询失败');
    when(() => bridge.crateFfiFfiReadRecordSessionList()).thenThrow(failure);
    await expectLater(
      repository.getReadRecordSessions(),
      throwsA(same(failure)),
    );
  });
}
