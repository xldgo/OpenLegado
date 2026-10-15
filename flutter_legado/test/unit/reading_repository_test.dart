import 'package:flutter_legado/src/app/bootstrap/book_api_bootstrap.dart';
import 'package:flutter_legado/src/data/repositories/mock_reading_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_reading_repository.dart';
import 'package:flutter_legado/src/domain/contracts/reading_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/reading_provider.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('目录解码', () {
    test('接受既有对象与裸数组，保留章节字段及顺序', () {
      const items = '[{"url":"chapter","title":"目录","index":2,"isVip":true}]';
      final chapters = decodeReadingChapters(items, 'getChapters');
      expect(chapters, [
        const BookChapter(url: 'chapter', title: '目录', index: 2, isVip: true),
      ]);
      expect(
        decodeReadingChapters('{"total":1,"chapters":$items}', 'refreshToc'),
        chapters,
      );
    });
    test('合法空目录成功，不将错误响应当空目录', () {
      expect(decodeReadingChapters('[]', 'getChapters'), isEmpty);
      expect(decodeReadingChapters('{"chapters":[]}', 'refreshToc'), isEmpty);
    });
    for (final json in [
      '{}',
      '{"chapters":null}',
      '{"chapters":{}}',
      'null',
      'true',
      '"网络失败"',
      '[null]',
      '[3]',
      '[{"index":"错误序号"}]',
      '{',
    ]) {
      test('非法目录报错：$json', () {
        expect(
          () => decodeReadingChapters(json, 'refreshToc'),
          throwsFormatException,
        );
      });
    }
  });

  test('Mock正文保存后所有读取入口使用同一缓存', () async {
    final api = MockBookApi();
    final repository = api.readingRepository;
    expect(repository, isA<MockReadingRepository>());
    expect(
      await repository.saveChapterContent(
        bookUrl: 'test://reading',
        chapterIndex: 3,
        title: '标题',
        content: '更新正文😀',
      ),
      isTrue,
    );
    expect(await repository.getChapterContent('test://reading', 3), '更新正文😀');
    expect(
      await repository.getChapterContentRaw('test://reading', 3),
      '更新正文😀',
    );
    expect(
      await repository.getChapterContentFull('test://reading', 3),
      '更新正文😀',
    );
    expect(
      await api.readingRepository.getChapterContent('test://reading', 3),
      '更新正文😀',
    );
  });

  test('Mock进度与书架共享存储，位置整数不被重新解释', () async {
    final api = MockBookApi();
    const book = Book(bookUrl: 'test://reading', name: '共享进度');
    await api.bookshelfRepository.addBook(book);
    await api.readingRepository.updateReadingProgress(
      bookUrl: book.bookUrl,
      chapterIndex: 4,
      chapterPos: 123456,
    );
    final updated = await api.bookshelfRepository.getBook(book.bookUrl);
    expect(updated?.durChapterIndex, 4);
    expect(updated?.durChapterPos, 123456);
    expect(updated?.name, book.name);
    await api.readingRepository.updateReadingProgress(
      bookUrl: 'missing',
      chapterIndex: 1,
      chapterPos: 0,
    );
    expect(await api.bookshelfRepository.getBook('missing'), isNull);
  });

  test('Mock保留缺内容和网络占位，不虚构联网抓取', () async {
    final repository = MockBookApi().readingRepository;
    expect(await repository.getChapters('missing'), isEmpty);
    expect(await repository.refreshToc('missing', 'source'), isEmpty);
    expect(await repository.getChapterContent('missing', 0), '（暂无内容）');
    expect(await repository.getChapterContentRaw('missing', 0), '（暂无内容）');
    expect(
      await repository.getChapterContentFull('missing', 0),
      '（Mock 模式：章节内容）',
    );
    expect(
      await repository.fetchChapterContent('missing', 'chapter', 'source'),
      '（Mock 模式：网络章节内容）\n\n这是从网络获取的章节正文。',
    );
  });

  test('Provider共享装配实例，并随根实例替换', () {
    final first = MockBookApi();
    final second = MockBookApi();
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(first)],
    );
    addTearDown(container.dispose);
    expect(
      container.read(readingRepositoryProvider),
      same(first.readingRepository),
    );
    container.updateOverrides([bookApiProvider.overrideWithValue(second)]);
    expect(
      container.read(readingRepositoryProvider),
      same(second.readingRepository),
    );
    expect(
      createBookApi(useMock: true).readingRepository,
      isA<ReadingRepository>(),
    );
    expect(
      createBookApi(useMock: false).readingRepository,
      isA<RustReadingRepository>(),
    );
  });
}
