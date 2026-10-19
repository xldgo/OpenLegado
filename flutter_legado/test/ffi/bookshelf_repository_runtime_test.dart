library;

/// 真实宿主 FFI 复核直接书架与分组适配，共用独立数据库。— Codex + Bridge
@Timeout(Duration(minutes: 3))
import '../helpers/native_ffi.dart';

import 'dart:convert';
import 'dart:io';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('书架读写、进度、排序、分组及导入直接适配共享同一数据库', () async {
    SharedPreferences.setMockInitialValues({});
    final root = Directory(
      '.dart_tool/bookshelf-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final api = createTestApplication(
      useMock: false,
      bootstrap: RustBootstrap(
        runtime: nativeTestRuntime(),
        environment: _Environment(root.absolute.path),
        configurationSource: SettingsRuntimeConfiguration(),
      ),
    );
    await initializeTestApplication(api: api);
    final shelf = api.bookshelfRepository;
    final groups = api.bookGroupRepository;
    expect(await shelf.getBook('不存在'), isNull);
    final group = await groups.addBookGroup(
      const BookGroup(groupName: '真实分组', order: 3),
    );
    await groups.updateBookGroup(
      group.copyWith(groupName: '已更新', cover: 'cover', order: 5, show: false),
    );
    final storedGroup = (await groups.getBookGroups()).firstWhere(
      (g) => g.groupId == group.groupId,
    );
    expect(storedGroup.groupName, '已更新');
    expect(storedGroup.order, 5);
    // 原更新只透传名称/封面/顺序，显隐使用独立入口。
    expect(storedGroup.show, isTrue);
    expect(await groups.bookGroupSetShow(group.groupId, false), isTrue);
    expect(
      (await groups.getBookGroups())
          .firstWhere((g) => g.groupId == group.groupId)
          .show,
      isFalse,
    );
    const book = Book(
      bookUrl: 'fixture://a',
      name: '真实书籍',
      author: '作者',
      order: 7,
    );
    final added = await shelf.addBook(book);
    expect(added.bookUrl, book.bookUrl);
    await api.readingRepository.updateReadingProgress(
      bookUrl: book.bookUrl,
      chapterIndex: 2,
      chapterPos: 201,
    );
    final positioned = (await shelf.getBook(book.bookUrl))!;
    expect(positioned.durChapterIndex, 2);
    expect(positioned.durChapterPos, 201);
    await shelf.updateBook(positioned.copyWith(name: '已更新书籍'));
    expect((await shelf.getBook(book.bookUrl))!.name, '已更新书籍');
    await shelf.setBookGroup(book.bookUrl, group.groupId);
    expect((await shelf.getBook(book.bookUrl))!.group, group.groupId);
    await shelf.topBook(book.bookUrl);
    expect((await shelf.getBook(book.bookUrl))!.order, -1);
    await shelf.unTopBook(book.bookUrl);
    expect((await shelf.getBook(book.bookUrl))!.order, 0);
    await shelf.importBooks(
      jsonEncode([
        book.copyWith(bookUrl: 'fixture://b', name: '导入书籍').toJson(),
      ]),
    );
    await shelf.reorderBooks([
      {'bookUrl': book.bookUrl, 'order': 8},
      {'bookUrl': 'fixture://b', 'order': 1},
    ]);
    expect((await shelf.getBook(book.bookUrl))!.order, 8);
    expect((await shelf.getBook('fixture://b'))!.order, 1);
    final before = await shelf.getBooks();
    await expectLater(shelf.importBooks('坏JSON'), throwsA(anything));
    expect(await shelf.getBooks(), before);
    await groups.deleteBookGroup(group.groupId);
    expect(
      (await groups.getBookGroups()).any((g) => g.groupId == group.groupId),
      isFalse,
    );
    await shelf.deleteBook(book.bookUrl);
    await shelf.deleteBook('fixture://b');
    expect(await shelf.getBook(book.bookUrl), isNull);
    await api.runtime.initialize();
    expect(api.bookshelfRepository, same(shelf));
    expect(api.bookGroupRepository, same(groups));
  });
}

class _Environment implements AppEnvironment {
  _Environment(this.root);
  final String root;
  @override
  Future<String> databasePath() async =>
      '$root${Platform.pathSeparator}legado.db';
  @override
  Future<void> warmLocalBookStore() async {}
  @override
  Future<String> cacheDirectory(RuntimeCache cache) async =>
      (await Directory('$root${Platform.pathSeparator}${cache.name}')
              .create(recursive: true))
          .path;
  @override
  Future<String?> deviceId() async => 'bookshelf-fixture';
}
