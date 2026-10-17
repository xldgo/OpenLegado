import 'dart:async';

import 'package:flutter_legado/src/bridge/ffi.dart' show BridgeError;
import 'package:flutter_legado/src/data/services/chapter_content_service.dart';
import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_record_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_record_settings_repository.dart';
import 'package:flutter_legado/src/domain/contracts/reading_repository.dart';
import 'package:flutter_legado/src/domain/models/read_record_settings.dart';
import 'package:flutter_legado/src/features/reader/application/reader_session_controller.dart';
import 'package:flutter_legado/src/features/reader/application/reader_session_host.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/reader/application/reader_state.dart';
import 'package:flutter_legado/src/services/reader_position_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Reading extends Mock implements ReadingRepository {}

class _Bookshelf extends Mock implements BookshelfRepository {}

class _Content extends Mock implements ChapterContentService {}

class _Records extends Mock implements ReadRecordRepository {}

class _RecordSettings extends Mock implements ReadRecordSettingsRepository {}

void main() {
  const book = Book(
    bookUrl: 'https://book/1',
    name: '测试小说',
    author: '作者',
    origin: 'https://source/1',
  );
  const chapters = [
    BookChapter(url: 'https://chapter/0', title: '第一章', index: 0),
    BookChapter(url: 'https://chapter/1', title: '第二章', index: 1),
    BookChapter(url: 'https://chapter/2', title: '第三章', index: 2),
  ];
  late _Reading reading;
  late _Bookshelf bookshelf;
  late _Content content;
  late _Records records;
  late _RecordSettings settings;
  late ReaderSessionController controller;
  late ReaderPositionStore positions;
  late ReaderState state;
  late int clock;
  late int resets;
  late bool released;

  setUpAll(() => registerFallbackValue(const ReadRecord()));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    reading = _Reading();
    bookshelf = _Bookshelf();
    content = _Content();
    records = _Records();
    settings = _RecordSettings();
    positions = ReaderPositionStore();
    state = const ReaderState();
    clock = 10000;
    resets = 0;
    released = false;
    when(() => reading.getChapters(any())).thenAnswer((_) async => chapters);
    when(() => content.read(any(), any()))
        .thenAnswer((call) async => '正文${call.positionalArguments[1]}' * 30);
    when(() => settings.load())
        .thenAnswer((_) async => const ReadRecordSettings(enableRecord: false));
    when(
      () => reading.updateReadingProgress(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
        chapterPos: any(named: 'chapterPos'),
      ),
    ).thenAnswer((_) async {});
    controller = ReaderSessionController(
      host: ReaderSessionHost(
        readState: () {
          if (released) throw StateError('宿主已经释放');
          return state;
        },
        writeState: (next) {
          if (released) throw StateError('宿主已经释放');
          state = next;
        },
        resetPagination: () => resets++,
      ),
      reading: reading,
      bookshelf: bookshelf,
      content: content,
      records: records,
      recordSettings: settings,
      positionStore: positions,
      clock: () => clock,
    );
    addTearDown(controller.dispose);
  });

  test('无Provider开书，换书清旧内容与分页，保留表现层设置', () async {
    state = state.copyWith(fontSize: 26, showControls: true);
    await controller.openBook(book);
    expect(state.currentBook, book);
    expect(state.chapters, chapters);
    expect(state.chapterContent, '正文0' * 30);
    expect(state.isLoading, isFalse);
    expect(state.showControls, isFalse);
    expect(state.fontSize, 26);
    expect(resets, 1);
    await controller.openBook(book);
    expect(resets, 1);
    verifyNever(() => reading.refreshToc(any(), any()));
  });

  test('本地目录为空才拉取网络目录，章节越界回到章首', () async {
    when(() => reading.getChapters(book.bookUrl)).thenAnswer((_) async => []);
    when(() => reading.refreshToc(book.bookUrl, book.origin))
        .thenAnswer((_) async => chapters);
    await controller.openBook(book.copyWith(durChapterIndex: 99));
    expect(state.currentChapterIndex, 0);
    expect(state.chapterContent, '正文0' * 30);
    verify(() => reading.refreshToc(book.bookUrl, book.origin)).called(1);
  });

  test('正文错误使用原错误文案，重新加载成功清除错误', () async {
    when(() => content.read(book.bookUrl, 0))
        .thenThrow(const BridgeError(message: '读取失败'));
    await controller.openBook(book);
    expect(state.error, '读取失败');
    expect(state.chapterContent, isEmpty);
    when(() => content.read(book.bookUrl, 0)).thenAnswer((_) async => '恢复正文');
    await controller.reloadChapterContent();
    expect(state.error, isNull);
    expect(state.chapterContent, '恢复正文');
  });

  test('保存并重开恢复原文锚点，读取宿主的最新设置与书籍字段', () async {
    await controller.openBook(book);
    state = state.copyWith(fontSize: 25);
    controller.updateCurrentBook(book.copyWith(author: '已编辑作者'));
    controller.updatePosition(3, sourceOffset: 20);
    expect(state.fontSize, 25);
    expect(state.currentBook!.author, '已编辑作者');
    expect(state.currentBook!.durChapterPos, 3);
    await controller.saveProgress();
    expect(
      (await positions.read(book.bookUrl, chapterIndex: 0))!.sourceOffset,
      20,
    );
    await controller.openBook(state.currentBook!);
    expect(state.currentChapterPos, 0);
    expect(controller.currentSourceOffset, 20);
    await controller.applyBookProgress(chapterIndex: 0);
    expect(controller.currentSourceOffset, isNull);
    expect(await positions.read(book.bookUrl, chapterIndex: 0), isNull);
  });

  test('上一章末页哨兵只留在页面状态，不写入书籍或仓储', () async {
    await controller.openBook(book.copyWith(durChapterIndex: 1));
    await controller.prevChapter();
    expect(state.currentChapterIndex, 0);
    expect(state.currentChapterPos, -1);
    expect(state.currentBook!.durChapterPos, 0);
    verifyNever(
      () => reading.updateReadingProgress(
        bookUrl: book.bookUrl,
        chapterIndex: any(named: 'chapterIndex'),
        chapterPos: -1,
      ),
    );
    controller.resetChapterPos();
    expect(state.currentChapterPos, 0);
  });

  test('全局页解析由宿主提供，同章翻页不重新加载正文', () async {
    await controller.openBook(book);
    await controller.goToPage(chapterIndex: 0, pageIndex: 2, globalIndex: 2);
    expect(state.currentChapterPos, 2);
    verify(() => content.read(book.bookUrl, 0)).called(1);
    await controller.goToPage(chapterIndex: 1, pageIndex: 1, globalIndex: 5);
    expect(state.currentChapterIndex, 1);
    expect(state.globalPageIndex, 5);
    expect(state.currentBook!.durChapterTitle, '第二章');
    verify(() => content.read(book.bookUrl, 1)).called(1);
  });

  test('先打开的慢书籍目录不会覆盖后打开的书籍', () async {
    final pending = Completer<List<BookChapter>>();
    when(() => reading.getChapters(book.bookUrl))
        .thenAnswer((_) => pending.future);
    final first = controller.openBook(book);
    await Future<void>.delayed(Duration.zero);
    final second = book.copyWith(bookUrl: 'https://book/2');
    await controller.openBook(second);
    pending.complete(chapters.reversed.toList());
    await first;
    expect(state.currentBook, second);
    expect(state.chapters, chapters);
    verifyNever(() => content.read(book.bookUrl, any()));
  });

  test('连续切章只发布最后一章，先发结果不能覆盖设置或正文', () async {
    await controller.openBook(book);
    final pending = Completer<String>();
    final entered = Completer<void>();
    when(() => content.read(book.bookUrl, 1)).thenAnswer((_) {
      entered.complete();
      return pending.future;
    });
    final first = controller.nextChapter();
    await entered.future;
    await controller.nextChapter();
    state = state.copyWith(fontSize: 28);
    pending.complete('过期第二章');
    await first;
    expect(state.currentChapterIndex, 2);
    expect(state.chapterContent, '正文2' * 30);
    expect(state.fontSize, 28);
    expect(state.isLoading, isFalse);
  });

  test('换书后旧正文返回不覆盖新书', () async {
    final pending = Completer<String>();
    final entered = Completer<void>();
    when(() => content.read(book.bookUrl, 0)).thenAnswer((_) {
      entered.complete();
      return pending.future;
    });
    final first = controller.openBook(book);
    await entered.future;
    final second = book.copyWith(bookUrl: 'https://book/2');
    await controller.openBook(second);
    pending.complete('旧书正文');
    await first;
    expect(state.currentBook, second);
    expect(state.chapterContent, '正文0' * 30);
    expect(state.isLoading, isFalse);
  });

  test('刷新重入不重复请求，失败保留旧正文并释放入口', () async {
    await controller.openBook(book);
    final pending = Completer<String>();
    when(
      () => content.refresh(
        bookUrl: book.bookUrl,
        chapterIndex: 0,
        chapterUrl: chapters[0].url,
        sourceUrl: book.origin,
      ),
    ).thenAnswer((_) => pending.future);
    final refreshing = controller.refreshChapterContent();
    expect(controller.isRefreshing, isTrue);
    expect(await controller.refreshChapterContent(), '正文刷新进行中');
    pending.completeError(const BridgeError(message: '刷新失败'));
    expect(await refreshing, '刷新失败');
    expect(state.chapterContent, '正文0' * 30);
    expect(state.error, '刷新失败');
    expect(controller.isRefreshing, isFalse);
    verify(
      () => content.refresh(
        bookUrl: book.bookUrl,
        chapterIndex: 0,
        chapterUrl: chapters[0].url,
        sourceUrl: book.origin,
      ),
    ).called(1);
  });

  test('刷新期间切章，迟到刷新不回写上一章内容', () async {
    await controller.openBook(book);
    final pending = Completer<String>();
    when(
      () => content.refresh(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
        chapterUrl: any(named: 'chapterUrl'),
        sourceUrl: any(named: 'sourceUrl'),
      ),
    ).thenAnswer((_) => pending.future);
    final refreshing = controller.refreshChapterContent();
    await controller.nextChapter();
    pending.complete('旧章刷新正文');
    await refreshing;
    expect(state.currentChapterIndex, 1);
    expect(state.chapterContent, '正文1' * 30);
    expect(controller.isRefreshing, isFalse);
  });

  test('换源重载复用书架与正文服务，按章节标题定位并保留当前页', () async {
    await controller.openBook(book);
    controller.updatePosition(2, sourceOffset: 10);
    final newBook = book.copyWith(origin: 'https://source/2');
    when(() => bookshelf.getBook(book.bookUrl))
        .thenAnswer((_) async => newBook);
    final newChapters = chapters.reversed.toList();
    when(() => reading.getChapters(book.bookUrl))
        .thenAnswer((_) async => newChapters);
    when(
      () => content.refresh(
        bookUrl: book.bookUrl,
        chapterIndex: 2,
        chapterUrl: chapters[0].url,
        sourceUrl: newBook.origin,
      ),
    ).thenAnswer((_) async => '新源正文');
    expect(await controller.reloadAfterSourceChange(book.bookUrl), isNull);
    expect(state.currentBook!.origin, newBook.origin);
    expect(state.currentChapterIndex, 2);
    expect(state.currentChapterPos, 2);
    expect(state.chapterContent, '新源正文');
    expect(controller.isChangeSourceFlowActive, isFalse);
    expect(controller.tryBeginChangeSourceFlow(), isTrue);
    expect(controller.tryBeginChangeSourceFlow(), isFalse);
    expect(await controller.reloadAfterSourceChange(book.bookUrl), '更换书源进行中');
    controller.endChangeSourceFlow();
  });

  test('阅读计时用原累计值，保存失败后保留待写时段并可重试', () async {
    when(() => settings.load())
        .thenAnswer((_) async => const ReadRecordSettings());
    when(() => records.getReadRecords()).thenAnswer(
      (_) async => [const ReadRecord(bookName: '测试小说', readTime: 5000)],
    );
    final saved = <ReadRecord>[];
    when(
      () => records.putReadRecord(
        any(),
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
      ),
    ).thenAnswer((call) async {
      saved.add(call.positionalArguments.first as ReadRecord);
      if (saved.length == 1) throw StateError('写入失败');
    });
    await controller.openBook(book);
    clock += 1000;
    await controller.saveProgress();
    clock += 2000;
    await controller.saveProgress();
    expect(saved.map((r) => r.readTime), [6000, 8000]);
    expect(saved.map((r) => r.startTime), [10000, 10000]);
    expect(saved.last.lastRead, 13000);
    expect(saved.last.author, book.author);
    expect(state.chapterContent, '正文0' * 30);
  });

  test('进度保存失败不阻断章节导航', () async {
    await controller.openBook(book);
    when(
      () => reading.updateReadingProgress(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
        chapterPos: any(named: 'chapterPos'),
      ),
    ).thenThrow(StateError('存储失败'));
    await controller.nextChapter();
    expect(state.currentChapterIndex, 1);
    expect(state.chapterContent, '正文1' * 30);
  });

  test('销毁后在途正文不再访问宿主，后续动作也不启动加载', () async {
    final pending = Completer<String>();
    final entered = Completer<void>();
    when(() => content.read(book.bookUrl, 0)).thenAnswer((_) {
      entered.complete();
      return pending.future;
    });
    final opening = controller.openBook(book);
    await entered.future;
    controller.dispose();
    released = true;
    pending.complete('销毁后正文');
    await opening;
    await controller.openBook(book);
    await controller.nextChapter();
    await controller.saveProgress();
    expect(controller.currentSourceOffset, isNull);
    expect(state.chapterContent, isEmpty);
    verify(() => content.read(book.bookUrl, 0)).called(1);
  });

  test('销毁时换源读取失败不访问已释放宿主', () async {
    await controller.openBook(book);
    final pending = Completer<Book?>();
    when(() => bookshelf.getBook(book.bookUrl))
        .thenAnswer((_) => pending.future);
    final reloading = controller.reloadAfterSourceChange(book.bookUrl);
    controller.dispose();
    released = true;
    pending.completeError(StateError('目录读取失败'));
    expect(await reloading, isNull);
  });
}
