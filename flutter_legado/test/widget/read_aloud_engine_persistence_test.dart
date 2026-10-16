import '../fixtures/app_test_api.dart';

// 朗读引擎双持久化 UI 测试（2026-10-04，对齐原版 SpeakEngineDialog）
//
// 覆盖两个入口：
// 1. 朗读条引擎对话框：底部「书」「取消」「全局」按钮（文案逐字对齐
//    values-zh/strings.xml：book=书:264、general=全局:1207）——「书」只写
//    当前书 readConfig.ttsEngine（SpeakEngineDialog.kt:164-170），「全局」
//    先清书级再写全局（:171-177）；行点击快捷路径保持既有行为（裸 URL 写
//    全局内存，read_aloud_engine_select_test.dart 钉住）。
// 2. 统一管理页：初始选中 = 有效引擎（书级优先）；点击行后选择书/全局范围，取消不落库。
import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud.dart';
import 'package:flutter_legado/src/widgets/reader/read_aloud_bar.dart';

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  const engineA = HttpTts(
    id: 1,
    name: '引擎甲',
    url: 'http://a.example/tts?text={{text}}',
  );
  const engineB = HttpTts(
    id: 2,
    name: '引擎乙',
    url: 'http://b.example/tts?text={{text}}',
  );
  const bookUrl = 'book-x';
  const urlA = 'http://a.example/tts?text={{text}}';
  const urlB = 'http://b.example/tts?text={{text}}';

  late MockRustApi api;
  late MockAudioService audioService;
  late FakeStreamAudioPlayer fakePlayer;
  late ProviderContainer container;
  late List<Book> savedBooks;
  late Map<String, String> configStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      kHttpTtsSeedVersionKey: kHttpTtsSeedVersion,
    });
    api = MockRustApi();
    audioService = MockAudioService();
    fakePlayer = FakeStreamAudioPlayer();
    savedBooks = [];
    configStore = {};
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        streamAudioPlayerProvider.overrideWithValue(fakePlayer),
        audioServiceProvider.overrideWithValue(audioService),
      ]),
    );
    addTearDown(container.dispose);

    when(() => audioService.dispose()).thenAnswer((_) async {});
    when(() => api.httpTtsRepository.getHttpTts())
        .thenAnswer((_) async => [engineA, engineB]);
    when(() => api.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => null);
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((invocation) async {
          final key = invocation.positionalArguments[0] as String;
          return configStore[key];
        });
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((invocation) async {
          final key = invocation.positionalArguments[0] as String;
          final value = invocation.positionalArguments[1] as String;
          configStore[key] = value;
        });
    when(() => api.bookshelfRepository.updateBook(any()))
        .thenAnswer((invocation) async {
          savedBooks.add(invocation.positionalArguments[0] as Book);
        });
  });

  AudioNotifier readNotifier() =>
      container.read(audioNotifierProvider.notifier);

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ReadAloudBar(
                  onDismiss: () {},
                  onOpenCatalog: () {},
                  onBackstage: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openEngineDialog(WidgetTester tester) async {
    await tester.tap(find.byTooltip('选择朗读引擎'));
    await tester.pumpAndSettle();
    expect(find.text('选择朗读引擎'), findsOneWidget);
  }

  /// 让 SnackBar 自动关闭计时器走完，避免用例结束残留 pending timer
  Future<void> settleSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  group('朗读条引擎对话框：双持久化按钮（原版 :164-177）', () {
    testWidgets('「书」按钮：只写当前书 readConfig.ttsEngine，不改全局', (tester) async {
      await pumpBar(tester);
      // 控制条挂载不写语速；绑定当前书后检查显式引擎保存。
      readNotifier().bindBook(const Book(bookUrl: bookUrl, name: '书'));
      readNotifier().updateConfig(engineUrl: urlB);
      await openEngineDialog(tester);

      // 原版文案逐字：书 / 取消 / 全局
      expect(find.widgetWithText(TextButton, '书'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '全局'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, '书'));
      await tester.pumpAndSettle();

      expect(savedBooks, hasLength(1));
      expect(savedBooks.single.bookUrl, bookUrl);
      expect(savedBooks.single.readConfig?.ttsEngine, '2');
      // 全局内存值保持「书」按钮前的状态（原版不改 AppConfig）
      expect(container.read(audioNotifierProvider).config.engineUrl, urlB);
      expect(find.text('已设为本书引擎：引擎乙'), findsOneWidget);
      await settleSnackBar(tester);
    });

    testWidgets('「全局」按钮：先清书级再写全局 config 键', (tester) async {
      await pumpBar(tester);
      readNotifier().bindBook(
        const Book(
          bookUrl: bookUrl,
          name: '书',
          readConfig: ReadConfig(ttsEngine: urlA),
        ),
      );
      await openEngineDialog(tester);

      await tester.tap(find.widgetWithText(TextButton, '全局'));
      await tester.pumpAndSettle();

      expect(savedBooks, hasLength(1));
      expect(savedBooks.single.readConfig?.ttsEngine, isNull);
      expect(configStore[kTtsEngineConfigKey], urlA);
      expect(container.read(audioNotifierProvider).config.engineUrl, urlA);
      expect(find.text('已设为全局引擎：引擎甲'), findsOneWidget);
      await settleSnackBar(tester);
    });

    testWidgets('无当前书：「书」按钮仍可点但如实提示（不静默假装成功）', (tester) async {
      readNotifier().updateConfig(engineUrl: urlB);
      await pumpBar(tester);
      await openEngineDialog(tester);

      await tester.tap(find.widgetWithText(TextButton, '书'));
      await tester.pumpAndSettle();

      expect(savedBooks, isEmpty);
      expect(find.text('未打开书籍，无法设为本书引擎'), findsOneWidget);
      await settleSnackBar(tester);
    });

    testWidgets('无匹配引擎（全局为空）：双按钮禁用', (tester) async {
      await pumpBar(tester);
      await openEngineDialog(tester);

      final bookBtn = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '书'),
      );
      final globalBtn = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '全局'),
      );
      expect(bookBtn.onPressed, isNull);
      expect(globalBtn.onPressed, isNull);
    });
  });

  group('管理页：点击引擎后按上游选择书或全局范围', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ReadAloudConfigScreen(initialTab: 1)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('不支持系统 TTS 的平台仍显示 HTTP 空列表提示', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        when(() => api.httpTtsRepository.getHttpTts())
            .thenAnswer((_) async => []);
        await pumpScreen(tester);
        expect(find.text('暂无朗读引擎'), findsOneWidget);
        expect(find.widgetWithText(ListTile, '系统 TTS'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('初始选中 = 有效引擎（书级优先）；取消范围选择不落库', (tester) async {
      readNotifier().bindBook(
        const Book(
          bookUrl: bookUrl,
          name: '书',
          readConfig: ReadConfig(ttsEngine: urlA),
        ),
      );
      await pumpScreen(tester);

      // 书级引擎甲高亮（radio checked），行点击不产生写库
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      // 两个 HTTP 选项加内置系统选项，只有书级引擎处于选中状态。
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
      final checkedTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('引擎甲'), matching: find.byType(ListTile)),
      );
      expect(checkedTile.selected, isTrue);

      await tester.tap(find.text('引擎乙'));
      await tester.pumpAndSettle();

      expect(savedBooks, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      final selected = tester.widget<ListTile>(
        find.ancestor(of: find.text('引擎甲'), matching: find.byType(ListTile)),
      );
      expect(selected.selected, true);
      expect(savedBooks, isEmpty);
    });

    testWidgets('「书」按钮：持久化选中引擎到当前书 readConfig.ttsEngine', (tester) async {
      when(() => api.bookshelfRepository.getBook(bookUrl))
          .thenAnswer((_) async => const Book(bookUrl: bookUrl, name: '书'));
      readNotifier().bindBook(const Book(bookUrl: bookUrl, name: '书'));
      await pumpScreen(tester);

      await tester.tap(find.text('引擎乙'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '书'));
      await tester.pumpAndSettle();

      expect(savedBooks, hasLength(1));
      expect(savedBooks.single.readConfig?.ttsEngine, '2');
      expect(find.text('已设为本书引擎'), findsOneWidget);
      await settleSnackBar(tester);
    });

    testWidgets('「全局」按钮：清书级 + 写全局 config 键', (tester) async {
      readNotifier().bindBook(
        const Book(
          bookUrl: bookUrl,
          name: '书',
          readConfig: ReadConfig(ttsEngine: urlA),
        ),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('引擎乙'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '全局'));
      await tester.pumpAndSettle();

      expect(savedBooks, hasLength(1));
      expect(savedBooks.single.readConfig?.ttsEngine, isNull);
      expect(configStore[kTtsEngineConfigKey], urlB);
      expect(container.read(audioNotifierProvider).config.engineUrl, urlB);
      expect(find.text('已设为全局引擎'), findsOneWidget);
      await settleSnackBar(tester);
    });

    testWidgets('编辑引擎：走 updateHttpTts 原地更新，保留 ID 与未展示高级字段；失败不删除原配置', (
      tester,
    ) async {
      const richEngine = HttpTts(
        id: 101,
        name: '富字段引擎',
        url: 'http://rich.example/tts?text={{text}}',
        contentType: 'audio/mpeg',
        pauseDuration: 180,
        concurrentRate: '1500',
        loginUrl: 'function login(){}',
        loginUi: '[{"name":"AppKey","type":"text"}]',
        header: '{"Authorization":"Bearer old"}',
        jsLib: 'var rich = 1;',
        enabledCookieJar: true,
        loginCheckJs: 'result',
        speed: 16,
        synthesisThreadCount: 4,
        lastUpdateTime: 1700000000111,
        isEnabled: false,
      );
      var currentList = <HttpTts>[richEngine];
      when(() => api.httpTtsRepository.getHttpTts())
          .thenAnswer((_) async => List.of(currentList));

      HttpTts? updatedArg;
      when(() => api.httpTtsRepository.updateHttpTts(any()))
          .thenAnswer((invocation) async {
            final arg = invocation.positionalArguments[0] as HttpTts;
            updatedArg = arg;
            currentList = [arg];
          });

      await pumpScreen(tester);
      await tester.tap(find.byTooltip('编辑').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '名称 *'),
        '富字段引擎-已改',
      );
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      verifyNever(() => api.httpTtsRepository.deleteHttpTts(any()));
      verifyNever(() => api.httpTtsRepository.addHttpTts(any()));
      verify(() => api.httpTtsRepository.updateHttpTts(any())).called(1);
      expect(updatedArg, isNotNull);
      expect(updatedArg!.id, 101);
      expect(updatedArg!.name, '富字段引擎-已改');
      expect(updatedArg!.pauseDuration, 180);
      expect(updatedArg!.concurrentRate, '1500');
      expect(updatedArg!.loginUrl, 'function login(){}');
      expect(updatedArg!.loginUi, '[{"name":"AppKey","type":"text"}]');
      expect(updatedArg!.jsLib, 'var rich = 1;');
      expect(updatedArg!.enabledCookieJar, isTrue);
      expect(updatedArg!.loginCheckJs, 'result');
      expect(updatedArg!.speed, 16);
      expect(updatedArg!.synthesisThreadCount, 4);
      expect(updatedArg!.isEnabled, isFalse);
      await settleSnackBar(tester);

      // 模拟更新失败：原记录保持不丢失，不调用删除
      when(() => api.httpTtsRepository.updateHttpTts(any()))
          .thenThrow(StateError('写库失败'));
      await tester.tap(find.byTooltip('编辑').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, '名称 *'),
        '富字段引擎-失败尝试',
      );
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      verifyNever(() => api.httpTtsRepository.deleteHttpTts(any()));
      expect(find.text('富字段引擎-已改'), findsOneWidget);
      expect(find.textContaining('保存失败'), findsOneWidget);
      await settleSnackBar(tester);
    });
  });
}
