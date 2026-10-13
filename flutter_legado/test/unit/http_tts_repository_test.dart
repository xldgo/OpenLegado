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

  test('Mock CRUD 保留字段与顺序，查询副本不能改写存储', () async {
    var nextId = 42;
    final repository = MockHttpTtsRepository(nextId: () => nextId++);
    const input = HttpTts(
      id: -1,
      name: '甲',
      url: 'http://a',
      contentType: 'audio/wav',
    );
    final first = await repository.addHttpTts(input);
    final second = await repository.addHttpTts(
      const HttpTts(name: '乙', url: 'http://b'),
    );
    expect(first, input.copyWith(id: 42));
    final updated = first.copyWith(name: '修改', url: 'http://new');
    await repository.updateHttpTts(updated);
    await repository.updateHttpTts(const HttpTts(id: 999, name: '不存在'));
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
  });

  test('Mock 导入只返回数量，启用操作维持原空实现，不伪造落库', () async {
    final repository = MockHttpTtsRepository(nextId: () => 1);
    expect(
      await repository.importHttpTts('[{"name":"仅统计","url":"http://a"}]'),
      1,
    );
    expect(await repository.getHttpTts(), isEmpty);
    expect(await repository.httpTtsSetEnabled(99, false), isTrue);
    await expectLater(
      repository.importHttpTts('不是JSON'),
      throwsFormatException,
    );
    await expectLater(
      repository.importHttpTts('{}'),
      throwsA(isA<TypeError>()),
    );
    expect(await repository.getHttpTts(), isEmpty);
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
  Future<void> initialize() async => initializations++;
}
