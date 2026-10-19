import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/app/routing/startup_default_to_read.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';

import '../fixtures/app_test_api.dart';
import '../fixtures/home_settings_storage.dart';

/// 冷启动「默认进入阅读」目标解析（对齐上游 shouldApplyDefaultToRead）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Book?> resolve({
    required bool defaultToRead,
    List<Book> books = const [],
  }) async {
    final storage = HomeSettingsStorage()
      ..values['defaultToRead'] = defaultToRead;
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    final api = MockBookApi();
    for (final old in await api.bookshelfRepository.getBooks()) {
      await api.bookshelfRepository.deleteBook(old.bookUrl);
    }
    for (final book in books) {
      await api.bookshelfRepository.addBook(book);
    }
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        appSettingsServiceProvider.overrideWithValue(service),
      ]),
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);
    return container.read(startupDefaultToReadProvider.future);
  }

  test('开启时取最近阅读且读过正文的那本书', () async {
    final book = await resolve(
      defaultToRead: true,
      books: const [
        Book(bookUrl: 'a', name: '读了一点', durChapterTime: 10),
        Book(bookUrl: 'b', name: '最近在读', durChapterTime: 90),
        Book(bookUrl: 'c', name: '没读过', durChapterTime: 0),
      ],
    );
    expect(book?.bookUrl, 'b');
  });

  test('关闭时不做任何恢复', () async {
    final book = await resolve(
      defaultToRead: false,
      books: const [Book(bookUrl: 'b', name: '最近在读', durChapterTime: 90)],
    );
    expect(book, isNull);
  });

  test('没有读过正文的书时不恢复', () async {
    final book = await resolve(
      defaultToRead: true,
      books: const [Book(bookUrl: 'c', name: '没读过', durChapterTime: 0)],
    );
    expect(book, isNull);
  });
}
