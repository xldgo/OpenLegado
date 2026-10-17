import 'package:flutter_legado/src/bridge/transfer_dto.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_read_record_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  final repository = RustReadRecordRepository();
  late _Bridge bridge;

  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('保留裸数组、毫秒和原字段，不缓存查询结果', () async {
    when(() => bridge.crateFfiFfiReadRecordList()).thenAnswer(
      (_) async =>
          '[{"bookName":"测试","readTime":4999,"lastRead":123,"deviceId":"设备"}]',
    );
    expect(await repository.getReadRecords(), [
      const ReadRecord(
        bookName: '测试',
        readTime: 4999,
        lastRead: 123,
        deviceId: '设备',
      ),
    ]);
    when(() => bridge.crateFfiFfiReadRecordList())
        .thenAnswer((_) async => '[]');
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

  test('每日查询传递年份，保持日期顺序、秒数及额外字段', () async {
    when(() => bridge.crateFfiFfiReadRecordDailyList(year: 2026)).thenAnswer(
      (_) async => '[{"date":"2026-01-01","seconds":5,"extra":"保留"},{"date":"2026-01-02","seconds":8}]',
    );
    expect(await repository.readRecordDailyList(2026), [
      {'date': '2026-01-01', 'seconds': 5, 'extra': '保留'},
      {'date': '2026-01-02', 'seconds': 8},
    ]);
    verify(() => bridge.crateFfiFfiReadRecordDailyList(year: 2026)).called(1);
    verifyNoMoreInteractions(bridge);
  });

  for (final json in ['{}', '{"data":[]}', 'null', '不是 JSON']) {
    test('查询拒绝非法或包装 JSON：$json', () async {
      when(() => bridge.crateFfiFfiReadRecordList())
          .thenAnswer((_) async => json);
      when(() => bridge.crateFfiFfiReadRecordDailyList(year: 2026))
          .thenAnswer((_) async => json);
      await expectLater(repository.getReadRecords(), throwsFormatException);
      await expectLater(
        repository.readRecordDailyList(2026),
        throwsFormatException,
      );
    });
  }

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
}
