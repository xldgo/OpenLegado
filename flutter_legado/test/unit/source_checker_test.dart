import 'package:flutter_legado/src/data/bridge/mock_app_runtime.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/data/repositories/mock_book_source_repository.dart';
import 'package:flutter_legado/src/data/services/mock_source_checker.dart';
import 'package:flutter_legado/src/data/services/rust_source_checker.dart';
import 'package:flutter_legado/src/features/book_sources/book_sources.dart';
import 'package:flutter_legado/src/models/book_source.dart';
import 'package:flutter_legado/src/providers/source_check/check_source_notifier.dart';

import '../mocks/mocks.dart';

class _Api extends MockBookApi {
  int initializationCount = 0;
  @override
  MockAppRuntime get runtime => _fixtureRuntime;
  late final _fixtureRuntime = MockAppRuntime(startup: _fixtureInitialize);

  Future<void> _fixtureInitialize() async => initializationCount++;
}

class _PreparingNotifier extends CheckSourceNotifier {
  Future<Map<String, dynamic>>? preparation;
  @override
  Future<Map<String, dynamic>> loadCheckConfig() =>
      preparation ?? super.loadCheckConfig();
}

class _GroupingNotifier extends SourceNotifier {
  final writes = <Set<String>>[];
  @override
  Future<void> addGroupToUrls(Set<String> urls, String group) async {
    expect(group, '失效');
    writes.add(Set.of(urls));
  }
}

/// 模拟已投递到原生回调队列的消息：取消订阅后仍可手动送达旧回调。
class _QueuedStream extends Stream<Map<String, dynamic>> {
  _QueuedStream() {
    controller.onCancel = () {
      cancellations++;
    };
  }
  final controller = StreamController<Map<String, dynamic>>();
  void Function(Map<String, dynamic>)? dataCallback;
  Function? errorCallback;
  void Function()? doneCallback;
  int cancellations = 0;

  @override
  StreamSubscription<Map<String, dynamic>> listen(
    void Function(Map<String, dynamic>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    dataCallback = onData;
    errorCallback = onError;
    doneCallback = onDone;
    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  void emit(Map<String, dynamic> event) => dataCallback!(event);
  void fail(Object error) => Function.apply(errorCallback!, [error]);
  void finish() => doneCallback!();
}

Map<String, dynamic> _event(
  String url, {
  int index = 0,
  int total = 2,
  bool last = false,
  bool search = true,
  bool toc = true,
  bool content = true,
}) => {
  'index': index,
  'total': total,
  'is_last': last,
  'source_name': '名称$url',
  'result': {
    'source_url': url,
    'search_ok': search,
    'toc_ok': toc,
    'content_ok': content,
    'search_error': search ? null : '失败原因',
    'toc_error': toc ? null : '目录原因',
    'content_error': content ? null : '正文原因',
    'total_time_ms': 321,
    'captcha': {'detected': false},
  },
};

const _source = BookSource(bookSourceUrl: 'fixture://a', bookSourceName: '甲');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(<String>[]));

