import 'dart:async';

import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/bridge/ffi.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/reading_provider.dart';
import 'package:flutter_legado/src/data/services/chapter_content_service.dart';
import 'package:flutter_legado/src/providers/chapter_content_provider.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';
import 'package:flutter_legado/src/providers/theme/theme_notifier.dart';
import 'package:flutter_legado/src/providers/ui_settings/ui_settings_notifier.dart';

import '../mocks/mocks.dart';

class ReaderChapterContent extends Mock implements ChapterContentService {}

void main() {
  late MockRustApi mockApi;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbacks();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApi = MockRustApi();
    // 创建容器并覆盖 bookshelfRepositoryProvider 注入 mock
    container = ProviderContainer(
      overrides: mergeTestOverrides([...mockApi.overrides]),
    );
    addTearDown(container.dispose);
  });

  /// 等待异步初始化完成（build() 中的 _loadSettings microtask）
  Future<void> pumpInit() async {
    await Future.delayed(Duration.zero);
    await Future.delayed(Duration.zero);
  }

  ReaderState readState() => container.read(readerNotifierProvider);
  ReaderNotifier readNotifier() =>
      container.read(readerNotifierProvider.notifier);

  // ===== 测试数据 =====

  const testBook = Book(
    bookUrl: 'https://book.com/1',
    name: '测试书籍',
    author: '作者',
    origin: 'https://source.com',
    durChapterIndex: 0,
  );

  final testChapters = [
    const BookChapter(title: '第一章', index: 0),
    const BookChapter(title: '第二章', index: 1),
    const BookChapter(title: '第三章', index: 2),
  ];

  /// 配置 openBook 所需的完整 mock 链
  void stubOpenBook({List<BookChapter>? chapters, String content = '章节内容'}) {
    when(() => mockApi.readingRepository.getChapters(any()))
        .thenAnswer((_) async => chapters ?? testChapters);
    when(() => mockApi.readingRepository.getChapterContentFull(any(), any()))
        .thenAnswer((_) async => content);
    when(
      () => mockApi.readingRepository.updateReadingProgress(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
        chapterPos: any(named: 'chapterPos'),
      ),
    ).thenAnswer((_) async {});
  }

  test('本地阅读与朗读共用可还原相对路径的正文入口', () async {
    stubOpenBook();
    const url = 'books/本地书.epub';
    when(() => mockApi.readingRepository.getChapterContent(url, any()))
        .thenAnswer((_) async => '相对路径本地正文');
    await readNotifier().openBook(
      testBook.copyWith(bookUrl: url, origin: BookType.localTag),
    );
    expect(readState().chapterContent, '相对路径本地正文');
    verify(() => mockApi.readingRepository.getChapterContent(url, 0)).called(1);
    verifyNever(
      () => mockApi.readingRepository.getChapterContentFull(any(), any()),
    );
  });

  test('正文服务可单独注入，目录与进度继续由阅读仓储提供', () async {
    stubOpenBook();
    final content = ReaderChapterContent();
    when(() => content.read(testBook.bookUrl, any()))
        .thenAnswer((_) async => '独立正文服务');
    final isolated = ProviderContainer(
      overrides: mergeTestOverrides([
        ...mockApi.overrides,
        chapterContentServiceProvider.overrideWithValue(content),
      ]),
    );
    addTearDown(isolated.dispose);
    final reader = isolated.read(readerNotifierProvider.notifier);
    await reader.openBook(testBook);
    expect(isolated.read(readerNotifierProvider).chapterContent, '独立正文服务');
    await reader.goToChapter(1);
    verify(() => content.read(testBook.bookUrl, 1)).called(1);
    verifyNever(
      () => mockApi.readingRepository.getChapterContentFull(any(), any()),
    );
  });

  test('目录、正文及进度只使用注入的阅读仓储', () async {
    final reading = ReadingRepositoryMock();
    when(() => reading.getChapters(testBook.bookUrl))
        .thenAnswer((_) async => testChapters);
    when(() => reading.getChapterContentFull(testBook.bookUrl, any()))
        .thenAnswer((_) async => '独立阅读正文');
    when(
      () => reading.updateReadingProgress(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
        chapterPos: any(named: 'chapterPos'),
      ),
    ).thenAnswer((_) async {});
    final isolated = ProviderContainer(
      overrides: mergeTestOverrides([
        ...mockApi.overrides,
        readingRepositoryProvider.overrideWithValue(reading),
      ]),
    );
    addTearDown(isolated.dispose);
    final reader = isolated.read(readerNotifierProvider.notifier);
    await reader.openBook(testBook);
    expect(isolated.read(readerNotifierProvider).chapterContent, '独立阅读正文');
    await reader.goToChapter(1);
    await reader.saveProgress();
    expect(isolated.read(readerNotifierProvider).currentChapterIndex, 1);
    verify(() => reading.getChapterContentFull(testBook.bookUrl, 1)).called(1);
    verify(
      () => reading.updateReadingProgress(
        bookUrl: testBook.bookUrl,
        chapterIndex: 1,
        chapterPos: 0,
      ),
    ).called(greaterThanOrEqualTo(1));
    verifyZeroInteractions(mockApi.readingRepository);
  });

  test('Provider重建释放旧会话，迟到正文不能覆盖重新打开的书籍', () async {
    stubOpenBook();
    final content = ReaderChapterContent();
    final entered = Completer<void>();
    final pending = Completer<String>();
    var calls = 0;
    when(() => content.read(testBook.bookUrl, 0)).thenAnswer((_) {
      if (calls++ == 0) {
        entered.complete();
        return pending.future;
      }
      return Future.value('重建后的正文');
    });
    final isolated = ProviderContainer(
      overrides: mergeTestOverrides([
        ...mockApi.overrides,
        chapterContentServiceProvider.overrideWithValue(content),
      ]),
    );
    addTearDown(isolated.dispose);
    final opening = isolated
        .read(readerNotifierProvider.notifier)
        .openBook(testBook);
    await entered.future;
    isolated.invalidate(readerNotifierProvider);
    await isolated.read(readerNotifierProvider.notifier).openBook(testBook);
    pending.complete('过期正文');
    await opening;
    expect(isolated.read(readerNotifierProvider).chapterContent, '重建后的正文');
    expect(isolated.read(readerNotifierProvider).isLoading, isFalse);
    expect(calls, 2);
  });

  test('保存并重新开书恢复原文锚点，历史页码和目录跳转不冒充锚点', () async {
    stubOpenBook(content: '章节正文' * 100);
    await readNotifier().openBook(testBook.copyWith(durChapterPos: 3));
    expect(readNotifier().currentSourceOffset, isNull);
    expect(readState().currentChapterPos, 0);
    readNotifier().updatePosition(2, sourceOffset: 120);
    await readNotifier().saveProgress();
    final savedBook = readState().currentBook!;
    readNotifier().updatePosition(0);
    await readNotifier().openBook(savedBook);
    expect(readNotifier().currentSourceOffset, 120);
    // 页码由新布局派生，开书只恢复原文锚点。
    expect(readState().currentChapterPos, 0);
    await readNotifier().goToChapter(0);
    expect(readNotifier().currentSourceOffset, isNull);
    await readNotifier().openBook(readState().currentBook!);
    expect(readNotifier().currentSourceOffset, isNull);
    expect(readState().currentChapterPos, 0);
  });

  test('应用无原文坐标的云端章节后，不恢复同章的旧锚点', () async {
    stubOpenBook(content: '章节正文' * 100);
    await readNotifier().openBook(testBook);
    readNotifier().updatePosition(2, sourceOffset: 120);
    await readNotifier().saveProgress();

    await readNotifier().applyBookProgress(chapterIndex: 0);
    expect(readNotifier().currentSourceOffset, isNull);
    expect(readState().currentChapterPos, 0);
    await readNotifier().openBook(readState().currentBook!);
    expect(readNotifier().currentSourceOffset, isNull);
    expect(readState().currentChapterPos, 0);
  });

  test('字号行距改变保持当前章节和原文锚点，重新开书仍恢复同一位置', () async {
    stubOpenBook(content: '章节正文' * 100);
    await readNotifier().openBook(testBook);
    readNotifier().updatePosition(2, sourceOffset: 120);
    await readNotifier().updateFontSize(26);
    await readNotifier().updateLineHeight(2.1);
    await container
        .read(readerSettingsRepositoryProvider)
        .update(fontFamily: 'SimSun', titleFontFamily: 'KaiTi');
    expect(readState().currentChapterIndex, 0);
    expect(readState().currentChapterPos, 2);
    expect(readNotifier().currentSourceOffset, 120);
    await readNotifier().saveProgress();
    await readNotifier().openBook(readState().currentBook!);
    expect(readNotifier().currentSourceOffset, 120);
    expect(readState().fontSize, 26);
    expect(readState().lineHeight, 2.1);
  });

  group('ReaderState 初始状态', () {
    test('初始无当前书籍', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().currentBook, isNull);
      expect(readState().chapters, isEmpty);
      expect(readState().chapterContent, equals(''));
    });

    test('初始非加载状态', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().isLoading, isFalse);
      expect(readState().error, isNull);
    });

    test('初始控制面板隐藏', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().showControls, isFalse);
    });

    test('初始阅读设置默认值', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      // [PARITY C2 R1/R2] 默认字号 18→20、行距 1.67→1.7（对齐参考）
      expect(readState().fontSize, equals(20.0));
      expect(readState().lineHeight, equals(1.7));
      expect(readState().backgroundColor, equals(ReaderBackground.white));
      // 默认翻页模式为 cover（对齐 Android 原版）
      expect(readState().pageTurnMode, equals(PageTurnMode.cover));
    });

    test('初始无上一章/下一章', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().hasPreviousChapter, isFalse);
      expect(readState().hasNextChapter, isFalse);
    });

    test('初始进度为 0', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().readingProgress, equals(0));
    });

    test('初始 currentChapter 为 null', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().currentChapter, isNull);
    });
  });

  group('PageTurnMode 枚举', () {
    test('displayName 返回正确中文名', () {
      expect(PageTurnMode.scroll.displayName, equals('滚动'));
      expect(PageTurnMode.slide.displayName, equals('滑动'));
      expect(PageTurnMode.simulate.displayName, equals('仿真'));
      expect(PageTurnMode.none.displayName, equals('无动画'));
      expect(PageTurnMode.cover.displayName, equals('覆盖'));
    });

    test('icon 返回正确表情', () {
      expect(PageTurnMode.scroll.icon, equals('📜'));
      expect(PageTurnMode.slide.icon, equals('👈'));
      expect(PageTurnMode.simulate.icon, equals('📖'));
      expect(PageTurnMode.none.icon, equals('⚡'));
      expect(PageTurnMode.cover.icon, equals('📄'));
    });

    test('values 包含 5 种模式', () {
      expect(PageTurnMode.values.length, equals(5));
    });
  });

  group('PageTurnMode.fromStorage 双通道恢复', () {
    test('name 优先：name="cover" 返回 cover', () {
      expect(PageTurnMode.fromStorage('cover', null), PageTurnMode.cover);
    });

    test('name 优先：name="slide" 即使 legacyIndex=0 也返回 slide', () {
      expect(PageTurnMode.fromStorage('slide', 0), PageTurnMode.slide);
    });

    test('name 为空时回退 legacyIndex=0 → scroll', () {
      expect(PageTurnMode.fromStorage(null, 0), PageTurnMode.scroll);
    });

    test('name 为空时回退 legacyIndex=3 → none', () {
      expect(PageTurnMode.fromStorage(null, 3), PageTurnMode.none);
    });

    test('name 为空字符串时回退 legacyIndex', () {
      expect(PageTurnMode.fromStorage('', 1), PageTurnMode.slide);
    });

    test('name 无效且 legacyIndex 有效时回退 legacyIndex', () {
      expect(
        PageTurnMode.fromStorage('invalid_name', 2),
        PageTurnMode.simulate,
      );
    });

    test('name 和 legacyIndex 都无效时默认 cover', () {
      expect(PageTurnMode.fromStorage(null, null), PageTurnMode.cover);
      expect(PageTurnMode.fromStorage('bad', -1), PageTurnMode.cover);
      expect(PageTurnMode.fromStorage('bad', 99), PageTurnMode.cover);
    });
  });

  group('ReaderNotifier 阅读设置', () {
    test('updateFontSize 正常设置', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().updateFontSize(22.0);
      expect(readState().fontSize, equals(22.0));
    });

    test('updateFontSize 低于下限被 clamp 到 12', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().updateFontSize(8.0);
      expect(readState().fontSize, equals(12.0));
    });

    test('updateFontSize 超过上限被 clamp 到 32', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().updateFontSize(50.0);
      expect(readState().fontSize, equals(32.0));
    });

    test('updateLineHeight 正常设置', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().updateLineHeight(2.0);
      expect(readState().lineHeight, equals(2.0));
    });

    test('updateLineHeight 低于下限被 clamp 到 1.0', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().updateLineHeight(0.5);
      expect(readState().lineHeight, equals(1.0));
    });

    // [UI-fix v2.0.4 | 2026-08-08] 行距上限 2.5 → 3.0（同步界面 Sheet
    // 行距滑条 1.0-3.0，对标原版 dsbLineSize 范围） — Qoder
    test('updateLineHeight 超过上限被 clamp 到 3.0', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().updateLineHeight(4.0);
      expect(readState().lineHeight, equals(3.0));
    });

    test('updateBackgroundColor 设置为预设绿色', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().updateBackgroundColor(ReaderBackground.green);
      expect(readState().backgroundColor, equals(ReaderBackground.green));
    });

    test('updateBackgroundColor 设置为自定义颜色', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      const custom = Color(0xFF123456);
      await readNotifier().updateBackgroundColor(custom);
      expect(readState().backgroundColor, equals(custom));
    });

    test('updatePageTurnMode 切换翻页模式', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().updatePageTurnMode(PageTurnMode.slide);
      expect(readState().pageTurnMode, equals(PageTurnMode.slide));
      await readNotifier().updatePageTurnMode(PageTurnMode.scroll);
      expect(readState().pageTurnMode, equals(PageTurnMode.scroll));
    });
  });

  group('ReaderNotifier loadSettings（SharedPreferences）', () {
    test('加载字体大小', () async {
      SharedPreferences.setMockInitialValues({'reader_font_size': 24.0});
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().fontSize, equals(24.0));
    });

    test('加载行距', () async {
      SharedPreferences.setMockInitialValues({'reader_line_height': 2.0});
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().lineHeight, equals(2.0));
    });

    test('加载背景色索引', () async {
      SharedPreferences.setMockInitialValues({'reader_bg_color_index': 1});
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().backgroundColor, equals(ReaderBackground.green));
    });

    test('背景色索引越界时保持默认', () async {
      SharedPreferences.setMockInitialValues({'reader_bg_color_index': 99});
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().backgroundColor, equals(ReaderBackground.white));
    });

    test('翻页模式 name 优先', () async {
      SharedPreferences.setMockInitialValues({
        'reader_flip_mode_name': 'slide',
        'reader_flip_mode': 0,
      });
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().pageTurnMode, equals(PageTurnMode.slide));
    });

    test('翻页模式回退 legacyIndex', () async {
      SharedPreferences.setMockInitialValues({'reader_flip_mode': 2});
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().pageTurnMode, equals(PageTurnMode.simulate));
    });
  });

  group('ReaderNotifier openBook（mock API）', () {
    test('成功加载章节列表', () async {
      stubOpenBook();
      container.read(readerNotifierProvider);
      await pumpInit();

      await readNotifier().openBook(testBook);

      expect(readState().currentBook, equals(testBook));
      expect(readState().chapters.length, equals(3));
      expect(readState().currentChapterIndex, equals(0));
      expect(readState().isLoading, isFalse);
      expect(readState().error, isNull);
    });

    test('加载章节内容', () async {
      stubOpenBook(content: '第一章正文内容');
      container.read(readerNotifierProvider);
      await pumpInit();

      await readNotifier().openBook(testBook);
      expect(readState().chapterContent, equals('第一章正文内容'));
    });

    test('失败时设置 BridgeError 错误', () async {
      when(() => mockApi.readingRepository.getChapters(any()))
          .thenThrow(const BridgeError(message: '书籍不存在'));
      container.read(readerNotifierProvider);
      await pumpInit();

      await readNotifier().openBook(testBook);

      expect(readState().error, equals('书籍不存在'));
      expect(readState().isLoading, isFalse);
    });

    test('失败时设置普通异常错误', () async {
      when(() => mockApi.readingRepository.getChapters(any()))
          .thenThrow(Exception('网络错误'));
      container.read(readerNotifierProvider);
      await pumpInit();

      await readNotifier().openBook(testBook);

      expect(readState().error, contains('网络错误'));
      expect(readState().isLoading, isFalse);
    });

    test('durChapterIndex 越界时重置为 0', () async {
      stubOpenBook();
      container.read(readerNotifierProvider);
      await pumpInit();

      final book = testBook.copyWith(durChapterIndex: 99);
      await readNotifier().openBook(book);
      expect(readState().currentChapterIndex, equals(0));
    });

    test('openBook 后派生属性正确', () async {
      stubOpenBook();
      container.read(readerNotifierProvider);
      await pumpInit();

      await readNotifier().openBook(testBook);
      expect(readState().hasPreviousChapter, isFalse);
      expect(readState().hasNextChapter, isTrue);
      // 第 0 章 / 共 3 章 = 1/3
      expect(readState().readingProgress, closeTo(0.333, 0.01));
      expect(readState().currentChapter?.title, equals('第一章'));
    });
  });

  group('ReaderNotifier 章节导航（mock API）', () {
    setUp(() {
      stubOpenBook();
    });

    test('nextChapter 切换到下一章', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().openBook(testBook);
      await readNotifier().nextChapter();
      expect(readState().currentChapterIndex, equals(1));
      expect(readState().currentChapterPos, equals(0));
    });

    test('nextChapter 在最后一章时不切换', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      final book = testBook.copyWith(durChapterIndex: 2);
      await readNotifier().openBook(book);
      await readNotifier().nextChapter();
      expect(readState().currentChapterIndex, equals(2));
    });

    test('prevChapter 切换到上一章', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      final book = testBook.copyWith(durChapterIndex: 1);
      await readNotifier().openBook(book);
      await readNotifier().prevChapter();
      expect(readState().currentChapterIndex, equals(0));
    });

    test('prevChapter 在第一章时不切换', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().openBook(testBook);
      await readNotifier().prevChapter();
      expect(readState().currentChapterIndex, equals(0));
    });

    test('goToChapter 跳转到指定章节', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().openBook(testBook);
      await readNotifier().goToChapter(2);
      expect(readState().currentChapterIndex, equals(2));
    });

    test('goToChapter 负索引不跳转', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().openBook(testBook);
      await readNotifier().goToChapter(-1);
      expect(readState().currentChapterIndex, equals(0));
    });

    test('goToChapter 越界索引不跳转', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().openBook(testBook);
      await readNotifier().goToChapter(99);
      expect(readState().currentChapterIndex, equals(0));
    });

    test('goToChapter 隐藏控制面板', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().openBook(testBook);
      readNotifier().toggleControls(); // 先显示
      await readNotifier().goToChapter(1);
      expect(readState().showControls, isFalse);
    });
  });

  group('ReaderNotifier 控制面板', () {
    test('toggleControls 显示控制面板', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      readNotifier().toggleControls();
      expect(readState().showControls, isTrue);
    });

    test('toggleControls 再次切换隐藏', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      readNotifier().toggleControls();
      readNotifier().toggleControls();
      expect(readState().showControls, isFalse);
    });

    test('hideControls 隐藏已显示的面板', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      readNotifier().toggleControls();
      readNotifier().hideControls();
      expect(readState().showControls, isFalse);
    });

    test('hideControls 对已隐藏面板无效', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      readNotifier().hideControls();
      expect(readState().showControls, isFalse);
    });
  });

  group('ReaderNotifier 阅读位置', () {
    test('updatePosition 更新当前位置', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      readNotifier().updatePosition(100);
      expect(readState().currentChapterPos, equals(100));
    });

    test('updatePosition 可多次更新', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      readNotifier().updatePosition(50);
      readNotifier().updatePosition(200);
      expect(readState().currentChapterPos, equals(200));
    });
  });

  group('ReaderNotifier saveProgress（mock API）', () {
    test('无书籍时不调用 API', () async {
      container.read(readerNotifierProvider);
      await pumpInit();
      await readNotifier().saveProgress();
      verifyNever(
        () => mockApi.readingRepository.updateReadingProgress(
          bookUrl: any(named: 'bookUrl'),
          chapterIndex: any(named: 'chapterIndex'),
          chapterPos: any(named: 'chapterPos'),
        ),
      );
    });

    test('有书籍时调用 API', () async {
      stubOpenBook(chapters: [const BookChapter(title: 'ch1', index: 0)]);
      container.read(readerNotifierProvider);
      await pumpInit();

      const book = Book(bookUrl: 'https://b.com/1', name: 'test');
      await readNotifier().openBook(book);
      await readNotifier().saveProgress();

      verify(
        () => mockApi.readingRepository.updateReadingProgress(
          bookUrl: 'https://b.com/1',
          chapterIndex: 0,
          chapterPos: 0,
        ),
      ).called(greaterThan(0));
    });
  });

  group('ReaderState 派生属性', () {
    test('isDarkBackground 深色背景为 true', () {
      const state = ReaderState(backgroundColor: ReaderBackground.dark);
      expect(state.isDarkBackground, isTrue);
    });

    test('isDarkBackground 浅色背景为 false', () {
      const state = ReaderState(backgroundColor: ReaderBackground.white);
      expect(state.isDarkBackground, isFalse);
    });

    test('isDarkBackground 主题默认纯黑（M1 收尾微调）为 true', () {
      final state = ReaderState(backgroundColor: const Color(0xFF000000));
      expect(state.isDarkBackground, isTrue);
      expect(state.textColor, equals(const Color(0xFFCCCCCC)));
    });

    test('textColor 深色背景返回浅灰', () {
      const state = ReaderState(backgroundColor: ReaderBackground.dark);
      expect(state.textColor, equals(const Color(0xFFCCCCCC)));
    });

    test('textColor 浅色背景返回深灰', () {
      const state = ReaderState(backgroundColor: ReaderBackground.white);
      expect(state.textColor, equals(const Color(0xFF333333)));
    });
  });

  group('ReaderBackground 预设', () {
    test('预设列表包含 5 种颜色', () {
      expect(ReaderBackground.presets.length, equals(5));
    });

    test('标签列表与预设对应', () {
      expect(
        ReaderBackground.labels.length,
        equals(ReaderBackground.presets.length),
      );
    });

    test('预设包含白色与护眼色', () {
      expect(ReaderBackground.presets, contains(ReaderBackground.white));
      expect(ReaderBackground.presets, contains(ReaderBackground.eyeProtect));
    });

    test('标签包含中文名称', () {
      expect(ReaderBackground.labels, contains('白色'));
      expect(ReaderBackground.labels, contains('夜间'));
    });
  });

  // 默认背景跟随主题；夜间背景跟随纯黑开关；浅色预设和自定义色保持原选择。
  group('[M1] 深色态背景默认解析', () {
    test('默认夜间跟随纯黑，主动保存的样式背景保持原颜色', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().backgroundColor, ReaderBackground.dark);
      final ui = container.read(uiSettingsProvider.notifier);
      await ui.setThemeAmoled(true);
      await pumpInit();
      expect(readState().backgroundColor, const Color(0xFF000000));
      expect(readState().textColor, const Color(0xFFCCCCCC));
      await readNotifier().updateBackgroundColor(ReaderBackground.dark);
      await pumpInit();
      expect(readState().backgroundColor, ReaderBackground.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('reader_bg_color_index'), isNull);
      expect(prefs.getString('reader_styles'), isNotNull);
      await ui.setThemeAmoled(false);
      await pumpInit();
      expect(readState().backgroundColor, ReaderBackground.dark);
    });

    test('亮色主题 + 从未设置背景 → 默认白色（原默认不变）', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'light'});
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().backgroundColor, equals(ReaderBackground.white));
    });

    test('深色主题 + 显式预设索引 1 → 保留 green', () async {
      SharedPreferences.setMockInitialValues({
        'app_theme_mode': 'dark',
        'themeAmoled': true,
        'reader_bg_color_index': 1,
      });
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().backgroundColor, equals(ReaderBackground.green));
    });

    test('深色主题 + 自定义背景 → 保留 custom', () async {
      const custom = Color(0xFF232323);
      SharedPreferences.setMockInitialValues({
        'app_theme_mode': 'dark',
        'themeAmoled': true,
        'reader_bg_use_custom': true,
        'reader_custom_bg_color': 0xFF232323,
      });
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().backgroundColor, equals(custom));
    });

    test('主题切换 深色→亮色 + 从未设置 → 重解析为白色', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().backgroundColor, equals(ReaderBackground.dark));

      // 触发 ref.listen 钩子：监听值 next.themeMode=light 直接传入
      // reapply（此刻 prefs 尚未落盘，不能重读）
      await container
          .read(themeNotifierProvider.notifier)
          .setThemeMode(ThemeMode.light);
      await pumpInit();
      expect(readState().backgroundColor, equals(ReaderBackground.white));
    });

    test('主题切换 深色→亮色 + 显式 green → 仍 green（尊重显式选择）', () async {
      SharedPreferences.setMockInitialValues({
        'app_theme_mode': 'dark',
        'themeAmoled': true,
        'reader_bg_color_index': 1,
      });
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().backgroundColor, equals(ReaderBackground.green));

      await container
          .read(themeNotifierProvider.notifier)
          .setThemeMode(ThemeMode.light);
      await pumpInit();
      expect(readState().backgroundColor, equals(ReaderBackground.green));
    });

    test('主题切换 深色→亮色 + 自定义背景 → 仍 custom（尊重显式选择）', () async {
      const custom = Color(0xFF232323);
      SharedPreferences.setMockInitialValues({
        'app_theme_mode': 'dark',
        'themeAmoled': true,
        'reader_bg_use_custom': true,
        'reader_custom_bg_color': 0xFF232323,
      });
      container.read(readerNotifierProvider);
      await pumpInit();
      expect(readState().backgroundColor, equals(custom));

      await container
          .read(themeNotifierProvider.notifier)
          .setThemeMode(ThemeMode.light);
      await pumpInit();
      expect(readState().backgroundColor, equals(custom));
    });
  });
}
