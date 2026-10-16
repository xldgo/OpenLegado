library;

/// 真实 Windows FRB 与临时数据库验证，不使用用户数据库。— Codex + Bridge
@Timeout(Duration(minutes: 3))
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' as privacy;
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/data/repositories/rust_book_group_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_bookshelf_repository.dart';
import 'package:flutter_legado/src/models/models.dart';

void main() {
  if (!Platform.isWindows) {
    test('隐私真实 FFI 需要 Windows DLL', () {}, skip: '当前平台不提供该原生夹具');
    return;
  }
  late Directory directory;
  setUpAll(() async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        File('../rust/target/debug/legado_ffi.dll').resolveSymbolicLinksSync(),
      ),
    );
    await bridge.init();
    directory = Directory(
      '.dart_tool/privacy-runtime-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    await bridge.dbOpen(path: '${directory.absolute.path}/privacy.db');
  });
  test('真实密码校验与旧密码保护，清除后不保留可用凭据', () async {
    expect(await privacy.privacyHasPassword(), isFalse);
    expect(
      await privacy.privacySetPassword(currentPassword: '', password: '原口令'),
      isTrue,
    );
    expect(await privacy.privacyVerifyPassword(password: '错误'), isFalse);
    expect(
      await privacy.privacySetPassword(currentPassword: '错误', password: ''),
      isFalse,
    );
    expect(await privacy.privacyVerifyPassword(password: '原口令'), isTrue);
    expect(
      await privacy.privacySetPassword(currentPassword: '原口令', password: '新口令'),
      isTrue,
    );
    expect(await privacy.privacyVerifyPassword(password: '原口令'), isFalse);
    expect(
      await privacy.privacySetPassword(currentPassword: '新口令', password: ''),
      isTrue,
    );
    expect(await privacy.privacyHasPassword(), isFalse);
  });
  test('私密书籍与分组标记穿过真实增改查，普通字段修改不清除标记', () async {
    const shelf = RustBookshelfRepository(), groups = RustBookGroupRepository();
    var group = await groups.addBookGroup(
      const BookGroup(groupName: '私密组', isPrivate: true),
    );
    var book = await shelf.addBook(
      Book(
        bookUrl: 'privacy://book/1',
        name: '私密测试书',
        author: '测试作者',
        group: group.groupId,
        isPrivate: true,
      ),
    );
    expect((await shelf.getBook(book.bookUrl))!.isPrivate, isTrue);
    expect(
      (await groups.getBookGroups())
          .singleWhere((g) => g.groupId == group.groupId)
          .isPrivate,
      isTrue,
    );
    group = group.copyWith(groupName: '修改组名');
    await groups.updateBookGroup(group);
    book = book.copyWith(customTag: '修改标签');
    await shelf.updateBook(book);
    expect((await shelf.getBook(book.bookUrl))!.isPrivate, isTrue);
    expect(
      (await groups.getBookGroups())
          .singleWhere((g) => g.groupId == group.groupId)
          .isPrivate,
      isTrue,
    );
    await shelf.updateBook(book.copyWith(isPrivate: false));
    expect((await shelf.getBook(book.bookUrl))!.isPrivate, isFalse);
  });
}
