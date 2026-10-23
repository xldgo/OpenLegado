import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' as ffi;
import 'package:flutter_legado/src/bridge/content_search_bridge.dart' as bridge;
import 'package:flutter_legado/src/data/services/rust_content_search_service.dart';
import 'package:flutter_legado/src/domain/contracts/content_search_service.dart';
import 'package:flutter_legado/src/domain/errors/app_exception.dart';

class _Api extends Mock implements RustLibApi {}

class _Request extends Mock implements ffi.StreamRequest {}

void main() {
  late _Api api;
  setUpAll(() {
    registerFallbackValue(
      bridge.ContentSearchOptionsDto(
        bookUrl: '',
        query: '',
        useRegex: false,
        useReplace: false,
        scope: bridge.ContentSearchScopeDto.network,
        currentChapterIndex: 0,
      ),
    );
    registerFallbackValue(_Request());
  });
  setUp(() {
    api = _Api();
    RustLib.initMock(api: api);
  });
  tearDown(RustLib.dispose);
  test('选项/增量批次映射与独立订阅取消；启动错误转换并释放凭据', () async {
    const service = RustContentSearchService();
    final requests = [_Request(), _Request()];
    for (final r in requests) {
      when(r.cancel).thenReturn(null);
      when(r.dispose).thenReturn(null);
    }
    var index = 0;
    when(api.crateFfiStreamRequestNew).thenAnswer((_) => requests[index++]);
    final input = StreamController<bridge.ContentSearchBatchDto>();
    when(
      () => api.crateContentSearchBridgeContentSearch(
        options: any(named: 'options'),
        request: requests[0],
      ),
    ).thenAnswer((_) => input.stream);
    final received = <ContentSearchBatch>[];
    final sub = service
        .search(
          bookUrl: 'book',
          query: '甲',
          useRegex: true,
          useReplace: false,
          scope: ContentSearchScope.cached,
          currentChapterIndex: 7,
        )
        .listen(received.add);
    input.add(
      bridge.ContentSearchBatchDto(
        chapterIndex: 7,
        chapterTitle: '第八章',
        scanned: BigInt.from(8),
        total: BigInt.from(10),
        error: '单章错误',
        limitReached: true,
        hits: [
          bridge.ContentSearchHitDto(
            sourceStart: BigInt.from(40),
            sourceEnd: BigInt.from(41),
            snippet: '…甲…',
            highlightStart: BigInt.one,
            highlightEnd: BigInt.two,
          ),
        ],
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final options =
        verify(
              () => api.crateContentSearchBridgeContentSearch(
                options: captureAny(named: 'options'),
                request: requests[0],
              ),
            ).captured.single
            as bridge.ContentSearchOptionsDto;
    expect(
      (
        options.bookUrl,
        options.query,
        options.useRegex,
        options.useReplace,
        options.scope,
        options.currentChapterIndex,
      ),
      ('book', '甲', true, false, bridge.ContentSearchScopeDto.cached, 7),
    );
    final event = received.single;
    final hit = event.hits.single;
    expect(
      (
        event.chapterIndex,
        event.chapterTitle,
        event.scanned,
        event.total,
        event.error,
        event.limitReached,
      ),
      (7, '第八章', 8, 10, '单章错误', true),
    );
    expect(
      (
        hit.sourceStart,
        hit.sourceEnd,
        hit.snippet,
        hit.highlightStart,
        hit.highlightEnd,
      ),
      (40, 41, '…甲…', 1, 2),
    );
    await sub.cancel();
    verify(requests[0].cancel).called(1);
    verify(requests[0].dispose).called(1);
    await input.close();
    when(
      () => api.crateContentSearchBridgeContentSearch(
        options: any(named: 'options'),
        request: requests[1],
      ),
    ).thenThrow(const ffi.BridgeError(message: '传输失败'));
    await expectLater(
      service.search(
        bookUrl: 'book',
        query: '故障',
        useRegex: false,
        useReplace: true,
        scope: ContentSearchScope.network,
        currentChapterIndex: 0,
      ),
      emitsError(isA<AppException>()),
    );
    verify(requests[1].dispose).called(1);
  });
}
