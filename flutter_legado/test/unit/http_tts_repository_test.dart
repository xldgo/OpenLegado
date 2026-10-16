import 'package:flutter_legado/src/data/bridge/mock_app_runtime.dart';

import 'dart:convert';

import 'package:flutter_legado/src/app/bootstrap/book_api_bootstrap.dart';
import 'package:flutter_legado/src/data/repositories/mock_http_tts_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_http_tts_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('工厂选择正式实现，Mock 默认样例与会话隔离保持原样', () async {
    expect(
      createBookApi(useMock: false).httpTtsRepository,
      isA<RustHttpTtsRepository>(),
    );
    final first = createBookApi(useMock: true).httpTtsRepository;
    final second = createBookApi(useMock: true).httpTtsRepository;
    final seeds = await first.getHttpTts();
    expect(seeds.map((e) => e.id), [-100, -29]);
    expect(seeds.map((e) => e.name), ['1.百度', '2.阿里云语音']);
    expect(seeds.map((e) => e.contentType), ['audio/wav', 'audio/mpeg']);
    await first.addHttpTts(
      const HttpTts(name: '新引擎', url: 'http://example.test/tts'),
    );
    expect(await second.getHttpTts(), seeds);
  });

  test(
    'Mock CRUD 保留全部高级字段与顺序（id=0 分配新 ID，id!=0 保留），更新不存在 ID 抛错且不改写存储',
    () async {
      var nextId = 42;
      final repository = MockHttpTtsRepository(nextId: () => nextId++);
      const input = HttpTts(
        id: 0,
        name: '甲',
        url: 'http://a',
        contentType: 'audio/wav',
        pauseDuration: 150,
        concurrentRate: '1500',
        loginUrl: 'function login(){}',
        loginUi: '[{"name":"AppKey","type":"text"}]',
        header: '{"Authorization":"Bearer token"}',
        jsLib: 'var v = 1;',
        enabledCookieJar: true,
        loginCheckJs: 'result',
        speed: 18,
        synthesisThreadCount: 12,
        lastUpdateTime: 1700000000000,
        isEnabled: false,
      );
      final first = await repository.addHttpTts(input);
      final second = await repository.addHttpTts(
        const HttpTts(id: -29, name: '乙', url: 'http://b'),
      );
      expect(first, input.copyWith(id: 42, synthesisThreadCount: 8));
      expect(second.id, -29);
      final updated = first.copyWith(
        name: '修改',
        url: 'http://new',
        speed: 25,
        synthesisThreadCount: 4,
      );
      await repository.updateHttpTts(updated);
      await expectLater(
        repository.updateHttpTts(const HttpTts(id: 999, name: '不存在')),
        throwsStateError,
      );
      final expected = [updated, second];
      expect(await repository.getHttpTts(), expected);
      (await repository.getHttpTts()).clear();
      expect(await repository.getHttpTts(), expected);
      expect(
        jsonDecode(await repository.exportHttpTts()),
        expected.map((e) => e.toJson()).toList(),
      );
      await repository.deleteHttpTts(999);
      await repository.deleteHttpTts(first.id);
      expect(await repository.getHttpTts(), [second]);
    },
  );

  test('Mock 导入完整保留字段、支持数组 loginUi 并更新启用态', () async {
    var nextId = 10;
    final repository = MockHttpTtsRepository(nextId: () => nextId++);
    expect(
      await repository.importHttpTts(
        jsonEncode([
          {
            'id': -29,
            'name': '阿里云',
            'url': 'https://nls.example.com/tts',
            'contentType': 'audio/mpeg',
            'loginUi': [
              {'name': 'AppKey', 'type': 'text'},
            ],
            'speed': 10,
            'synthesisThreadCount': 99,
            'pauseDuration': 120,
            'isEnabled': false,
          },
          {'name': '', 'url': 'http://skip'},
        ]),
      ),
      1,
    );
    final stored = (await repository.getHttpTts()).single;
    expect(stored.id, -29);
    expect(stored.name, '阿里云');
    expect(stored.loginUi, '[{"name":"AppKey","type":"text"}]');
    expect(stored.speed, 10);
    expect(stored.synthesisThreadCount, 8);
    expect(stored.pauseDuration, 120);
    expect(stored.isEnabled, isFalse);

    expect(await repository.httpTtsSetEnabled(-29, true), isTrue);
    expect((await repository.getHttpTts()).single.isEnabled, isTrue);

    await expectLater(
      repository.importHttpTts('不是JSON'),
      throwsFormatException,
    );
    await expectLater(
      repository.importHttpTts('{}'),
      throwsA(isA<TypeError>()),
    );
  });

  test('Mock 导入无 ID 条目时跳过已被占用的正 ID，绝不覆盖已有记录', () async {
    var nextId = 1;
    final repository = MockHttpTtsRepository(nextId: () => nextId++);
    // 预置显式 ID=1 的已有引擎
    await repository.addHttpTts(
      const HttpTts(id: 1, name: '预置引擎', url: 'http://orig'),
    );
    // 导入无 ID 条目（id 为 0 或未提供，nextId 首次生成也是 1）
    final count = await repository.importHttpTts(
      jsonEncode([
        {'name': '导入的新引擎', 'url': 'http://imported'},
      ]),
    );
    expect(count, 1);
    final all = await repository.getHttpTts();
    expect(all, hasLength(2));
    expect(all[0].id, 1);
    expect(all[0].name, '预置引擎');
    expect(all[1].id, 2);
    expect(all[1].name, '导入的新引擎');
  });

  test('HTTP 配置与书签沿用根对象的同一 ID 分配，不改变其他领域', () async {
    final api = MockBookApi();
    final first = await api.httpTtsRepository.addHttpTts(
      const HttpTts(name: '一'),
    );
    final bookmark = await api.bookmarkRepository.addBookmark(
      const Bookmark(bookName: '测试'),
    );
    final second = await api.httpTtsRepository.addHttpTts(
      const HttpTts(name: '二'),
    );
    expect([first.id, bookmark.id, second.id], [1, 2, 3]);
  });

  test('根实例共享及替换不会创建第二份列表或重新初始化', () async {
    final first = _Api();
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(first)],
    );
    addTearDown(container.dispose);
    final consumer = Provider((ref) => ref.watch(httpTtsRepositoryProvider));
    final repository = container.read(consumer);
    expect(repository, same(first.httpTtsRepository));
    expect(container.read(httpTtsRepositoryProvider), same(repository));
    await repository.addHttpTts(const HttpTts(name: '旧会话'));
    final second = _Api();
    container.updateOverrides([bookApiProvider.overrideWithValue(second)]);
    expect(container.read(consumer), same(second.httpTtsRepository));
    expect(
      (await container.read(consumer).getHttpTts()).map((e) => e.name),
      isNot(contains('旧会话')),
    );
    expect((await repository.getHttpTts()).map((e) => e.name), contains('旧会话'));
    expect(first.initializations + second.initializations, 0);
  });
}

class _Api extends MockBookApi {
  int initializations = 0;
  @override
  MockAppRuntime get runtime => _fixtureRuntime;
  late final _fixtureRuntime = MockAppRuntime(startup: _fixtureInitialize);

  Future<void> _fixtureInitialize() async => initializations++;
}
