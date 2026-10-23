import 'package:flutter_legado/src/domain/contracts/content_search_service.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/features/search/application/content_search_controller.dart';
import 'package:flutter_legado/src/domain/contracts/reading_repository.dart';
import 'package:flutter_legado/src/domain/contracts/chapter_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/search_history_repository.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Reading extends Mock implements ReadingRepository {}

class _Cache extends Mock implements ChapterCacheRepository {}

class _History extends Mock implements SearchHistoryRepository {}

class _Matching extends Mock implements ContentSearchService {}

class _Matcher extends Mock implements ContentSearchMatcher {}

void main() {
  late _Reading reading;
  late _Cache cache;
  late _History history;
  late _Matching matching;
  final handles = <_Matcher>[];
  late ContentSearchController controller;
  late List<String> errors;
  setUp(() {
    reading = _Reading();
    cache = _Cache();
    history = _History();
    matching = _Matching();
    handles.clear();
    when(() => matching.open(any(), useRegex: any(named: 'useRegex')))
        .thenAnswer((call) async {
          final query = call.positionalArguments[0] as String;
          if (query == '[') return null;
          final matcher = _Matcher();
          handles.add(matcher);
          when(matcher.close).thenReturn(null);
          when(() => matcher.search(any())).thenAnswer((call) async {
            final content = call.positionalArguments[0] as String;
            final fixture = <(String, String), ContentSearchHit>{
              ('关键词', '新关键词'): const ContentSearchHit(
                sourceStart: 1,
                sourceEnd: 4,
                snippet: '新关键词',
                highlightStart: 1,
                highlightEnd: 4,
              ),
              ('关键词', '替换关键词'): const ContentSearchHit(
                sourceStart: 2,
                sourceEnd: 5,
                snippet: '替换关键词',
                highlightStart: 2,
                highlightEnd: 5,
              ),
              ('新', '新关键词'): const ContentSearchHit(
                sourceStart: 0,
                sourceEnd: 1,
                snippet: '新关键词',
                highlightStart: 0,
                highlightEnd: 1,
              ),
              ('旧', '旧'): const ContentSearchHit(
                sourceStart: 0,
                sourceEnd: 1,
                snippet: '旧',
                highlightStart: 0,
                highlightEnd: 1,
              ),
            }[(query, content)];
            if (fixture == null) throw StateError('缺少正文搜索夹具');
            return [fixture];
          });
          return matcher;
        });
    errors = [];
    when(() => history.addSearchKeyword(any(), any())).thenAnswer((_) async {});
    when(() => reading.getChapters('book')).thenAnswer(
      (_) async => List.generate(
        3,
        (i) => BookChapter(url: 'c$i', title: '章$i', index: i, bookUrl: 'book'),
      ),
    );
    when(() => reading.getChapterContentRaw('book', any()))
        .thenAnswer((_) async => '新关键词');
    when(() => reading.getChapterContent('book', any()))
        .thenAnswer((_) async => '替换关键词');
    controller = ContentSearchController(
      bookUrl: 'book',
      bookName: '书',
      reading: reading,
      cache: cache,
      history: history,
      matching: matching,
      log: (op, e, s) => errors.add(op),
    );
    addTearDown(controller.dispose);
  });
  Future<void> search(
    String query, {
    ContentSearchScope scope = ContentSearchScope.network,
    bool replace = false,
    bool regex = false,
  }) => controller.search(
    query,
    currentChapterIndex: 0,
    useRegex: regex,
    useReplace: replace,
    scope: scope,
  );
  test('已缓存范围只扫描当前章与已缓存章，并按正文口径选择净化接口', () async {
    when(() => cache.listCachedChapterUrls('book'))
        .thenAnswer((_) async => ['c2']);
    await search('关键词', scope: ContentSearchScope.cached, replace: true);
    expect(controller.state.results.map((r) => r.chapterIndex), [0, 2]);
    verifyNever(() => reading.getChapterContent('book', 1));
    verifyNever(() => reading.getChapterContentRaw(any(), any()));
    expect(() => controller.state.results.clear(), throwsUnsupportedError);
  });
  test('新搜索覆盖旧搜索，迟到结果不再调度下一章或覆盖状态', () async {
    final old = Completer<String>();
    var calls = 0;
    when(() => reading.getChapterContentRaw('book', 0))
        .thenAnswer((_) => calls++ == 0 ? old.future : Future.value('新关键词'));
    final first = search('旧');
    await Future<void>.delayed(Duration.zero);
    await search('新');
    old.complete('旧');
    await first;
    expect(controller.state.query, '新');
    expect(controller.state.results, hasLength(3));
    verify(() => reading.getChapterContentRaw('book', 1)).called(1);
  });
  test('清空会取消扫描，迟到正文不重新填充结果', () async {
    final pending = Completer<String>();
    when(() => reading.getChapterContentRaw('book', 0))
        .thenAnswer((_) => pending.future);
    final searching = search('关键词');
    await Future<void>.delayed(Duration.zero);
    controller.clear();
    pending.complete('关键词');
    await searching;
    expect(controller.state.query, '');
    expect(controller.state.results, isEmpty);
    expect(controller.state.searching, isFalse);
    verifyNever(() => reading.getChapterContentRaw('book', 1));
  });
  test('失败章节跳过并记录诊断，其余结果继续返回', () async {
    when(() => reading.getChapterContentRaw('book', 1))
        .thenThrow(StateError('离线'));
    await search('关键词');
    expect(controller.state.results.map((r) => r.chapterIndex), [0, 2]);
    expect(errors, ['搜索章节1']);
    expect(controller.state.searching, isFalse);
  });
  test('非法正则保持空结果，不请求正文', () async {
    await search('[', regex: true);
    expect(controller.state.results, isEmpty);
    expect(controller.state.searching, isFalse);
    verifyNever(() => reading.getChapterContentRaw(any(), any()));
  });
  test('编译及匹配等待期间停止，迟到结果不发布且最终释放各自句柄', () async {
    final compiled = Completer<ContentSearchMatcher?>();
    final handle = _Matcher();
    when(handle.close).thenReturn(null);
    when(() => matching.open('编译中', useRegex: false))
        .thenAnswer((_) => compiled.future);
    final pendingOpen = search('编译中');
    controller.cancel();
    compiled.complete(handle);
    await pendingOpen;
    verifyNever(() => handle.search(any()));
    verify(handle.close).called(1);

    final result = Completer<List<ContentSearchHit>>();
    final matchedHandle = _Matcher();
    when(matchedHandle.close).thenReturn(null);
    when(() => matching.open('匹配中', useRegex: false))
        .thenAnswer((_) async => matchedHandle);
    when(() => matchedHandle.search(any())).thenAnswer((_) => result.future);
    final pendingMatch = search('匹配中');
    await Future<void>.delayed(Duration.zero);
    controller.cancel();
    result.complete([
      const ContentSearchHit(
        sourceStart: 1,
        sourceEnd: 2,
        snippet: '迟到',
        highlightStart: 1,
        highlightEnd: 2,
      ),
    ]);
    await pendingMatch;
    expect(controller.state.results, isEmpty);
    expect(controller.state.searching, isFalse);
    verify(matchedHandle.close).called(1);
  });
}
