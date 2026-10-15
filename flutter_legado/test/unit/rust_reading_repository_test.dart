import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_reading_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  late RustReadingRepository repository;
  late List<String> intercepted;

  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
    intercepted = [];
    repository = RustReadingRepository(
      interceptResult: (raw) async {
        intercepted.add(raw);
        return raw.startsWith('载荷:') ? raw.substring(3) : raw;
      },
    );
  });
  tearDown(RustLib.dispose);

  test('读取目录直接解码，刷新目录先执行平台载荷', () async {
    when(() => bridge.crateFfiFfiReaderGetChapters(bookUrl: 'book'))
        .thenAnswer((_) async => '{"chapters":[{"title":"本地目录"}]}');
    when(
      () => bridge.crateFfiFfiReaderRefreshToc(bookUrl: 'book', sourceUrl: '源'),
    ).thenAnswer((_) async => '载荷:[{"title":"网络目录"}]');
    expect((await repository.getChapters('book')).single.title, '本地目录');
    expect(intercepted, isEmpty);
    expect((await repository.refreshToc('book', '源')).single.title, '网络目录');
    expect(intercepted, ['载荷:[{"title":"网络目录"}]']);
    verify(() => bridge.crateFfiFfiReaderGetChapters(bookUrl: 'book'))
        .called(1);
    verify(
      () => bridge.crateFfiFfiReaderRefreshToc(bookUrl: 'book', sourceUrl: '源'),
    ).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('本地正文和原文搜索沿用各自FRB入口，不进入平台拦截', () async {
    when(
      () =>
          bridge.crateFfiFfiReaderGetContent(bookUrl: 'book', chapterIndex: 2),
    ).thenAnswer((_) async => '净化正文');
    when(
      () => bridge.crateFfiFfiReaderGetContentRaw(
        bookUrl: 'book',
        chapterIndex: 2,
      ),
    ).thenAnswer((_) async => '原始正文');
    expect(await repository.getChapterContent('book', 2), '净化正文');
    expect(await repository.getChapterContentRaw('book', 2), '原始正文');
    expect(intercepted, isEmpty);
  });

  test('完整正文和网络正文均返回平台载荷处理后的内容', () async {
    when(
      () => bridge.crateFfiFfiReaderGetContentFull(
        bookUrl: 'book',
        chapterIndex: 2,
      ),
    ).thenAnswer((_) async => '载荷:完整正文');
    when(
      () => bridge.crateFfiFfiReaderFetchContent(
        bookUrl: 'book',
        chapterUrl: 'chapter',
        sourceUrl: '源',
      ),
    ).thenAnswer((_) async => '载荷:网络正文');
    expect(await repository.getChapterContentFull('book', 2), '完整正文');
    expect(
      await repository.fetchChapterContent('book', 'chapter', '源'),
      '网络正文',
    );
    expect(intercepted, ['载荷:完整正文', '载荷:网络正文']);
  });

  test('正文写入保留原参数，空chapterUrl仍由Rust回填', () async {
    when(
      () => bridge.crateFfiFfiSaveChapterContent(
        bookUrl: 'book',
        chapterIndex: 3,
        title: '章名',
        content: '新正文😀',
        chapterUrl: '',
      ),
    ).thenAnswer((_) async => false);
    expect(
      await repository.saveChapterContent(
        bookUrl: 'book',
        chapterIndex: 3,
        title: '章名',
        content: '新正文😀',
      ),
      isFalse,
    );
    verify(
      () => bridge.crateFfiFfiSaveChapterContent(
        bookUrl: 'book',
        chapterIndex: 3,
        title: '章名',
        content: '新正文😀',
        chapterUrl: '',
      ),
    ).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('进度不换算坐标、不另存副本', () async {
    when(
      () => bridge.crateFfiFfiReaderUpdateProgress(
        bookUrl: 'video',
        chapterIndex: 1,
        chapterPos: 123456,
      ),
    ).thenAnswer((_) async {});
    await repository.updateReadingProgress(
      bookUrl: 'video',
      chapterIndex: 1,
      chapterPos: 123456,
    );
    verify(
      () => bridge.crateFfiFfiReaderUpdateProgress(
        bookUrl: 'video',
        chapterIndex: 1,
        chapterPos: 123456,
      ),
    ).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('Rust错误原样传播，不触发拦截或回退为空正文', () async {
    final error = StateError('正文失败');
    when(
      () => bridge.crateFfiFfiReaderGetContentFull(
        bookUrl: 'book',
        chapterIndex: 2,
      ),
    ).thenThrow(error);
    await expectLater(
      repository.getChapterContentFull('book', 2),
      throwsA(same(error)),
    );
    expect(intercepted, isEmpty);
  });

  test('平台执行失败原样传播，不当作成功正文或空目录', () async {
    when(
      () => bridge.crateFfiFfiReaderRefreshToc(bookUrl: 'book', sourceUrl: '源'),
    ).thenAnswer((_) async => '载荷');
    final error = StateError('平台执行失败');
    repository = RustReadingRepository(
      interceptResult: (_) async => throw error,
    );
    await expectLater(repository.refreshToc('book', '源'), throwsA(same(error)));
  });

  for (final invalid in ['{}', '{"chapters":null}', '[null]']) {
    test('刷新后的错误目录不回退为空列表：$invalid', () async {
      when(
        () =>
            bridge.crateFfiFfiReaderRefreshToc(bookUrl: 'book', sourceUrl: '源'),
      ).thenAnswer((_) async => invalid);
      await expectLater(
        repository.refreshToc('book', '源'),
        throwsFormatException,
      );
    });
  }
}
