import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/data/repositories/mock_app_log_repository.dart';
import 'package:flutter_legado/src/domain/models/app_log_entry.dart';
import 'package:flutter_legado/src/features/logs/application/app_log_notifier.dart';
import 'package:flutter_legado/src/providers/app_log_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  test('同一装配共享缓冲，返回列表可修改而不影响仓储，分级清空互不影响', () async {
    final api = MockBookApi();
    final repository = api.appLogRepository;
    await repository.appLogPush(level: 'message', message: '消息');
    await repository.appLogPush(level: 'http', message: '网络');
    final list = await api.appLogRepository.appLogList(level: 'message');
    expect(list.single.message, '消息');
    list.clear();
    expect(await repository.appLogList(level: 'message'), hasLength(1));
    await repository.appLogClear(level: 'message');
    expect(await repository.appLogList(level: 'message'), isEmpty);
    expect((await repository.appLogList(level: 'http')).single.message, '网络');
    await repository.appLogClearAll();
    expect(await repository.appLogList(level: 'http'), isEmpty);
  });

  test('Mock每级最多500条且新消息在前，空消息不占容量', () async {
    final repository = MockAppLogRepository();
    for (var index = 0; index < 505; index++) {
      await repository.appLogPush(level: 'message', message: '条目$index');
    }
    await repository.appLogPush(level: 'message', message: '');
    await repository.appLogPush(level: 'crash', message: '崩溃');
    final list = await repository.appLogList(level: 'message');
    expect(list, hasLength(500));
    expect(list.first.message, '条目504');
    expect(list.last.message, '条目5');
    expect(await repository.appLogList(level: 'crash'), hasLength(1));
  });

  test('Mock导出保留既有格式并限制64000字符', () async {
    final repository = MockAppLogRepository();
    await repository.appLogPush(level: 'http', message: '原消息');
    expect(await repository.appLogExport(), contains('[http] 原消息\n'));
    await repository.appLogPush(level: 'message', message: '字' * 65000);
    expect((await repository.appLogExport()).length, 64000);
  });

  test('时间文本保持本地HH:mm:ss.SSS格式', () {
    final time = DateTime(2026, 10, 16, 12, 34, 56, 7).millisecondsSinceEpoch;
    final entry = AppLogEntry(timestamp: time, level: 'message', message: 'm');
    expect(entry.timeText, '12:34:56.007');
  });

  test('仓储支持注入并跟随窄依赖替换', () async {
    final repository = MockAppLogRepository();
    final first = MockBookApi(appLogRepository: repository);
    final second = MockBookApi();
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        appLogRepositoryProvider.overrideWithValue(first.appLogRepository),
      ]),
    );
    addTearDown(container.dispose);
    expect(container.read(appLogRepositoryProvider), same(repository));
    await repository.appLogPush(level: 'message', message: '独立数据');
    container.updateOverrides(
      mergeTestOverrides([
        appLogRepositoryProvider.overrideWithValue(second.appLogRepository),
      ]),
    );
    await container.pump();
    expect(
      container.read(appLogRepositoryProvider),
      same(second.appLogRepository),
    );
    expect(
      await container
          .read(appLogRepositoryProvider)
          .appLogList(level: 'message'),
      isEmpty,
    );
  });

  group('Notifier独立仓储', () {
    late AppLogRepositoryMock repository;
    late ProviderContainer container;
    late AppLogNotifier notifier;
    const entry = AppLogEntry(timestamp: 1, level: 'message', message: '保留消息');
    AppLogState state() => container.read(appLogNotifierProvider);
    setUp(() {
      repository = AppLogRepositoryMock();
      when(() => repository.appLogList(level: 'message'))
          .thenAnswer((_) async => [entry]);
      container = ProviderContainer(
        overrides: [appLogRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      notifier = container.read(appLogNotifierProvider.notifier);
    });

    test('分级加载与重试，失败不混入其他级别日志', () async {
      await notifier.load('message');
      expect(state().logs, [entry]);
      when(() => repository.appLogList(level: 'http'))
          .thenThrow(StateError('读取失败'));
      await notifier.load('http');
      expect(state().currentLevel, 'http');
      expect(state().logs, isEmpty);
      expect(state().error, contains('读取失败'));
      when(() => repository.appLogList(level: 'http'))
          .thenAnswer((_) async => []);
      await notifier.load('http');
      expect(state().error, isNull);
    });

    test('当前级别清空后刷新当前级别，全部清空保留选中级别', () async {
      when(() => repository.appLogList(level: 'http'))
          .thenAnswer((_) async => []);
      when(() => repository.appLogClear(level: 'http'))
          .thenAnswer((_) async {});
      when(() => repository.appLogClearAll()).thenAnswer((_) async {});
      await notifier.load('http');
      expect(await notifier.clearCurrentLevel(), isTrue);
      expect(await notifier.clearAll(), isTrue);
      expect(state().currentLevel, 'http');
      verify(() => repository.appLogClear(level: 'http')).called(1);
      verify(() => repository.appLogClearAll()).called(1);
      verify(() => repository.appLogList(level: 'http')).called(3);
    });

    for (final all in [true, false]) {
      test('清空all=$all异常保留条目、返回失败且不刷新', () async {
        await notifier.load('message');
        clearInteractions(repository);
        when(() => repository.appLogClear(level: 'message'))
            .thenThrow(StateError('清空失败'));
        when(() => repository.appLogClearAll()).thenThrow(StateError('清空失败'));
        expect(
          await (all ? notifier.clearAll() : notifier.clearCurrentLevel()),
          isFalse,
        );
        expect(state().logs, [entry]);
        expect(state().error, contains('清空失败'));
        verifyNever(() => repository.appLogList(level: 'message'));
      });
    }

    test('导出原样返回，异常不伪造空文本', () async {
      when(() => repository.appLogExport()).thenAnswer((_) async => '原格式\n');
      expect(await notifier.export(), '原格式\n');
      final error = StateError('导出失败');
      when(() => repository.appLogExport()).thenThrow(error);
      await expectLater(() => notifier.export(), throwsA(same(error)));
    });
  });
}
