import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/bridge/entity_dto_mapping.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' show BridgeError;
import 'package:flutter_legado/src/bridge/transfer_dto.dart';
import 'package:flutter_legado/src/data/services/rust_book_source_query_service.dart';
import 'package:flutter_legado/src/domain/errors/app_exception.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  const service = RustBookSourceQueryService();
  late _Bridge bridge;
  setUpAll(
    () => registerFallbackValue(
      bookSourceToDto(
        const BookSource(
          bookSourceUrl: 'https://source.test',
          bookSourceName: '源',
        ),
      ),
    ),
  );
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('识别端口完整传递源上下文与既有类型，返回值不在Dart重新判断', () async {
    const source = BookSource(
      bookSourceUrl: 'https://source.test',
      bookSourceName: '源',
      bookSourceGroup: '分组',
      bookSourceType: 2,
      searchUrl: '/search',
      exploreUrl: '/explore',
      ruleToc: TocRule(chapterList: '.chapters'),
      ruleContent: ContentRule(
        content: '.content',
        sourceRegex: 'regex',
        imageStyle: 'FULL',
      ),
    );
    when(
      () => bridge.crateFfiFfiBookResolveReadingType(
        bookType: BookType.text | BookType.notShelf,
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async => BookType.video);
    expect(
      await service.resolveReadingType(
        BookType.text | BookType.notShelf,
        source,
      ),
      BookType.video,
    );
    final sent =
        verify(
              () => bridge.crateFfiFfiBookResolveReadingType(
                bookType: BookType.text | BookType.notShelf,
                source: captureAny(named: 'source'),
              ),
            ).captured.single
            as BookSourceDto;
    expect(
      [
        sent.bookSourceUrl,
        sent.bookSourceName,
        sent.bookSourceGroup,
        sent.bookSourceType,
        sent.searchUrl,
        sent.exploreUrl,
      ],
      ['https://source.test', '源', '分组', 2, '/search', '/explore'],
    );
    expect(sent.ruleToc!.chapterList, '.chapters');
    expect(
      [
        sent.ruleContent!.content,
        sent.ruleContent!.sourceRegex,
        sent.ruleContent!.imageStyle,
      ],
      ['.content', 'regex', 'FULL'],
    );
  });

  test('无源也交由同一端口处理，失败转换领域错误', () async {
    when(
      () => bridge.crateFfiFfiBookResolveReadingType(
        bookType: BookType.local,
        source: null,
      ),
    ).thenAnswer((_) async => 0);
    expect(await service.resolveReadingType(BookType.local, null), 0);
    when(
      () => bridge.crateFfiFfiBookResolveReadingType(
        bookType: BookType.local,
        source: null,
      ),
    ).thenThrow(const BridgeError(message: '桥接失败'));
    await expectLater(
      service.resolveReadingType(BookType.local, null),
      throwsA(isA<AppException>()),
    );
  });
}
