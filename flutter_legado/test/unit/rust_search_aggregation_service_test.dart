import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' as bridge;
import 'package:flutter_legado/src/bridge/search_aggregate_dto.dart';
import 'package:flutter_legado/src/data/services/rust_search_aggregation_service.dart';
import 'package:flutter_legado/src/domain/errors/app_exception.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Api extends Mock implements RustLibApi {}

class _Handle extends Mock implements bridge.SearchAggregation {}

void main() {
  late _Api api;
  setUpAll(() => registerFallbackValue(<SearchAggregateInputDto>[]));
  setUp(() {
    api = _Api();
    RustLib.initMock(api: api);
  });
  tearDown(RustLib.dispose);
  test('按序追加快照和释放，只用首条完整对象合并原生投影', () async {
    final handle = _Handle();
    when(() => api.crateFfiSearchAggregationBegin(keyword: '甲'))
        .thenAnswer((_) async => handle);
    final added = Completer<List<SearchAggregateRetainedDto>>();
    when(() => handle.add(books: any(named: 'books')))
        .thenAnswer((_) => added.future);
    when(() => handle.snapshot(keepOther: false)).thenAnswer(
      (_) async => [
        SearchAggregateResultDto(
          representativeId: BigInt.from(9),
          name: '归一书名',
          author: '归一作者',
          origins: ['a', 'b'],
          hasReadRecord: true,
        ),
      ],
    );
    when(handle.close).thenAnswer((_) async {});
    final session = const RustSearchAggregationService().open('甲');
    const first = SearchResult(
      book: Book(
        name: '原书名',
        author: '原作者',
        bookUrl: 'first',
        origin: 'a',
        variable: '保留书级变量',
        totalChapterNum: 42,
      ),
      sourceName: '首源',
    );
    final append = session.addAll([
      first,
      const SearchResult(
        book: Book(name: '后到元数据', origin: 'b'),
      ),
    ]);
    final snapshot = session.snapshot(keepOther: false);
    final closing = session.close();
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => handle.snapshot(keepOther: false));
    verifyNever(handle.close);
    added.complete([
      SearchAggregateRetainedDto(
        inputIndex: BigInt.zero,
        representativeId: BigInt.from(9),
      ),
    ]);
    await append;
    final out = (await snapshot).single;
    expect(out.book, first.book.copyWith(name: '归一书名', author: '归一作者'));
    expect((out.sourceName, out.hasReadRecord), ('首源', true));
    expect(out.origins.toList(), ['a', 'b']);
    await closing;
    verify(handle.close).called(1);
    await expectLater(session.addAll([]), throwsStateError);
  });
  test('创建失败正常上抛，释放失败不偷偷重建查询', () async {
    when(() => api.crateFfiSearchAggregationBegin(keyword: '失败'))
        .thenThrow(const bridge.BridgeError(message: '聚合失败'));
    final session = const RustSearchAggregationService().open('失败');
    await expectLater(session.snapshot(), throwsA(isA<AppException>()));
    await expectLater(session.close(), throwsA(isA<AppException>()));
    verify(() => api.crateFfiSearchAggregationBegin(keyword: '失败')).called(1);
  });
}