  group('独立校验能力与共享存储', () {
    test('Provider 共用根引用，替换后跟随且不初始化', () {
      final first = _Api();
      final second = _Api();
      final container = ProviderContainer(
        overrides: mergeTestOverrides([
          sourceCheckerProvider.overrideWithValue(first.sourceChecker),
        ]),
      );
      addTearDown(container.dispose);
      expect(container.read(sourceCheckerProvider), same(first.sourceChecker));
      container.updateOverrides(
        mergeTestOverrides([
          sourceCheckerProvider.overrideWithValue(second.sourceChecker),
        ]),
      );
      expect(container.read(sourceCheckerProvider), same(second.sourceChecker));
      expect(first.initializationCount, 0);
      expect(second.initializationCount, 0);
      expect(
        createTestApplication(useMock: true).sourceChecker,
        isA<MockSourceChecker>(),
      );
      expect(
        createTestApplication(useMock: false).sourceChecker,
        isA<RustSourceChecker>(),
      );
    });

    test('Mock 单源结果和宽松非对象输入保持', () async {
      final checker = MockSourceChecker(store: MockBookSourceStore());
      final result = await checker.checkSource(jsonEncode(_source.toJson()));
      expect(result['source_url'], 'fixture://a');
      expect(result['search_ok'], isTrue);
      expect(result['toc_ok'], isTrue);
      expect(result['content_ok'], isTrue);
      expect(result['total_time_ms'], 321);
      expect(result['captcha'], {
        'detected': false,
        'captcha_type': null,
        'matched_keyword': null,
      });
      expect(result['redirect'], isNull);
      expect((await checker.checkSource('[]'))['source_url'], '');
      await expectLater(checker.checkSource('bad JSON'), throwsFormatException);
    });

    test('Mock 空列表包含禁用源，顺序与未知源展示保持', () async {
      final store = MockBookSourceStore()
        ..sources.addAll([
          _source,
          _source.copyWith(
            bookSourceUrl: 'fixture://b',
            bookSourceName: '乙',
            enabled: false,
          ),
        ]);
      final checker = MockSourceChecker(store: store);
      final events = await checker.checkSourcesStream([]).toList();
      expect(events.map((e) => e['source_name']), ['甲', '乙']);
      expect(events.map((e) => e['index']), [0, 1]);
      expect(events.map((e) => e['is_last']), [false, true]);
      final unknown = await checker.checkSourcesStream(['不存在']).single;
      expect(unknown['source_name'], '不存在');
      expect(unknown['result']['source_url'], '不存在');
    });

    test('Mock 查名称使用当前存储，不建立另一份缓存', () async {
      final store = MockBookSourceStore()..sources.add(_source);
      final repository = MockBookSourceRepository(
        store: store,
        writeConfig: (_, _) {},
      );
      final checker = MockSourceChecker(store: store);
      final event = checker.checkSourcesStream(['fixture://a']).single;
      await repository.updateBookSource(
        _source.copyWith(bookSourceName: '更新名'),
      );
      expect((await event)['source_name'], '更新名');
      await repository.deleteBookSource('fixture://a');
      expect(await checker.checkSourcesStream([]).toList(), isEmpty);
    });

    test('Mock 原取消空操作与独立根存储保持', () async {
      final first = MockBookSourceStore()..sources.add(_source);
      final second = MockBookSourceStore();
      final checker = MockSourceChecker(store: first);
      final events = checker.checkSourcesStream([
        'fixture://a',
        'fixture://a',
      ]).toList();
      await checker.cancelCheckSources();
      expect(await events, hasLength(2));
      expect(
        await MockSourceChecker(store: second).checkSourcesStream([]).toList(),
        isEmpty,
      );
    });
  });

  group('校验会话', () {
    late SourceCheckerMock checker;
    late ProviderContainer container;
    late _PreparingNotifier notifier;
    late _GroupingNotifier grouping;
    late _QueuedStream stream;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      checker = SourceCheckerMock();
      stream = _QueuedStream();
      when(
        () => checker.checkSourcesStream(
          any(),
          configJson: any(named: 'configJson'),
        ),
      ).thenAnswer((_) => stream);
      when(checker.cancelCheckSources).thenAnswer((_) async {});
      container = ProviderContainer(
        overrides: [
          sourceCheckerProvider.overrideWithValue(checker),
          checkSourceNotifierProvider.overrideWith(_PreparingNotifier.new),
          sourceNotifierProvider.overrideWith(_GroupingNotifier.new),
        ],
      );
      notifier = container.read(
        checkSourceNotifierProvider.notifier,
      ) as _PreparingNotifier;
      grouping =
          container.read(sourceNotifierProvider.notifier) as _GroupingNotifier;
      addTearDown(container.dispose);
    });

    CheckSourceState read() => container.read(checkSourceNotifierProvider);
    Future<void> start() =>
        notifier.start(sourceUrls: ['fixture://a', 'fixture://b']);

    test('仅覆盖窄接口即可启动，进度与原成功文案保持', () async {
      await start();
      stream.emit(_event('fixture://a'));
      expect(read().checking, isTrue);
      expect(read().done, 1);
      expect(read().total, 2);
      expect(read().currentName, '名称fixture://a');
      expect(read().messages['fixture://a']!.text, '校验成功 321ms');
      stream.finish();
      expect(read().checking, isFalse);
      expect(read().cancelled, isFalse);
    });

