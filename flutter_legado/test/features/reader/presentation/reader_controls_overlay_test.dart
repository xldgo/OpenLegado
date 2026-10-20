import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_controls_overlay.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_menu_panel.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_settings_sheet.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/audio/application/audio_notifier.dart';
import 'package:flutter_legado/src/features/audio/application/read_aloud_capsule.dart';
import 'package:flutter_legado/src/widgets/reader/read_aloud_bar.dart';

import '../../../fixtures/app_test_api.dart';

const _readerState = ReaderState(
  currentBook: Book(bookUrl: 'fixture://book', name: '阅读小说'),
  chapterContent: '正文段落。',
  chapters: [
    BookChapter(url: 'fixture://chapter/0', title: '第一章', index: 0),
    BookChapter(url: 'fixture://chapter/1', title: '第二章', index: 1),
  ],
  showControls: true,
);

class _Reader extends ReaderNotifier {
  _Reader(this.initial);
  final ReaderState initial;
  @override
  ReaderState build() => initial;
}

class _Audio extends AudioNotifier {
  _Audio(this.initial);
  final AudioState initial;
  @override
  final followReadAloud = ValueNotifier(false);
  int stops = 0;
  @override
  int get paragraphCount => 0;
  @override
  AudioState build() {
    ref.onDispose(followReadAloud.dispose);
    return initial;
  }

  @override
  void restoreReadAloudFollow() => followReadAloud.value = true;

  @override
  void stop() {
    stops++;
    state = state.copyWith(state: PlayerState.idle);
  }
}

class _Actions {
  int catalogs = 0;
  int searches = 0;
  int alouds = 0;
  int autoTurns = 0;
  int fromPage = 0;
  final pages = <int>[];
}

Future<(ProviderContainer, _Audio, _Actions)> _pump(
  WidgetTester tester, {
  PlayerState playerState = PlayerState.idle,
  String playingBookUrl = 'fixture://book',
  bool readerLoading = false,
  bool imageDominant = false,
  bool streamMode = false,
  bool classicExpanded = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final audio = _Audio(
    AudioState(
      config: TtsConfig(),
      bookUrl: playingBookUrl,
      bookName: '阅读小说',
      state: playerState,
      isStreamMode: streamMode,
    ),
  );
  final actions = _Actions();
  final container = ProviderContainer(
    overrides: mergeTestOverrides([
      ...MockBookApi().overrides,
      readerNotifierProvider.overrideWith(
        () => _Reader(_readerState.copyWith(isLoading: readerLoading)),
      ),
      audioNotifierProvider.overrideWith(() => audio),
    ]),
  );
  addTearDown(container.dispose);
  container
      .read(readAloudCapsuleProvider.notifier)
      .showClassic(classicExpanded);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Stack(
              children: [
                ReaderControlsOverlay(
                  state: ref.watch(readerNotifierProvider),
                  imageDominant: imageDominant,
                  progressBehavior: 'page',
                  onAddBookmark: () {},
                  onOpenCatalog: () => actions.catalogs++,
                  onOpenContentSearch: () => actions.searches++,
                  onReadAloud: () => actions.alouds++,
                  onToggleAutoPage: () => actions.autoTurns++,
                  onReadFromVisiblePage: () async => actions.fromPage++,
                  onSeekPage: actions.pages.add,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, audio, actions);
}

void main() {
  testWidgets(
    '菜单动作和页内进度事件交给页面，不建立第二份阅读状态',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      final (container, _, actions) = await _pump(tester);
      final bottomBar = find.byKey(const ValueKey('reader-actions-surface'));
      final screenHeight = MediaQuery.sizeOf(tester.element(bottomBar)).height;
      expect(
        screenHeight - tester.getRect(bottomBar).bottom,
        defaultTargetPlatform == TargetPlatform.android ? 54 : 20,
      );
      for (final label in ['目录', '全文搜索', '自动翻页', '朗读']) {
        await tester.tap(find.text(label));
      }
      expect(actions.catalogs, 1);
      expect(actions.searches, 1);
      expect(actions.autoTurns, 1);
      expect(actions.alouds, 1);
      container
          .read(readerNotifierProvider.notifier)
          .updateChapterPageCount(0, 4);
      await tester.pump();
      final slider = find.byType(GlassSlider);
      await tester.drag(slider, const Offset(200, 0));
      await tester.pump();
      expect(actions.pages, isNotEmpty);
      expect(actions.pages.last, inInclusiveRange(1, 3));
      expect(container.read(readerNotifierProvider).currentChapterPos, 0);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('设置动作仍能通过当前Navigator打开实际快捷面板', (tester) async {
    const channel = MethodChannel('github.com/aaassseee/screen_brightness');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unsupported');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await _pump(tester);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderSettingsSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('朗读脱离跟随后显示两项操作，恢复跟随只改变现有播放状态', (tester) async {
    final (_, audio, actions) = await _pump(
      tester,
      playerState: PlayerState.playing,
    );
    expect(find.byType(ActionChip), findsNWidgets(2));
    final fromPage = find.widgetWithIcon(ActionChip, Icons.play_arrow);
    await tester.tap(fromPage);
    expect(actions.fromPage, 1);
    await tester.tap(find.widgetWithIcon(ActionChip, Icons.my_location));
    await tester.pumpAndSettle();
    expect(audio.followReadAloud.value, isTrue);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('正文加载时仅禁用从当前页朗读，仍可恢复播放位置', (tester) async {
    final (_, audio, actions) = await _pump(
      tester,
      playerState: PlayerState.playing,
      readerLoading: true,
    );
    final fromPage = tester.widget<ActionChip>(
      find.widgetWithIcon(ActionChip, Icons.play_arrow),
    );
    expect(fromPage.onPressed, isNull);
    expect(actions.fromPage, 0);
    await tester.tap(find.widgetWithIcon(ActionChip, Icons.my_location));
    await tester.pumpAndSettle();
    expect(audio.followReadAloud.value, isTrue);
  });

  for (final mode in ['其他书籍', '音频书', '图片正文']) {
    testWidgets('$mode不显示当前文本页的朗读定位操作', (tester) async {
      await _pump(
        tester,
        playerState: PlayerState.playing,
        playingBookUrl: mode == '其他书籍' ? 'fixture://other' : 'fixture://book',
        streamMode: mode == '音频书',
        imageDominant: mode == '图片正文',
        classicExpanded: mode == '其他书籍',
      );
      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(ReaderMenuPanel), findsOneWidget);
      expect(find.byType(ReadAloudBar), findsNothing);
    });
  }

  testWidgets('经典朗读条与阅读菜单互斥，停止后回到菜单并收起经典条', (tester) async {
    final (container, audio, actions) = await _pump(
      tester,
      playerState: PlayerState.playing,
      classicExpanded: true,
    );
    expect(find.byType(ReadAloudBar), findsOneWidget);
    expect(find.byType(ReaderMenuPanel), findsNothing);
    await tester.tap(find.text('目录'));
    expect(actions.catalogs, 1);
    await tester.tap(find.byTooltip('停止朗读'));
    await tester.pumpAndSettle();
    expect(audio.stops, 1);
    expect(container.read(readAloudCapsuleProvider).classicExpanded, isFalse);
    expect(find.byType(ReadAloudBar), findsNothing);
    expect(find.byType(ReaderMenuPanel), findsOneWidget);
  });
}
