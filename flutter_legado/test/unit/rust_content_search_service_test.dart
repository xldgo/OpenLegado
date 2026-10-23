import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' show BridgeError;
import 'package:flutter_legado/src/bridge/content_search_bridge.dart' as bridge;
import 'package:flutter_legado/src/data/services/rust_content_search_service.dart';
import 'package:flutter_legado/src/domain/errors/app_exception.dart';

class _Api extends Mock implements RustLibApi {}

class _Handle extends Mock implements bridge.ContentSearchMatcher {}

void main() {
  late _Api api;
  setUp(() {
    api = _Api();
    RustLib.initMock(api: api);
  });
  tearDown(RustLib.dispose);
  test('正文原生句柄传参、UTF16摘要投影及释放，不重新匹配摘要', () async {
    const service = RustContentSearchService();
    final handle = _Handle();
    when(
      () => api.crateContentSearchBridgeContentSearchBegin(
        query: '(?<=章)甲',
        useRegex: true,
      ),
    ).thenAnswer((_) async => handle);
    when(() => handle.search(content: '章甲')).thenAnswer(
      (_) async => [
        bridge.ContentSearchHitDto(
          sourceStart: BigInt.from(100),
          sourceEnd: BigInt.from(101),
          snippet: '…甲…',
          highlightStart: BigInt.one,
          highlightEnd: BigInt.two,
        ),
      ],
    );
    when(handle.dispose).thenReturn(null);
    final matcher = (await service.open('(?<=章)甲', useRegex: true))!;
    final hit = (await matcher.search('章甲')).single;
    expect(
      (
        hit.sourceStart,
        hit.sourceEnd,
        hit.snippet,
        hit.highlightStart,
        hit.highlightEnd,
      ),
      (100, 101, '…甲…', 1, 2),
    );
    matcher.close();
    verify(handle.dispose).called(1);
    when(
      () => api.crateContentSearchBridgeContentSearchBegin(
        query: '[',
        useRegex: true,
      ),
    ).thenAnswer((_) async => null);
    expect(await service.open('[', useRegex: true), isNull);
    when(
      () => api.crateContentSearchBridgeContentSearchBegin(
        query: '故障',
        useRegex: false,
      ),
    ).thenThrow(const BridgeError(message: '传输失败'));
    await expectLater(
      service.open('故障', useRegex: false),
      throwsA(isA<AppException>()),
    );
  });
}
