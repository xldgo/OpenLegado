import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/native_test_api.dart';

import '../mocks/mocks.dart';

void main() {
  test('工厂保留 Mock 与真实实现的选择', () {
    expect(createTestApplication(useMock: true), isA<MockBookApi>());
    expect(createTestApplication(useMock: false), isA<NativeTestApi>());
  });

  test('等待初始化完成后注入同一实例，多个消费者共享它', () async {
    final api = MockRustApi();
    final gate = Completer<void>();
    when(() => api.runtime.initialize()).thenAnswer((_) => gate.future);
    var ready = false;
    final initialization = initializeTestApplication(api: api).then((value) {
      ready = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(ready, isFalse);

    gate.complete();
    final initialized = await initialization;
    final container = ProviderContainer(
      overrides: mergeTestOverrides([...initialized.overrides]),
    );
    addTearDown(container.dispose);
    final consumer = Provider((ref) => ref.watch(bookshelfRepositoryProvider));
    expect(initialized, same(api));
    expect(
      container.read(bookshelfRepositoryProvider),
      same(api.bookshelfRepository),
    );
    expect(container.read(consumer), same(api.bookshelfRepository));
    verify(() => api.runtime.initialize()).called(1);
  });

  test('初始化失败原样传播，不返回未就绪实例', () async {
    final api = MockRustApi();
    final failure = StateError('数据库初始化失败');
    when(() => api.runtime.initialize()).thenAnswer((_) async => throw failure);
    await expectLater(
      initializeTestApplication(api: api),
      throwsA(same(failure)),
    );
    verify(() => api.runtime.initialize()).called(1);
  });
}
