import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/domain/contracts/general_settings_repository.dart';
import 'package:flutter_legado/src/domain/models/general_settings.dart';
import 'package:flutter_legado/src/features/reader/application/reader_exit_controller.dart';
import 'package:flutter_legado/src/models/book.dart';

class _Bookshelf extends Mock implements BookshelfRepository {}

class _Settings extends Mock implements GeneralSettingsRepository {}

void main() {
  const book = Book(
    bookUrl: 'fixture://book',
    name: '小说',
    bookType: BookType.notShelf,
  );
  late _Bookshelf bookshelf;
  late _Settings settings;
  late ReaderExitController controller;
  late Book? current;
  late bool active;
  late List<String> events;
  late List<Book> added;
  late List<String> messages;
  late Future<bool> Function(String) confirm;
  String? addError;

  setUp(() {
    bookshelf = _Bookshelf();
    settings = _Settings();
    current = book;
    active = true;
    events = [];
    added = [];
    messages = [];
    addError = null;
    confirm = (_) async => false;
    when(() => bookshelf.getBook(book.bookUrl)).thenAnswer((_) async => book);
    when(() => bookshelf.deleteBook(book.bookUrl)).thenAnswer((_) async {
      events.add('delete');
    });
    when(() => settings.load())
        .thenAnswer((_) async => const GeneralSettings());
    controller = ReaderExitController(
      host: ReaderExitHost(
        readBook: () => current,
        isActive: () => active,
        confirmAdd: (name) {
          events.add('confirm:$name');
          return confirm(name);
        },
        addBook: (value) async {
          events.add('add');
          added.add(value);
          return addError;
        },
        saveProgress: () async {
          events.add('save');
        },
        close: () => events.add('close'),
        notify: messages.add,
      ),
      bookshelf: bookshelf,
      settings: settings,
    );
    addTearDown(controller.dispose);
  });

  test('无书籍直接退出，不读取书架或设置', () async {
    current = null;
    await controller.requestExit();
    expect(events, ['close']);
    verifyZeroInteractions(bookshelf);
    verifyZeroInteractions(settings);
  });

  test('书架记录是权威，内存仍带未入架位时也先保存再退出', () async {
    when(() => bookshelf.getBook(book.bookUrl))
        .thenAnswer((_) async => book.copyWith(bookType: 0));
    await controller.requestExit();
    expect(events, ['save', 'close']);
    verifyZeroInteractions(settings);
    verifyNever(() => bookshelf.deleteBook(any()));
  });

  test('关闭入架提示时清理临时书后退出，不保存无主进度', () async {
    when(() => settings.load()).thenAnswer(
      (_) async => const GeneralSettings(showAddToShelfAlert: false),
    );
    await controller.requestExit();
    expect(events, ['delete', 'close']);
    expect(added, isEmpty);
  });

  test('确认入架清除未入架位，入架成功后保存并退出', () async {
    confirm = (_) async => true;
    await controller.requestExit();
    expect(events, ['confirm:小说', 'add', 'save', 'close']);
    expect(added.single.bookUrl, book.bookUrl);
    expect(added.single.bookType & BookType.notShelf, 0);
    verifyNever(() => bookshelf.deleteBook(any()));
  });

  test('取消或关闭确认框，删除临时记录后退出', () async {
    await controller.requestExit();
    expect(events, ['confirm:小说', 'delete', 'close']);
    expect(added, isEmpty);
  });

  test('入架失败留在阅读页并显示现有错误，之后可以重试', () async {
    confirm = (_) async => true;
    addError = '加入书架失败：写入失败';
    await controller.requestExit();
    expect(events, ['confirm:小说', 'add']);
    expect(messages, ['加入书架失败：写入失败']);
    addError = null;
    events.clear();
    await controller.requestExit();
    expect(events, ['confirm:小说', 'add', 'save', 'close']);
  });

  test('设置读取失败不能当作关闭提示，保留阅读页且不删除书籍', () async {
    when(() => settings.load()).thenThrow(StateError('读取失败'));
    await controller.requestExit();
    expect(events, isEmpty);
    expect(messages, ['读取返回入架设置失败，请重试']);
    verifyNever(() => bookshelf.deleteBook(any()));
  });

  test('临时记录清理失败仍沿用既有退出路径', () async {
    when(() => bookshelf.deleteBook(book.bookUrl))
        .thenThrow(StateError('删除失败'));
    await controller.requestExit();
    expect(events, ['confirm:小说', 'close']);
    expect(messages, isEmpty);
  });

  test('确认框在途不重复退出判定，页面销毁后不执行后续操作', () async {
    final pending = Completer<bool>();
    confirm = (_) => pending.future;
    final first = controller.requestExit();
    await Future<void>.delayed(Duration.zero);
    await controller.requestExit();
    expect(events, ['confirm:小说']);
    controller.dispose();
    active = false;
    pending.complete(true);
    await first;
    expect(events, ['confirm:小说']);
    expect(added, isEmpty);
    verify(() => bookshelf.getBook(book.bookUrl)).called(1);
  });
}
