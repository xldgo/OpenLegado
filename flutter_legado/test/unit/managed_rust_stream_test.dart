// 订阅独占取消凭据，验证取消和释放次数。— Codex + Bridge
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/ffi.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/bridge/managed_rust_stream.dart';

class _Api extends Mock implements RustLibApi {}

class _Request extends Mock implements StreamRequest {}

void main() {
  late _Api api;
  setUp(() {
    api = _Api();
    RustLib.initMock(api: api);
  });
  tearDown(RustLib.dispose);
  test('晚取消旧流只取消旧凭据，新流继续交付并释放', () async {
    final old = _Request(), current = _Request();
    var count = 0;
    when(() => api.crateFfiStreamRequestNew())
        .thenAnswer((_) => (count++ == 0) ? old : current);
    final a = StreamController<int>(), b = StreamController<int>();
    final first = managedRustStream<int>((request) {
      expect(identical(request, old), true);
      return a.stream;
    }).listen((_) {});
    final events = <int>[];
    final second = managedRustStream<int>((request) {
      expect(identical(request, current), true);
      return b.stream;
    }).listen(events.add);
    await first.cancel();
    b.add(7);
    await b.close();
    await Future<void>.delayed(Duration.zero);
    expect(events, [7]);
    verify(() => old.cancel()).called(1);
    verify(() => old.dispose()).called(1);
    verifyNever(() => current.cancel());
    verify(() => current.dispose()).called(1);
    await second.cancel();
    await a.close();
    verifyNoMoreInteractions(old);
    verifyNoMoreInteractions(current);
  });
  test('同步启动失败仍释放并以流错误通知', () async {
    final request = _Request();
    when(() => api.crateFfiStreamRequestNew()).thenReturn(request);
    await expectLater(
      managedRustStream<int>((_) => throw StateError('启动失败')),
      emitsError(isStateError),
    );
    verify(() => request.dispose()).called(1);
  });
}
