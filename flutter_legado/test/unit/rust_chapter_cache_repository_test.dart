import '../fixtures/business_transport_fixtures.dart';

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
        .thenAnswer((_) async => ['c2', 'c1']);
    when(() => bridge.crateFfiFfiCacheListCachedChapters(bookUrl: '书'))
        .thenAnswer(
          (_) async => fixtureCached(
            '[{"url":"c2","wordCount":"1.2万字"},{"url":"c1","wordCount":""}]',
          ),
        );
    expect(await repository.listCachedChapterUrls('书'), ['c2', 'c1']);
    expect(await repository.listCachedChapters('书'), {'c2': '1.2万字'});
  });

  test('合法空列表成功，FRB失败原样传递', () async {
    when(() => bridge.crateFfiFfiCacheListCachedChapters(bookUrl: '书'))
        .thenAnswer((_) async => fixtureCached('[]'));
    when(() => bridge.crateFfiFfiCacheListCachedChapterUrls(bookUrl: '书'))
        .thenAnswer((_) async => []);
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
