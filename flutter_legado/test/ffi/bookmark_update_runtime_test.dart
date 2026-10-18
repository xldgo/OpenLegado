library;

/// 使用真实 FRB 绑定与 Windows DLL，验证书签更新不会删除后新增。
@Timeout(Duration(minutes: 3))
import 'dart:io';

import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/bridge/ffi.dart' show BridgeError;
import 'package:flutter_legado/src/bridge/transfer_dto.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/data/repositories/rust_bookmark_repository.dart';
import 'package:flutter_legado/src/domain/contracts/bookmark_repository.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;
import 'package:flutter_test/flutter_test.dart';

void main() {
  if (!Platform.isWindows) {
    test('书签真实 FFI 更新需要本地 Windows DLL', () {}, skip: '未提供 Windows DLL');
    return;
  }

  late BookmarkRepository repository;
  setUpAll(() async {
    final dll = File('../rust/target/debug/legado_ffi.dll')
        .resolveSymbolicLinksSync();
    await RustLib.init(externalLibrary: ExternalLibrary.open(dll));
    await bridge.init();
    final directory = Directory(
      '.dart_tool/bookmark-update-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    await bridge.dbOpen(path: '${directory.absolute.path}/bookmarks.db');
    final api = createTestApplication(useMock: false);
    repository = api.bookmarkRepository;
    expect(repository, isA<RustBookmarkRepository>());
    expect(api.bookmarkRepository, same(repository));
  });

  test('连续更新保留原 id、创建时间和其他书签', () async {
    final added = await repository.addBookmark(
      const Bookmark(bookName: '真实更新测试', bookText: '正文', content: '原备注'),
    );
    final other = await repository.addBookmark(
      const Bookmark(bookName: '真实更新测试', content: '其他书签'),
    );
    final before = await repository.getBookmarksByBook('真实更新测试', '');
    final original = before.singleWhere((b) => b.id == added.id);
    final untouched = before.singleWhere((b) => b.id == other.id);

    await repository.updateBookmark(
      added.copyWith(content: '新备注', chapterPos: 10),
    );
    await repository.updateBookmark(
      added.copyWith(content: '再次更新', chapterPos: 20),
    );
    final after = await repository.getBookmarksByBook('真实更新测试', '');
    expect(after.length, 2);
    expect(
      after.singleWhere((b) => b.id == added.id),
      original.copyWith(content: '再次更新', chapterPos: 20),
    );
    expect(after.singleWhere((b) => b.id == other.id), untouched);
  });

  test('强类型更新不存在的目标失败，原记录完整保留', () async {
    final before = await repository.getAllBookmarks();
    await expectLater(
      bridge.bookmarkUpdate(
        bookmark: BookmarkDto(
          id: 9007199254740993,
          time: 9007199254740993,
          bookName: '不存在😀',
          bookAuthor: '',
          chapterIndex: 0,
          chapterPos: 0,
          chapterName: '',
          bookText: '',
          content: '',
        ),
      ),
      throwsA(
        isA<BridgeError>().having(
          (error) => error.message,
          '精确 i64 ID',
          contains('9007199254740993'),
        ),
      ),
    );
    await expectLater(
      repository.updateBookmark(const Bookmark(id: -1, content: '不存在')),
      throwsA(
        isA<AppException>()
            .having((error) => error.cause, '桥接原因', isA<BridgeError>())
            .having((error) => error.message, '目标 ID', contains('-1')),
      ),
    );
    expect(await repository.getAllBookmarks(), before);
  });

  test('窄接口查询隔离同名书，搜索及删除仍访问同一原生存储', () async {
    final first = await repository.addBookmark(
      const Bookmark(
        bookName: '双键测试',
        bookAuthor: '甲',
        content: '甲的唯一备注',
        bookText: '甲😀e\u0301乙',
        chapterPos: 3,
        chapterName: '',
      ),
    );
    final second = await repository.addBookmark(
      const Bookmark(bookName: '双键测试', bookAuthor: '乙', content: '乙的唯一备注'),
    );
    final byAuthor = await repository.getBookmarksByBook('双键测试', '甲');
    expect(byAuthor.map((b) => b.id), [first.id]);
    expect(byAuthor.single.bookText, '甲😀e\u0301乙');
    expect(byAuthor.single.chapterPos, 3);
    expect(byAuthor.single.chapterName, isEmpty);
    final raw = await bridge.bookmarkGetAll(bookName: '双键测试');
    expect(raw.map((b) => b.id).toSet(), {first.id, second.id});
    expect(
      (await repository.getBookmarksByBook('双键测试', '乙')).map((b) => b.id),
      [second.id],
    );
    expect((await repository.searchBookmarks('甲的唯一备注')).map((b) => b.id), [
      first.id,
    ]);
    await repository.deleteBookmark(first.id);
    expect(await repository.getBookmarksByBook('双键测试', '甲'), isEmpty);
    expect(
      (await repository.getAllBookmarks()).any((b) => b.id == second.id),
      isTrue,
    );
  });
}
