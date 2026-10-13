import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_read_record_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  const repository = RustReadRecordRepository();
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

  test('写入只传累计毫秒和书名，沿用 Rust 的时间与设备规则', () async {
    when(
      () => bridge.crateFfiFfiReadRecordUpsert(bookName: '测试', readTime: 4999),
    ).thenAnswer((_) async => 4999);
    await repository.putReadRecord(
      const ReadRecord(
        bookName: '测试',
        readTime: 4999,
        lastRead: -1,
        deviceId: '不注入',
      ),
    );
    verify(
      () => bridge.crateFfiFfiReadRecordUpsert(bookName: '测试', readTime: 4999),
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
    when(() => bridge.crateFfiFfiReadRecordUpsert(bookName: '测试', readTime: 1))
        .thenAnswer((_) async => throw failure);
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
}
