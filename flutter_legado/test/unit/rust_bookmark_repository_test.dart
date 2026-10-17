import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/bridge/transfer_dto.dart';
import 'package:flutter_legado/src/data/repositories/rust_bookmark_repository.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  const repository = RustBookmarkRepository();
  late _Bridge bridge;
  final dto = BookmarkDto(
    id: 9007199254740993,
    time: 9223372036854775806,
    bookName: '书😀',
    bookAuthor: '',
    chapterIndex: 7,
    chapterPos: 3,
    chapterName: '章节',
    bookText: '甲😀e\u0301乙',
    content: '备注\n第二行',
  );
  final model = Bookmark(
    id: dto.id,
    time: dto.time,
    bookName: dto.bookName,
    bookAuthor: dto.bookAuthor,
    chapterIndex: dto.chapterIndex,
    chapterPos: dto.chapterPos,
    chapterName: dto.chapterName,
    bookText: dto.bookText,
    content: dto.content,
  );

  setUpAll(() => registerFallbackValue(dto));
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('三种查询完整映射 DTO，大 ID 与时间不经浮点转换', () async {
    when(() => bridge.crateFfiFfiBookmarkList()).thenAnswer((_) async => [dto]);
    when(
      () =>
          bridge.crateFfiFfiGetBookmarksByBook(bookName: '书😀', bookAuthor: ''),
    ).thenAnswer((_) async => [dto]);
    when(() => bridge.crateFfiFfiBookmarkSearch(keyword: '备注'))
        .thenAnswer((_) async => [dto]);
    expect(await repository.getAllBookmarks(), [model]);
    expect(await repository.getBookmarksByBook('书😀', ''), [model]);
    expect(await repository.searchBookmarks('备注'), [model]);
    final first = await repository.getAllBookmarks();
    first.clear();
    expect(await repository.getAllBookmarks(), [model]);
    when(() => bridge.crateFfiFfiBookmarkList()).thenAnswer((_) async => []);
    expect(await repository.getAllBookmarks(), isEmpty);
  });

  test('更新将所有字段直接映射到 DTO，保留底层 void 语义', () async {
    when(
      () => bridge.crateFfiFfiBookmarkUpdate(bookmark: any(named: 'bookmark')),
    ).thenAnswer((_) async {});
    await repository.updateBookmark(model);
    final sent =
        verify(
              () => bridge.crateFfiFfiBookmarkUpdate(
                bookmark: captureAny(named: 'bookmark'),
              ),
            ).captured.single
            as BookmarkDto;
    expect(sent, dto);
    verifyNoMoreInteractions(bridge);
  });

  test('新增仍传原标量参数，返回 ID；删除使用精确 i64', () async {
    when(
      () => bridge.crateFfiFfiBookmarkAdd(
        bookName: dto.bookName,
        bookAuthor: dto.bookAuthor,
        chapterIndex: dto.chapterIndex,
        chapterPos: dto.chapterPos,
        chapterName: dto.chapterName,
        bookText: dto.bookText,
        content: dto.content,
      ),
    ).thenAnswer((_) async => dto.id);
    expect(await repository.addBookmark(model.copyWith(id: 0)), model);
    when(() => bridge.crateFfiFfiBookmarkDelete(bookmarkId: dto.id))
        .thenAnswer((_) async {});
    await repository.deleteBookmark(dto.id);
    verify(() => bridge.crateFfiFfiBookmarkDelete(bookmarkId: dto.id))
        .called(1);
  });

  test('查询和更新失败原样传播，不返回缓存或空数据', () async {
    final failure = StateError('数据库失败');
    when(() => bridge.crateFfiFfiBookmarkList())
        .thenAnswer((_) async => throw failure);
    when(
      () =>
          bridge.crateFfiFfiGetBookmarksByBook(bookName: '书😀', bookAuthor: ''),
    ).thenAnswer((_) async => throw failure);
    when(() => bridge.crateFfiFfiBookmarkSearch(keyword: '备注'))
        .thenAnswer((_) async => throw failure);
    when(
      () => bridge.crateFfiFfiBookmarkUpdate(bookmark: any(named: 'bookmark')),
    ).thenAnswer((_) async => throw failure);
    await expectLater(repository.getAllBookmarks(), throwsA(same(failure)));
    await expectLater(
      repository.getBookmarksByBook('书😀', ''),
      throwsA(same(failure)),
    );
    await expectLater(repository.searchBookmarks('备注'), throwsA(same(failure)));
    await expectLater(repository.updateBookmark(model), throwsA(same(failure)));
  });
}
