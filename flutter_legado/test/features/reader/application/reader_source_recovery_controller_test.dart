import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/domain/contracts/book_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/reader_settings_repository.dart';
import 'package:flutter_legado/src/domain/contracts/source_switch_service.dart';
import 'package:flutter_legado/src/domain/models/reader_settings.dart';
import 'package:flutter_legado/src/features/reader/application/reader_source_recovery_controller.dart';
import 'package:flutter_legado/src/features/reader/application/reader_state.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Settings extends Mock implements ReaderSettingsRepository {}

class _Sources extends Mock implements BookSourceRepository {}

class _Switch extends Mock implements SourceSwitchService {}

void main() {
  const book = Book(
    bookUrl: 'https://book/1',
    name: '小说',
    author: '作者',
    origin: 'https://source/1',
    durChapterIndex: 4,
    durChapterPos: 2,
    durChapterTitle: '旧章名',
  );
  const target = SourceMatch(
    sourceUrl: 'https://source/2',
    sourceName: '新书源',
    bookUrl: 'https://new/book',
  );
  late _Settings settings;
  late _Sources sources;
  late _Switch service;
  late ReaderSourceRecoveryController controller;
  late ReaderState state;
  late List<Book> opened;
  late List<String> messages;
  late bool released;

  setUp(() {
    settings = _Settings();
    sources = _Sources();
    service = _Switch();
    state = const ReaderState(currentBook: book, error: '正文失败');
    opened = [];
    messages = [];
    released = false;
    when(() => settings.current)
        .thenReturn(const ReaderSettings(autoChangeSource: true));
    when(() => service.searchSource(any(), any())).thenAnswer((_) async => []);
    controller = ReaderSourceRecoveryController(
      host: ReaderSourceRecoveryHost(
        readState: () {
          if (released) throw StateError('宿主已经释放');
          return state;
        },
        openBook: (value) async {
          opened.add(value);
          state = state.copyWith(currentBook: value);
        },
        notify: messages.add,
      ),
      settings: settings,
      sources: sources,
      switchSource: service,
    );
    addTearDown(controller.dispose);
  });

  test('开关关闭、本地书、WebDAV书和无书籍不启动搜索', () async {
    when(() => settings.current)
        .thenReturn(const ReaderSettings(autoChangeSource: false));
    await controller.onChapterError(state);
    when(() => settings.current)
        .thenReturn(const ReaderSettings(autoChangeSource: true));
    for (final origin in [BookType.localTag, '${BookType.webDavTag}book']) {
      state = state.copyWith(currentBook: book.copyWith(origin: origin));
      await controller.onChapterError(state);
    }
    await controller.onChapterError(const ReaderState());
    verifyZeroInteractions(service);
  });

  test('沿用首个非同源候选及事务返回信息，保留原阅读进度', () async {
    when(() => service.searchSource(book.name, book.author)).thenAnswer(
      (_) async => [
        const SourceMatch(),
        SourceMatch(sourceUrl: book.origin),
        target,
        const SourceMatch(sourceUrl: 'https://source/3'),
      ],
    );
    when(
      () =>
          service.switchSource(book.bookUrl, target.sourceUrl, target.bookUrl),
    ).thenAnswer(
      (_) async => book.copyWith(
        origin: target.sourceUrl,
        originBookUrl: target.bookUrl,
        tocUrl: 'https://new/toc',
        durChapterIndex: 0,
        durChapterPos: 0,
        durChapterTitle: '新章名',
      ),
    );
    await controller.onChapterError(state);
    expect(opened, hasLength(1));
    expect(opened.single.origin, target.sourceUrl);
    expect(opened.single.originBookUrl, target.bookUrl);
    expect(opened.single.tocUrl, 'https://new/toc');
    expect(opened.single.durChapterIndex, 4);
    expect(opened.single.durChapterPos, 2);
    expect(opened.single.durChapterTitle, '旧章名');
    expect(messages, ['章节加载失败，已自动换源：新书源']);
    verify(
      () =>
          service.switchSource(book.bookUrl, target.sourceUrl, target.bookUrl),
    ).called(1);
  });

  test('无候选最多尝试三次，换书后重置计数', () async {
    for (var i = 0; i < 5; i++) {
      await controller.onChapterError(state);
    }
    verify(() => service.searchSource(book.name, book.author)).called(3);
    expect(messages, List.filled(3, '自动换源：无可用替代书源'));
    state = state.copyWith(
      currentBook: book.copyWith(bookUrl: 'https://book/2'),
    );
    await controller.onChapterError(state);
    verify(() => service.searchSource(book.name, book.author)).called(1);
  });

  test('搜索失败显示原失败提示，释放重入锁并允许重试', () async {
    when(() => service.searchSource(any(), any()))
        .thenThrow(StateError('搜索失败'));
    await controller.onChapterError(state);
    await controller.onChapterError(state);
    expect(messages, List.filled(2, '自动换源失败: Bad state: 搜索失败'));
    verify(() => service.searchSource(book.name, book.author)).called(2);
    expect(opened, isEmpty);
  });

  test('在途重复通知不重复搜索，设置读取采用当前共享值', () async {
    final pending = Completer<List<SourceMatch>>();
    when(() => service.searchSource(any(), any()))
        .thenAnswer((_) => pending.future);
    final first = controller.onChapterError(state);
    await controller.onChapterError(state);
    pending.complete([]);
    await first;
    when(() => settings.current)
        .thenReturn(const ReaderSettings(autoChangeSource: false));
    await controller.onChapterError(state);
    verify(() => service.searchSource(book.name, book.author)).called(1);
  });

  test('成功换源后重置重试次数', () async {
    await controller.onChapterError(state);
    await controller.onChapterError(state);
    when(() => service.searchSource(any(), any()))
        .thenAnswer((_) async => [target]);
    when(
      () =>
          service.switchSource(book.bookUrl, target.sourceUrl, target.bookUrl),
    ).thenAnswer((_) async => book.copyWith(origin: target.sourceUrl));
    await controller.onChapterError(state);
    when(() => service.searchSource(any(), any())).thenAnswer((_) async => []);
    await controller.onChapterError(state);
    expect(opened, hasLength(1));
    expect(messages.last, '自动换源：无可用替代书源');
    verify(() => service.searchSource(book.name, book.author)).called(4);
  });

  test('切换失败不重开书籍，也不会发布成功提示', () async {
    when(() => service.searchSource(any(), any()))
        .thenAnswer((_) async => [target]);
    when(
      () =>
          service.switchSource(book.bookUrl, target.sourceUrl, target.bookUrl),
    ).thenThrow(StateError('切换失败'));
    await controller.onChapterError(state);
    expect(opened, isEmpty);
    expect(state.currentBook, book);
    expect(messages.single, '自动换源失败: Bad state: 切换失败');
  });

  test('销毁后迟到搜索不访问宿主、不切换或通知', () async {
    final pending = Completer<List<SourceMatch>>();
    when(() => service.searchSource(any(), any()))
        .thenAnswer((_) => pending.future);
    final operation = controller.onChapterError(state);
    controller.dispose();
    released = true;
    pending.complete([target]);
    await operation;
    expect(messages, isEmpty);
    expect(opened, isEmpty);
    verifyNever(() => service.switchSource(any(), any(), any()));
  });

  test('查找当前书源交给登录弹层，过期书籍不返回登录数据', () async {
    final source = BookSource(
      bookSourceUrl: book.origin,
      loginUrl: 'https://login',
    );
    when(() => sources.getBookSources()).thenAnswer((_) async => [source]);
    expect(await controller.findLoginSource(book), source);
    final pending = Completer<List<BookSource>>();
    when(() => sources.getBookSources()).thenAnswer((_) => pending.future);
    final finding = controller.findLoginSource(book);
    state = state.copyWith(
      currentBook: book.copyWith(bookUrl: 'https://book/2'),
    );
    pending.complete([source]);
    expect(await finding, isNull);
    verifyZeroInteractions(service);
  });
}
