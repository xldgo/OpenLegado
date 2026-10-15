import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_chapter_cache_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const repository = RustChapterCacheRepository();

  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('单章/整书清理及正文读取保留FRB参数与返回值', () async {
    when(() => bridge.crateFfiFfiCacheClearBook(bookUrl: '书'))
        .thenAnswer((_) async => 4);
    when(
      () => bridge.crateFfiFfiCacheClearChapter(bookUrl: '书', chapterIndex: 2),
    ).thenAnswer((_) async => 1);
    when(() => bridge.crateFfiFfiCacheGetChapter(bookUrl: '书', chapterIndex: 2))
        .thenAnswer((_) async => '缓存正文');
    expect(await repository.clearBookCache('书'), 4);
    expect(await repository.clearChapterCache('书', 2), 1);
    expect(await repository.getCachedChapter('书', 2), '缓存正文');
    verify(() => bridge.crateFfiFfiCacheClearBook(bookUrl: '书')).called(1);
    verify(
      () => bridge.crateFfiFfiCacheClearChapter(bookUrl: '书', chapterIndex: 2),
    ).called(1);
    verify(
      () => bridge.crateFfiFfiCacheGetChapter(bookUrl: '书', chapterIndex: 2),
    ).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('合法URL与字数列表保留顺序、过滤空字数', () async {
    when(() => bridge.crateFfiFfiCacheListCachedChapterUrls(bookUrl: '书'))
        .thenAnswer((_) async => '["c2","c1"]');
    when(() => bridge.crateFfiFfiCacheListCachedChapters(bookUrl: '书'))
        .thenAnswer(
          (_) async =>
              '[{"url":"c2","wordCount":"1.2万字"},{"url":"c1","wordCount":""}]',
        );
    expect(await repository.listCachedChapterUrls('书'), ['c2', 'c1']);
    expect(await repository.listCachedChapters('书'), {'c2': '1.2万字'});
  });

  for (final raw in ['{}', 'null', '{', '[null]', '[2]']) {
    test('缓存列表结构错误必须失败：$raw', () async {
      when(() => bridge.crateFfiFfiCacheListCachedChapterUrls(bookUrl: '书'))
          .thenAnswer((_) async => raw);
      when(() => bridge.crateFfiFfiCacheListCachedChapters(bookUrl: '书'))
          .thenAnswer((_) async => raw);
      await expectLater(
        repository.listCachedChapterUrls('书'),
        throwsFormatException,
      );
      await expectLater(
        repository.listCachedChapters('书'),
        throwsFormatException,
      );
    });
  }

  for (final raw in [
    '[{}]',
    '[{"url":"c","wordCount":42}]',
    '[{"url":3,"wordCount":"42字"}]',
  ]) {
    test('字数条目缺字段或类型错误不能跳过：$raw', () async {
      when(() => bridge.crateFfiFfiCacheListCachedChapters(bookUrl: '书'))
          .thenAnswer((_) async => raw);
      await expectLater(
        repository.listCachedChapters('书'),
        throwsFormatException,
      );
    });
  }

  test('合法空列表成功，FRB失败原样传递', () async {
    when(() => bridge.crateFfiFfiCacheListCachedChapters(bookUrl: '书'))
        .thenAnswer((_) async => '[]');
    when(() => bridge.crateFfiFfiCacheListCachedChapterUrls(bookUrl: '书'))
        .thenAnswer((_) async => '[]');
    expect(await repository.listCachedChapters('书'), isEmpty);
    expect(await repository.listCachedChapterUrls('书'), isEmpty);
    final error = StateError('数据库不可用');
    when(
      () => bridge.crateFfiFfiCacheClearChapter(bookUrl: '书', chapterIndex: 2),
    ).thenThrow(error);
    await expectLater(
      () => repository.clearChapterCache('书', 2),
      throwsA(same(error)),
    );
  });
}
