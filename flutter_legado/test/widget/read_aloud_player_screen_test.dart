import '../fixtures/app_test_api.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/features/read_aloud/read_aloud_player_info.dart';
import 'package:flutter_legado/src/features/read_aloud/widgets/read_aloud_player_content.dart';
import 'package:flutter_legado/src/features/read_aloud/widgets/read_aloud_chapter_text.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';
import 'package:flutter_legado/src/providers/audio/read_aloud_position.dart';
import 'package:flutter_legado/src/providers/audio/read_aloud_preferences.dart';
import 'package:flutter_legado/src/screens/read_aloud_player_screen.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';

import '../mocks/mocks.dart';

class _Preferences extends ReadAloudPreferencesNotifier {
  @override
  ReadAloudPreferences build() => const ReadAloudPreferences(loaded: true);

  @override
  Future<void> load() async {}
}

/// 用确定的播放快照验证展示；合成与媒体会话另由现有引擎测试保护。
class _Audio extends AudioNotifier {
  final paragraphs = List.generate(30, (i) => '第$i段：小说正文，继续阅读这段文字。');
  int index = 0;
  int pauses = 0, resumes = 0, loads = 0, seeks = 0;
  final sourceSeeks = <(int, int)>[];

  @override
  AudioState build() {
    publishOffset(0);
    return AudioState(
      bookUrl: 'book',
      bookName: '测试小说',
      state: PlayerState.playing,
      config: TtsConfig(engineUrl: '1'),
      chapters: [
        AudioChapter(index: 0, title: '第一章', text: paragraphs.join('\n')),
      ],
    );
  }

  void publishOffset(int offset) {
    readAloudPosition.value = ReadAloudPosition(
      bookUrl: 'book',
      chapterIndex: 0,
      paragraphIndex: index,
      paragraphStart: 0,
      paragraphEnd: paragraphs.first.length,
      offset: offset,
      session: 1,
    );
  }

  @override
  Future<void> seekToChapterPosition(int chapterIndex, int offset) async {
    sourceSeeks.add((chapterIndex, offset));
    publishOffset(offset);
  }

  @override
  Book? get currentBook =>
      const Book(bookUrl: 'book', name: '测试小说', author: '作者');
  @override
  List<String> get currentParagraphs => paragraphs;
  @override
  int get currentParagraphIndex => index;
  @override
  bool get hasNextParagraph => index < paragraphs.length - 1;
  @override
  bool get hasPrevParagraph => index > 0;
  @override
  void pause({bool dueToInterruption = false}) {
    pauses++;
    state = state.copyWith(state: PlayerState.paused);
  }

  @override
  Future<void> resumeOrPlay() async {
    resumes++;
    state = state.copyWith(state: PlayerState.playing);
  }

  @override
  Future<void> loadChapters(String bookUrl) async {
    loads++;
  }

