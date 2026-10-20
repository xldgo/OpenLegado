import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/domain/models/search_batch.dart';
import 'package:flutter_legado/src/domain/services/search_session.dart';

import '../mocks/mocks.dart';

void main() {
  test('关闭幂等，原生取消先于订阅解绑', () async {
    final service = SearchServiceMock();
    final events = StreamController<SearchBatch>();
    final calls = <String>[];
    final gate = Completer<void>();
    events.onCancel = () {
      calls.add('解绑');
    };
    when(() => service.searchMultiStream('甲', sourceUrls: null, page: 1))
        .thenAnswer((_) => events.stream);
    when(() => service.cancelSearch()).thenAnswer((_) {
      calls.add('取消');
      return gate.future;
    });
    final session = SearchSession(service);
    session.start(
      keyword: '甲',
      page: 1,
      sourceUrls: null,
      onBatch: (_) {},
      onError: (_) {},
      onDone: () {},
    );
    final close = session.close();
    expect(session.close(), same(close));
    expect(calls, ['取消']);
    gate.complete();
    await close;
    expect(calls, ['取消', '解绑']);
    await events.close();
  });

  test('关闭未启动会话不发送原生取消，关闭后不能启动', () async {
    final service = SearchServiceMock();
    final session = SearchSession(service);
    await session.close();
    verifyNever(() => service.cancelSearch());
    expect(
      () => session.start(
        keyword: '甲',
        page: 1,
        sourceUrls: null,
        onBatch: (_) {},
        onError: (_) {},
        onDone: () {},
      ),
      throwsStateError,
    );
  });

  test('自然结束不发送取消，下一页沿用实例并透传参数', () async {
    final service = SearchServiceMock();
    when(
      () => service.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) => const Stream<SearchBatch>.empty());
    final session = SearchSession(service);
    for (final page in [1, 2]) {
      final done = Completer<void>();
      session.start(
        keyword: '甲',
        page: page,
        sourceUrls: ['源'],
        onBatch: (_) {},
        onError: (_) {},
        onDone: done.complete,
      );
      await done.future;
    }
    verify(() => service.searchMultiStream('甲', sourceUrls: ['源'], page: 2))
        .called(1);
    await session.close();
    verifyNever(() => service.cancelSearch());
  });

  test('关闭后的数据、异常和结束回调都不转发', () async {
    final service = SearchServiceMock();
    final events = StreamController<SearchBatch>();
    final cancel = Completer<void>();
    when(() => service.searchMultiStream('甲', sourceUrls: null, page: 1))
        .thenAnswer((_) => events.stream);
    when(() => service.cancelSearch()).thenAnswer((_) => cancel.future);
    var callbacks = 0;
    final session = SearchSession(service);
    session.start(
      keyword: '甲',
      page: 1,
      sourceUrls: null,
      onBatch: (_) {
        callbacks++;
      },
      onError: (_) {
        callbacks++;
      },
      onDone: () {
        callbacks++;
      },
    );
    final close = session.close();
    events.add(SearchBatch());
    events.addError(StateError('迟到'));
    await Future<void>.delayed(Duration.zero);
    expect(callbacks, 0);
    cancel.complete();
    await close;
    await events.close();
    expect(callbacks, 0);
  });

  test('原生取消失败仍解绑，关闭调用收到原错误', () async {
    final service = SearchServiceMock();
    final events = StreamController<SearchBatch>();
    var detached = false;
    events.onCancel = () {
      detached = true;
    };
    when(() => service.searchMultiStream('甲', sourceUrls: null, page: 1))
        .thenAnswer((_) => events.stream);
    final error = StateError('取消失败');
    when(() => service.cancelSearch()).thenThrow(error);
    final session = SearchSession(service);
    session.start(
      keyword: '甲',
      page: 1,
      sourceUrls: null,
      onBatch: (_) {},
      onError: (_) {},
      onDone: () {},
    );
    await expectLater(session.close(), throwsA(same(error)));
    expect(detached, isTrue);
    await events.close();
  });
}
