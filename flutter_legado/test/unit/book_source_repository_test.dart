import 'package:flutter_legado/src/data/bridge/mock_app_runtime.dart';

import 'dart:convert';

import 'package:flutter_legado/src/app/bootstrap/book_api_bootstrap.dart';
import 'package:flutter_legado/src/data/repositories/mock_book_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_repository.dart';
import 'package:flutter_legado/src/features/book_sources/book_sources.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements BookSourceRepository {}

class _Api extends MockBookApi {
  int initializationCount = 0;
  @override
  MockAppRuntime get runtime => _fixtureRuntime;
  late final _fixtureRuntime = MockAppRuntime(startup: _fixtureInitialize);

  Future<void> _fixtureInitialize() async => initializationCount++;
}

const _source = BookSource(
  bookSourceUrl: 'fixture://source',
  bookSourceName: '源配置',
  bookSourceGroup: '分组',
  enabled: true,
  customOrder: 7,
  variable: '旧变量',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('只覆盖窄接口可以加载书源，失败和空返回不清空已有列表', () async {
    final repository = _Repository();
    final container = ProviderContainer(
      overrides: [
        bookSourceRepositoryProvider.overrideWithValue(repository),
        bookApiProvider.overrideWith((ref) => throw StateError('不应创建根实例')),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(sourceNotifierProvider.notifier);
    when(repository.getBookSources).thenAnswer((_) async => [_source]);
    await notifier.loadSources();
    expect(container.read(sourceNotifierProvider).sources, [_source]);
    when(repository.getBookSources).thenThrow(StateError('加载失败'));
    await notifier.loadSources();
    expect(container.read(sourceNotifierProvider).sources, [_source]);
    expect(container.read(sourceNotifierProvider).error, contains('加载失败'));
    when(repository.getBookSources).thenAnswer((_) async => []);
    await notifier.loadSources();
    expect(container.read(sourceNotifierProvider).sources, [_source]);
    expect(container.read(sourceNotifierProvider).loading, isFalse);
  });

  test('Provider 分享根引用，替换根后跟随替换且不初始化', () {
    final first = _Api();
    final second = _Api();
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(first)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      bookSourceRepositoryProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    expect(
      container.read(bookSourceRepositoryProvider),
      same(first.bookSourceRepository),
    );
    container.updateOverrides([bookApiProvider.overrideWithValue(second)]);
    expect(
      container.read(bookSourceRepositoryProvider),
      same(second.bookSourceRepository),
    );
    expect(first.initializationCount, 0);
    expect(second.initializationCount, 0);
  });

  test('Mock 查询副本、变量写入和缺失失败不改变其他字段', () async {
    final store = MockBookSourceStore()..sources.add(_source);
    final repository = MockBookSourceRepository(
      store: store,
      writeConfig: (key, value) {},
    );
    (await repository.getBookSources()).clear();
    (await repository.getEnabledBookSources()).clear();
    expect(await repository.getBookSources(), [_source]);
    await repository.setSourceVariable(_source.bookSourceUrl, '新变量');
    expect(await repository.getBookSources(), [
      _source.copyWith(variable: '新变量'),
    ]);
    await repository.setSourceVariable(_source.bookSourceUrl, '');
    final before = await repository.getBookSources();
    await expectLater(repository.setSourceVariable('缺失', '值'), throwsException);
    expect(await repository.getBookSources(), before);
    expect(before.single.variable, '');
  });

  test('Mock 默认种子、校验任务和排序配置共用原存储', () async {
    final api = MockBookApi();
    final repository = api.bookSourceRepository;
    for (final source in await repository.getBookSources()) {
      await repository.deleteBookSource(source.bookSourceUrl);
    }
    await repository.addBookSource(_source);
    await repository.updateBookSource(_source.copyWith(bookSourceName: '校验可见'));
    final events = await api.sourceChecker.checkSourcesStream([]).toList();
    expect(events, hasLength(1));
    expect(events.single['source_name'], '校验可见');
    expect(events.single['result']['source_url'], _source.bookSourceUrl);
    await repository.sortBookSources(2, false);
    expect(await api.configRepository.getConfig('source_sort_key'), '2');
    expect(
      await api.configRepository.getConfig('source_sort_ascending'),
      'false',
    );
    expect(
      createBookApi(useMock: true).bookSourceRepository,
      isA<MockBookSourceRepository>(),
    );
  });

  test('Mock 启停与空目标行为保持，独立会话不串源', () async {
    final api = MockBookApi();
    final repository = api.bookSourceRepository;
    final other = MockBookApi().bookSourceRepository;
    await repository.addBookSource(_source);
    await repository.disableBookSource(_source.bookSourceUrl);
    expect(
      (await repository.getEnabledBookSources()).any(
        (s) => s.bookSourceUrl == _source.bookSourceUrl,
      ),
      isFalse,
    );
    await repository.enableBookSource(_source.bookSourceUrl);
    expect(
      (await repository.getEnabledBookSources()).any(
        (s) => s.bookSourceUrl == _source.bookSourceUrl,
      ),
      isTrue,
    );
    final before = await repository.getBookSources();
    await repository.updateBookSource(_source.copyWith(bookSourceUrl: '缺失'));
    await repository.disableBookSource('缺失');
    await repository.enableBookSource('缺失');
    await repository.deleteBookSource('缺失');
    expect(await repository.getBookSources(), before);
    expect(
      (await other.getBookSources()).any(
        (s) => s.bookSourceUrl == _source.bookSourceUrl,
      ),
      isFalse,
    );
  });

  test('Mock 导入仍只返回数量，错误保留存储，导出保留完整字段', () async {
    final store = MockBookSourceStore()..sources.add(_source);
    final repository = MockBookSourceRepository(
      store: store,
      writeConfig: (key, value) {},
    );
    final before = await repository.getBookSources();
    expect(
      await repository.importBookSources(jsonEncode([_source.toJson()])),
      1,
    );
    expect(await repository.getBookSources(), before);
    await expectLater(
      repository.importBookSources('坏JSON'),
      throwsFormatException,
    );
    expect(await repository.getBookSources(), before);
    expect(jsonDecode(await repository.exportBookSources()), [
      _source.toJson(),
    ]);
  });
}