  @override
  Future<void> seekToParagraph(int value) async {
    seeks++;
    index = value;
    notifyListeners();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_Audio> pumpPlayer(
    WidgetTester tester, {
    Size size = const Size(360, 640),
    double scale = 1,
    bool reduced = false,
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = _Audio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...MockRustApi().overrides,
          audioNotifierProvider.overrideWith(() => audio),
          readAloudPreferencesProvider.overrideWith(_Preferences.new),
          readAloudPlayerInfoProvider.overrideWith(
            (_) async => const ReadAloudPlayerInfo(
              engineName: 'HTTP 测试引擎',
              voiceName: '中文音色',
            ),
          ),
        ]),
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduced,
            ),
            child: child!,
          ),
          home: const ReadAloudPlayerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return audio;
  }

  testWidgets('封面页展示音色信息，进入页面不重新加载，播放按钮沿用会话', (tester) async {
    final audio = await pumpPlayer(tester);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('中文音色'), findsOneWidget);
    expect(find.text('HTTP 测试引擎'), findsNothing);
    expect(find.text('测试小说'), findsOneWidget);
    expect(find.text('作者'), findsNothing);
    final badge = find.byType(Chip);
    expect(badge, findsOneWidget);
    expect(
      find.ancestor(of: badge, matching: find.byType(ListTile)),
      findsNothing,
    );
    expect(tester.widget<Chip>(badge).onDeleted, isNull);
    await tester.ensureVisible(badge);
    await tester.tap(badge);
    await tester.pumpAndSettle();
    expect(find.byType(ReadAloudPlayerScreen), findsOneWidget);
    expect(audio.loads, 0);
    await tester.tap(find.byTooltip('暂停'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final icon = tester.widget<AnimatedIcon>(find.byType(AnimatedIcon));
    expect(icon.progress.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(audio.pauses, 1);
    await tester.tap(find.byTooltip('播放'));
    await tester.pumpAndSettle();
    expect(audio.resumes, 1);
    expect(audio.loads, 0);
  });

  testWidgets('原文进度跟随段内回调，拖动仅在松手后定位并保持暂停', (tester) async {
    final audio = await pumpPlayer(tester);
    final length = audio.paragraphs.join('\n').length;
    audio.publishOffset(length ~/ 3);
    await tester.pump();
    var slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.max, length);
    expect(slider.value, length ~/ 3);
    await tester.tap(find.byTooltip('暂停'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(85, 0));
    await tester.pumpAndSettle();
    expect(audio.sourceSeeks, hasLength(1));
    expect(audio.sourceSeeks.single.$1, 0);
    expect(audio.sourceSeeks.single.$2, greaterThan(length ~/ 3));
    expect(audio.seeks, 0);
    expect(audio.resumes, 0);
    expect(audio.loads, 0);
    expect(find.byTooltip('播放'), findsOneWidget);
    slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, audio.sourceSeeks.single.$2);
  });

  testWidgets('三页可滑动和通过紧凑菜单访问', (tester) async {
    await pumpPlayer(tester);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.byType(ReadAloudChapterText), findsOneWidget);
    expect(
      tester
          .widget<ReadAloudChapterText>(find.byType(ReadAloudChapterText))
          .active,
      isTrue,
    );
    await tester.tap(find.byTooltip('朗读播放器'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('目录'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadAloudChapterText), findsNothing);
    expect(find.text('第一章'), findsNWidgets(2));
  });

  testWidgets('播放器倍速按钮打开共用面板，不重新加载或暂停朗读', (tester) async {
    final audio = await pumpPlayer(tester);
    await tester.tap(find.text('1.00×'));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(8));
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('语速'), findsOneWidget);
    expect(audio.loads, 0);
    expect(audio.pauses, 0);
    expect(audio.resumes, 0);
  });

  for (final reduced in [false, true]) {
    testWidgets('正文滚动隐藏/连续拖动/离页恢复，减少动画=$reduced', (tester) async {
      await pumpPlayer(tester, reduced: reduced);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      final list = find.descendant(
        of: find.byType(ReadAloudChapterText),
        matching: find.byType(ListView),
      );
      await tester.drag(list, const Offset(0, -150));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widget<ReadAloudControlsVisibility>(
              find.byType(ReadAloudControlsVisibility),
            )
            .visible,
        isFalse,
      );
      await tester.drag(list, const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester
            .widget<ReadAloudControlsVisibility>(
              find.byType(ReadAloudControlsVisibility),
            )
            .visible,
        isFalse,
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        tester
            .widget<ReadAloudControlsVisibility>(
              find.byType(ReadAloudControlsVisibility),
            )
            .visible,
        isTrue,
      );
      await tester.drag(list, const Offset(0, -80));
      await tester.pump();
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ReadAloudControlsVisibility>(
              find.byType(ReadAloudControlsVisibility),
            )
            .visible,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }

  for (final (size, scale, dark) in [
    (const Size(320, 568), 1.5, false),
    (const Size(640, 360), 1.5, true),
    (const Size(800, 1024), 2.0, false),
  ]) {
    testWidgets('布局适应 $size / 字体 $scale / 暗色 $dark', (tester) async {
      await pumpPlayer(
        tester,
        size: size,
        scale: scale,
        dark: dark,
        reduced: true,
      );
      expect(tester.takeException(), isNull);
      final scroll = find.descendant(
        of: find.byType(PageView),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(scroll, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('中文音色').hitTestable(), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('文本过渡排除退出内容的语义，减少动画直接更新', (tester) async {
    Widget content(String text, bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: ReadAloudPlayerText(current: text, next: '后文'),
        ),
      ),
    );
    await tester.pumpWidget(content('当前内容', false));
    await tester.pumpWidget(content('新内容', false));
    expect(find.text('当前内容'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('当前内容'),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.text('当前内容'), findsNothing);
    await tester.pumpWidget(content('减少动画内容', true));
    expect(find.text('新内容'), findsNothing);
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
