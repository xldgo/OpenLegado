import '../fixtures/app_test_api.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';
import 'package:flutter_legado/src/providers/audio/read_aloud_preferences.dart';
import 'package:flutter_legado/src/widgets/reader/read_aloud_timer_sheet.dart';
import 'package:flutter_legado/src/widgets/reader/read_aloud_speed_sheet.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/widgets/bottom_sheet_widget.dart';

import '../mocks/mocks.dart';

void main() {
  late MockRustApi api;
  late ProviderContainer container;
  late Map<String, String> saved;
  bool failSave = false;
  String? failKey;
  AudioNotifier audio() => container.read(audioNotifierProvider.notifier);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    saved = {};
    failSave = false;
    failKey = null;
    api = MockRustApi();
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((call) async => saved[call.positionalArguments[0]]);
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((call) async {
          if (failSave || call.positionalArguments[0] == failKey) {
            throw StateError('测试保存失败');
          }
          saved[call.positionalArguments[0] as String] =
              call.positionalArguments[1] as String;
        });
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        streamAudioPlayerProvider.overrideWithValue(FakeStreamAudioPlayer()),
      ]),
    );
    addTearDown(container.dispose);
  });

  Future<void> settle(WidgetTester tester) async {
    // 设置仓储在真实异步区加载；让真实写队列与Widget微任务都完成。
    for (var i = 0; i < 4; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester, {
    bool speed = false,
    Size size = const Size(360, 640),
    double scale = 1,
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (speed) {
      await tester.runAsync(
        () => container.read(readAloudPreferencesProvider.notifier).load(),
      );
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => speed
                    ? showReadAloudSpeedSheet(context)
                    : showReadAloudTimerSheet(context, audio()),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await settle(tester);
  }

  for (final speed in [false, true]) {
    testWidgets('朗读Sheet开关行铺满宽度，快捷项保留留白 speed=$speed', (tester) async {
      await open(tester, speed: speed);
      final sheet = tester.getRect(find.byType(AppBottomSheet));
      final tile = find.ancestor(
        of: find.byType(Switch),
        matching: find.byType(ListTile),
      );
      final bounds = tester.getRect(tile);
      expect(bounds.left, closeTo(sheet.left, .01));
      expect(bounds.right, closeTo(sheet.right, .01));
      final grid = tester.getRect(find.byType(AppSheetPresetGrid));
      expect(grid.left, closeTo(sheet.left + 16, .01));
      expect(grid.right, closeTo(sheet.right - 16, .01));
      final oldValue = tester.widget<Switch>(find.byType(Switch)).value;
      await tester.tapAt(Offset(bounds.left + 2, bounds.center.dy));
      await settle(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, !oldValue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('定时标题同排显示剩余量，移除重复说明，章数快捷项铺满一行', (tester) async {
    audio().startChapterStop(2);
    await open(tester);
    final title = find.text('定时停止');
    final remaining = find.text('剩余 2 章');
    expect(remaining, findsOneWidget);
    expect(
      tester.getCenter(title).dy,
      closeTo(tester.getCenter(remaining).dy, 2),
    );
    final toolbar = find.byType(NavigationToolbar);
    final header = find.descendant(of: toolbar, matching: find.byType(Row));
    expect(
      tester.getCenter(header).dx,
      closeTo(tester.getCenter(find.byType(AppBottomSheet)).dx, 0.01),
    );
    expect(find.text('章节模式'), findsOneWidget);
    expect(find.text('时间模式'), findsOneWidget);
    expect(find.textContaining('自然播完指定章数'), findsNothing);
    expect(find.textContaining('暂停时冻结'), findsNothing);
    expect(find.widgetWithText(ActionChip, '1 章'), findsNothing);
    expect(find.widgetWithText(ActionChip, '5 章'), findsOneWidget);
    final first = find.widgetWithText(ActionChip, '当前章');
    final last = find.widgetWithText(ActionChip, '5 章');
    expect(first, findsOneWidget);
    final grid = find.byType(AppSheetPresetGrid);
    expect(
      tester.getTopLeft(first).dy,
      closeTo(tester.getTopLeft(last).dy, .01),
    );
    expect(
      tester.getSize(first).width,
      closeTo(tester.getSize(last).width, .01),
    );
    expect(
      tester.getTopLeft(first).dx,
      closeTo(tester.getTopLeft(grid).dx, .01),
    );
    expect(
      tester.getTopRight(last).dx,
      closeTo(tester.getTopRight(grid).dx, .01),
    );
    await tester.tap(first);
    await settle(tester);
    expect(audio().chaptersToStopRemaining, 1);
    await tester.tap(find.text('打开'));
    await settle(tester);
    expect(find.text('当前章'), findsNWidgets(2));
    await tester.tap(find.widgetWithText(ActionChip, '5 章'));
    await settle(tester);
    expect(audio().chaptersToStopRemaining, 5);
    audio().cancelSleepTimer();
  });

  testWidgets('时间快捷项均分整行，滑动预选量仅在标题旁显示', (tester) async {
    await open(tester);
    final first = find.widgetWithText(ActionChip, '10 分钟');
    final last = find.widgetWithText(ActionChip, '90 分钟');
    expect(find.widgetWithText(ActionChip, '20 分钟'), findsNothing);
    expect(find.widgetWithText(ActionChip, '45 分钟'), findsOneWidget);
    final grid = find.byType(AppSheetPresetGrid);
    expect(
      tester.getTopLeft(first).dy,
      closeTo(tester.getTopLeft(last).dy, .01),
    );
    expect(
      tester.getSize(first).width,
      closeTo(tester.getSize(last).width, .01),
    );
    expect(
      tester.getTopRight(last).dx,
      closeTo(tester.getTopRight(grid).dx, .01),
    );
    tester.widget<Slider>(find.byType(Slider)).onChanged!(42);
    await tester.pump();
    expect(find.text('42 分钟'), findsOneWidget);
    expect(
      tester.getCenter(find.text('42 分钟')).dy,
      closeTo(tester.getCenter(find.text('定时停止')).dy, 2),
    );
    expect(audio().isSleepTimerActive, isFalse);
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(42);
    await tester.pump();
    expect(find.text('剩余 42 分钟'), findsOneWidget);
    audio().cancelSleepTimer();
  });

  testWidgets('时间模式可开启读完本章，章节模式单独设置且模式互斥', (tester) async {
    await open(tester);
    expect(audio().isSleepTimerActive, isFalse);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.widgetWithText(ActionChip, '30 分钟'));
    await settle(tester);
    expect(audio().sleepRemainingSeconds, 1800);
    expect(audio().finishCurrentChapterAfterTimer, isTrue);
    await tester.tap(find.text('打开'));
    await settle(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    final seconds = audio().sleepRemainingSeconds;
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(audio().sleepRemainingSeconds, seconds);
    expect(audio().finishCurrentChapterAfterTimer, isFalse);
    await tester.tap(find.text('章节模式').first);
    await settle(tester);
    expect(find.byType(Switch), findsNothing);
    expect(audio().sleepTimerMode, SleepTimerMode.off);
    expect(audio().sleepRemainingSeconds, 0);
    await tester.tap(find.widgetWithText(ActionChip, '3 章'));
    await settle(tester);
    expect(audio().chaptersToStopRemaining, 3);
  });

  testWidgets('计时滑块只在松手后设置，0 关闭，关闭面板不取消计时', (tester) async {
    await open(tester);
    var slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(42);
    await tester.pump();
    expect(audio().isSleepTimerActive, isFalse);
    slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChangeEnd!(42);
    await tester.pump();
    expect(audio().sleepRemainingSeconds, 42 * 60);
    slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(0);
    await tester.pump();
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(0);
    await tester.pump();
    expect(audio().isSleepTimerActive, isFalse);
    audio().startSleepTimer(5, finishCurrentChapter: true);
    Navigator.of(tester.element(find.byType(Slider))).pop();
    await settle(tester);
    expect(audio().finishCurrentChapterAfterTimer, isTrue);
    expect(audio().sleepRemainingSeconds, 300);
    audio().cancelSleepTimer();
  });

  testWidgets('倍速滑块只预览，预设保存同一份偏好，跟随系统保留手动值', (tester) async {
    await open(tester, speed: true);
    expect(saved, isEmpty);
    var slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(1.7);
    await tester.pump();
    expect(saved, isEmpty);
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(1.7);
    await settle(tester);
    expect(saved['ttsSpeechRate'], '12');
    expect(saved['ttsFollowSys'], 'false');
    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(saved['ttsSpeechRate'], '12');
    expect(saved['ttsFollowSys'], 'true');
    await tester.tap(find.widgetWithText(ChoiceChip, '2.0×'));
    await settle(tester);
    expect(saved['ttsSpeechRate'], '15');
    expect(saved['ttsFollowSys'], 'false');
    slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 2);
  });

  testWidgets('倍速保存失败提示并回退，后续可以重试', (tester) async {
    await open(tester, speed: true);
    failSave = true;
    await tester.tap(find.widgetWithText(ChoiceChip, '1.5×'));
    await settle(tester);
    expect(find.textContaining('测试保存失败'), findsOneWidget);
    expect(container.read(readAloudPreferencesProvider).followSystem, isTrue);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1);
    failSave = false;
    await tester.tap(find.widgetWithText(ChoiceChip, '1.5×'));
    await settle(tester);
    expect(find.textContaining('测试保存失败'), findsNothing);
    expect(container.read(readAloudPreferencesProvider).effectiveSpeed, 1.5);
  });

  testWidgets('手动速度写入后跟随开关写失败，不错误应用手动播放倍率', (tester) async {
    await open(tester, speed: true);
    failKey = 'ttsFollowSys';
    await tester.tap(find.widgetWithText(ChoiceChip, '1.5×'));
    await settle(tester);
    expect(saved['ttsSpeechRate'], '10');
    expect(container.read(readAloudPreferencesProvider).followSystem, isTrue);
    expect(container.read(readAloudPreferencesProvider).effectiveSpeed, 1);
    expect(find.textContaining('测试保存失败'), findsOneWidget);
    failKey = null;
    await tester.tap(find.widgetWithText(ChoiceChip, '1.5×'));
    await settle(tester);
    expect(container.read(readAloudPreferencesProvider).effectiveSpeed, 1.5);
  });

  for (final speed in [false, true]) {
    for (final size in [const Size(320, 568), const Size(640, 360)]) {
      testWidgets('面板布局 speed=$speed / $size / 大字体暗色', (tester) async {
        await open(tester, speed: speed, size: size, scale: 1.8, dark: true);
        expect(tester.takeException(), isNull);
        final item = speed
            ? find.widgetWithText(ChoiceChip, '3.0×')
            : find.byType(Switch);
        await tester.ensureVisible(item);
        await settle(tester);
        expect(item.hitTestable(), findsOneWidget);
        if (!speed) {
          await tester.ensureVisible(find.text('章节模式').first);
          await tester.tap(find.text('章节模式').first);
          await settle(tester);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