    test('配置读取期间重复启动只发起一个流', () async {
      final gate = Completer<Map<String, dynamic>>();
      notifier.preparation = gate.future;
      final first = start();
      await start();
      verifyNever(
        () => checker.checkSourcesStream(
          any(),
          configJson: any(named: 'configJson'),
        ),
      );
      gate.complete({'keyword': '我的'});
      await first;
      verify(
        () => checker.checkSourcesStream(
          any(),
          configJson: any(named: 'configJson'),
        ),
      ).called(1);
    });

    test('取消准备后配置完成不再发起流或写入关键词', () async {
      final gate = Completer<Map<String, dynamic>>();
      notifier.preparation = gate.future;
      final first = notifier.start(
        sourceUrls: ['fixture://a'],
        keyword: '迟到关键词',
      );
      await notifier.cancel();
      gate.complete({'keyword': '我的'});
      await first;
      verifyNever(
        () => checker.checkSourcesStream(
          any(),
          configJson: any(named: 'configJson'),
        ),
      );
      verifyNever(checker.cancelCheckSources);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'check_source_keyword',
        ),
        isNull,
      );
      expect(read().cancelled, isTrue);
    });

    test('空列表与运行中重复启动不创建新流', () async {
      await notifier.start(sourceUrls: []);
      expect(read().hasSession, isFalse);
      await start();
      await start();
      verify(
        () => checker.checkSourcesStream(
          any(),
          configJson: any(named: 'configJson'),
        ),
      ).called(1);
    });

    test('准备失败允许重试，原异常传递', () async {
      final failure = StateError('读取配置失败');
      notifier.preparation = Future.error(failure);
      await expectLater(start(), throwsA(same(failure)));
      notifier.preparation = null;
      await start();
      expect(read().checking, isTrue);
    });

    test('当前流错误结束会话，后续进度被隔离', () async {
      await start();
      stream.fail(StateError('校验失败'));
      final stopped = read();
      expect(stopped.checking, isFalse);
      expect(stopped.cancelled, isTrue);
      stream.emit(_event('迟到', last: true, search: false));
      stream.finish();
      expect(read(), same(stopped));
      expect(grouping.writes, isEmpty);
    });

    test('正常末条仅回写一次失效分组，后续重复消息被隔离', () async {
      await start();
      stream.emit(_event('fixture://a', search: false));
      stream.emit(_event('fixture://b', index: 1, last: true));
      final completed = read();
      expect(completed.checking, isFalse);
      expect(completed.invalidCount, 1);
      expect(completed.messages['fixture://a']!.text, '搜索失败：失败原因 321ms');
      expect(grouping.writes, [
        {'fixture://a'},
      ]);
      stream.emit(_event('fixture://b', index: 1, last: true, search: false));
      stream.fail(StateError('迟到异常'));
      stream.finish();
      expect(read(), same(completed));
      expect(grouping.writes, hasLength(1));
    });

    test('取消解除订阅，不处理迟到进度、错误、完成或分组', () async {
      await start();
      await notifier.cancel();
      final cancelled = read();
      expect(stream.cancellations, 1);
      stream.emit(_event('fixture://a', last: true, search: false));
      stream.fail(StateError('迟到异常'));
      stream.finish();
      expect(read(), same(cancelled));
      expect(grouping.writes, isEmpty);
      verify(checker.cancelCheckSources).called(1);
    });

    test('下一轮等待旧取消完成，旧回调不能覆盖新进度', () async {
      final gate = Completer<void>();
      when(checker.cancelCheckSources).thenAnswer((_) => gate.future);
      await start();
      final old = stream;
      final cancel = notifier.cancel();
      final nextStream = _QueuedStream();
      when(
        () => checker.checkSourcesStream(
          any(),
          configJson: any(named: 'configJson'),
        ),
      ).thenAnswer((_) => nextStream);
      final next = start();
      await pumpEventQueue();
      verify(
        () => checker.checkSourcesStream(
          any(),
          configJson: any(named: 'configJson'),
        ),
      ).called(1);
      gate.complete();
      await cancel;
      await next;
      nextStream.emit(_event('新结果'));
      final current = read();
      old.emit(_event('旧结果', last: true, search: false));
      old.fail(StateError('旧异常'));
      old.finish();
      expect(read(), same(current));
      expect(read().checking, isTrue);
      expect(read().messages.keys, ['新结果']);
      expect(grouping.writes, isEmpty);
    });

    test('清除消息后迟到回调不能重建会话', () async {
      await start();
      notifier.clearMessages();
      await pumpEventQueue();
      stream.emit(_event('旧结果', last: true, search: false));
      expect(read().hasSession, isFalse);
      expect(read().messages, isEmpty);
      expect(grouping.writes, isEmpty);
      verify(checker.cancelCheckSources).called(1);
      expect(stream.cancellations, 1);
    });

    test('销毁取消发起实例并解除订阅，迟到回调不读取已销毁 Provider', () async {
      await start();
      container.dispose();
      await pumpEventQueue();
      stream.emit(_event('旧结果', last: true, search: false));
      stream.fail(StateError('迟到异常'));
      stream.finish();
      verify(checker.cancelCheckSources).called(1);
      expect(stream.cancellations, 1);
      expect(grouping.writes, isEmpty);
    });

    test('准备期间销毁不会在配置完成后启动原生流', () async {
      final gate = Completer<Map<String, dynamic>>();
      notifier.preparation = gate.future;
      final first = start();
      container.dispose();
      gate.complete({});
      await first;
      verifyNever(
        () => checker.checkSourcesStream(
          any(),
          configJson: any(named: 'configJson'),
        ),
      );
    });

    test('取消失败仍解除订阅并传递原错误', () async {
      final failure = StateError('取消失败');
      when(checker.cancelCheckSources).thenAnswer((_) async => throw failure);
      await start();
      await expectLater(notifier.cancel(), throwsA(same(failure)));
      expect(read().checking, isFalse);
      expect(read().cancelled, isTrue);
      expect(stream.cancellations, 1);
      stream.emit(_event('迟到'));
      expect(read().messages, isEmpty);
    });

    test('同步启动错误不会卡在运行态，可以再次启动', () async {
      final failure = StateError('流创建失败');
      when(
        () => checker.checkSourcesStream(
          any(),
          configJson: any(named: 'configJson'),
        ),
      ).thenThrow(failure);
      await expectLater(start(), throwsA(same(failure)));
      expect(read().checking, isFalse);
      expect(read().cancelled, isTrue);
      when(
        () => checker.checkSourcesStream(
          any(),
          configJson: any(named: 'configJson'),
        ),
      ).thenAnswer((_) => stream);
      await start();
      expect(read().checking, isTrue);
    });

    test('根替换不改变准备期间捕获的校验对象及其取消，下一轮使用新根', () async {
      final first = MockRustApi();
      final second = MockRustApi();
      final original = _QueuedStream();
      final next = _QueuedStream();
      when(
        () => first.sourceChecker.checkSourcesStream(
          any(),
          configJson: any(named: 'configJson'),
        ),
      ).thenAnswer((_) => original);
      when(
        () => second.sourceChecker.checkSourcesStream(
          any(),
          configJson: any(named: 'configJson'),
        ),
      ).thenAnswer((_) => next);
      when(first.sourceChecker.cancelCheckSources).thenAnswer((_) async {});
      when(second.sourceChecker.cancelCheckSources).thenAnswer((_) async {});
      final roots = ProviderContainer(
        overrides: mergeTestOverrides([
          ...first.overrides,
          sourceCheckerProvider.overrideWithValue(first.sourceChecker),
          checkSourceNotifierProvider.overrideWith(_PreparingNotifier.new),
        ]),
      );
      addTearDown(roots.dispose);
      final prepared = roots.read(
        checkSourceNotifierProvider.notifier,
      ) as _PreparingNotifier;
      final gate = Completer<Map<String, dynamic>>();
      prepared.preparation = gate.future;
      final task = prepared.start(sourceUrls: ['fixture://a']);
      roots.updateOverrides(
        mergeTestOverrides([
          ...second.overrides,
          sourceCheckerProvider.overrideWithValue(second.sourceChecker),
          checkSourceNotifierProvider.overrideWith(_PreparingNotifier.new),
        ]),
      );
      gate.complete({});
      await task;
      await prepared.cancel();
      verify(first.sourceChecker.cancelCheckSources).called(1);
      verifyNever(second.sourceChecker.cancelCheckSources);
      prepared.preparation = null;
      await prepared.start(sourceUrls: ['fixture://a']);
      verify(
        () => second.sourceChecker.checkSourcesStream(
          any(),
          configJson: any(named: 'configJson'),
        ),
      ).called(1);
      verifyNever(first.runtime.initialize);
      verifyNever(second.runtime.initialize);
    });
  });
}
