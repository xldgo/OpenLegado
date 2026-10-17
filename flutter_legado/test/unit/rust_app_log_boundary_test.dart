import '../fixtures/business_transport_fixtures.dart';

import 'dart:convert';

import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_app_log_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const repository = RustAppLogRepository();
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('按级别读取返回共享条目，保留原顺序和换行消息', () async {
    when(() => bridge.crateFfiFfiAppLogList(level: 'http')).thenAnswer(
      (_) async => fixtureLogs(
        jsonEncode([
          {'timestamp': 20, 'level': 'http', 'message': '新日志\nGET /'},
          {'timestamp': 10, 'level': 'http', 'message': '旧日志'},
        ]),
      ),
    );
    final list = await repository.appLogList(level: 'http');
    expect(list.map((entry) => entry.timestamp), [20, 10]);
    expect(list.first.level, 'http');
    expect(list.first.message, '新日志\nGET /');
    verify(() => bridge.crateFfiFfiAppLogList(level: 'http')).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('写入与两种清空透传原参数，导出不重排或改写', () async {
    when(
      () => bridge.crateFfiFfiAppLogPush(level: 'message', message: '失败\n来源'),
    ).thenAnswer((_) async {});
    when(() => bridge.crateFfiFfiAppLogClear(level: 'crash'))
        .thenAnswer((_) async {});
    when(() => bridge.crateFfiFfiAppLogClearAll()).thenAnswer((_) async {});
    const exported = '[时间] [HTTP] 原样文本\n';
    when(() => bridge.crateFfiFfiAppLogExport())
        .thenAnswer((_) async => exported);
    await repository.appLogPush(level: 'message', message: '失败\n来源');
    await repository.appLogClear(level: 'crash');
    await repository.appLogClearAll();
    expect(await repository.appLogExport(), exported);
    verify(
      () => bridge.crateFfiFfiAppLogPush(level: 'message', message: '失败\n来源'),
    ).called(1);
    verify(() => bridge.crateFfiFfiAppLogClear(level: 'crash')).called(1);
    verify(() => bridge.crateFfiFfiAppLogClearAll()).called(1);
    verify(() => bridge.crateFfiFfiAppLogExport()).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('合法空数组与空导出不报错', () async {
    when(() => bridge.crateFfiFfiAppLogList(level: 'message'))
        .thenAnswer((_) async => fixtureLogs('[]'));
    when(() => bridge.crateFfiFfiAppLogExport()).thenAnswer((_) async => '');
    expect(await repository.appLogList(level: 'message'), isEmpty);
    expect(await repository.appLogExport(), '');
  });

  test('五项FRB异常原样传递，不伪造成功', () async {
    final error = StateError('日志失败');
    when(() => bridge.crateFfiFfiAppLogPush(level: 'message', message: 'm'))
        .thenThrow(error);
    when(() => bridge.crateFfiFfiAppLogList(level: 'message')).thenThrow(error);
    when(() => bridge.crateFfiFfiAppLogClear(level: 'message'))
        .thenThrow(error);
    when(() => bridge.crateFfiFfiAppLogClearAll()).thenThrow(error);
    when(() => bridge.crateFfiFfiAppLogExport()).thenThrow(error);
    await expectLater(
      () => repository.appLogPush(level: 'message', message: 'm'),
      throwsA(same(error)),
    );
    await expectLater(
      () => repository.appLogList(level: 'message'),
      throwsA(same(error)),
    );
    await expectLater(
      () => repository.appLogClear(level: 'message'),
      throwsA(same(error)),
    );
    await expectLater(() => repository.appLogClearAll(), throwsA(same(error)));
    await expectLater(() => repository.appLogExport(), throwsA(same(error)));
  });
}
