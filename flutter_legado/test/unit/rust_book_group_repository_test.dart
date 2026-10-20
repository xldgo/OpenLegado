// 分组类型化列表保留原六字段与领域默认值。— Codex + Bridge
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/bridge/transfer_dto.dart';
import 'package:flutter_legado/src/data/repositories/rust_book_group_repository.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const repository = RustBookGroupRepository();
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('分组快照保留排序、隐私、空封面与未返回字段默认值', () async {
    when(() => bridge.crateFfiFfiBookGroupList()).thenAnswer(
      (_) async => [
        const BookGroupDto(
          groupId: 9007199254740993,
          groupName: '分组😀',
          cover: null,
          order: -7,
          show_: false,
          isPrivate: true,
        ),
        const BookGroupDto(
          groupId: 1,
          groupName: '另一组',
          cover: 'cover://1',
          order: 3,
          show_: true,
          isPrivate: false,
        ),
      ],
    );
    expect(await repository.getBookGroups(), [
      const BookGroup(
        groupId: 9007199254740993,
        groupName: '分组😀',
        order: -7,
        show: false,
        isPrivate: true,
      ),
      const BookGroup(
        groupId: 1,
        groupName: '另一组',
        cover: 'cover://1',
        order: 3,
      ),
    ]);
    when(() => bridge.crateFfiFfiBookGroupList()).thenAnswer((_) async => []);
    expect(await repository.getBookGroups(), isEmpty);
    verify(() => bridge.crateFfiFfiBookGroupList()).called(2);
  });

  test('新增与更新沿用标量参数，新增只替换实际主键', () async {
    const group = BookGroup(
      groupId: -1,
      groupName: '私密',
      isPrivate: true,
      order: -2,
      show: false,
      enableRefresh: false,
      bookSort: 4,
      onlyUpdateRead: true,
    );
    when(
      () => bridge.crateFfiFfiBookGroupAdd(
        groupName: '私密',
        cover: '',
        order: -2,
        isPrivate: true,
      ),
    ).thenAnswer((_) async => 17);
    final added = await repository.addBookGroup(group);
    expect(added, group.copyWith(groupId: 17));
    when(
      () => bridge.crateFfiFfiBookGroupUpdate(
        id: 17,
        groupName: '私密',
        cover: '',
        order: -2,
        isPrivate: true,
      ),
    ).thenAnswer((_) async => false);
    await repository.updateBookGroup(added);
    verify(
      () => bridge.crateFfiFfiBookGroupUpdate(
        id: 17,
        groupName: '私密',
        cover: '',
        order: -2,
        isPrivate: true,
      ),
    ).called(1);
  });

  test('查询失败上抛，显示更新保留false', () async {
    final error = StateError('数据库不可用');
    when(() => bridge.crateFfiFfiBookGroupList()).thenThrow(error);
    await expectLater(repository.getBookGroups(), throwsA(same(error)));
    when(() => bridge.crateFfiFfiBookGroupSetShow(id: 17, show_: false))
        .thenAnswer((_) async => false);
    expect(await repository.bookGroupSetShow(17, false), false);
  });
}
