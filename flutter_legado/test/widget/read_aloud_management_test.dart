import '../fixtures/app_test_api.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_credential_store.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_providers.dart';
import 'package:flutter_legado/src/features/read_aloud/http_tts_seed.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud_config_screen.dart';
import 'package:flutter_legado/src/widgets/app_settings_sheet.dart';
import 'package:flutter_legado/src/widgets/bottom_sheet_widget.dart';
import 'package:flutter_legado/src/features/read_aloud/tts_providers.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/platform/tts/system_tts.dart';
import 'package:flutter_legado/src/platform/tts/cloud_tts_credential_store.dart';
import 'package:flutter_legado/src/features/audio/application/audio_notifier.dart';
import 'package:flutter_legado/src/features/read_aloud/presentation/read_aloud_settings_screen.dart';
import 'package:flutter_legado/src/routes.dart';

import '../mocks/mocks.dart';

class _System extends Fake implements SystemTts {
  bool supported = false;
  List<SystemTtsVoice> voices = [];
  @override
  Future<List<SystemTtsVoice>> getVoices() async => List.of(voices);
  @override
  bool get isSupported => supported;
  @override
  bool get supportsEngineSelection => true;
  @override
  Future<List<String>> getEngines() async => ['fixture.engine'];
  @override
  String get selectedEngine => '';
  @override
  String get selectedVoice => '';
  @override
  Future<void> dispose() async {}
}

class _Credentials implements CloudTtsCredentialStore {
  final delegate = MemoryCloudTtsCredentialStore();
  final writes = <String>[];
  @override
  Future<String?> read(String key) => delegate.read(key);
  @override
  Future<void> write(String key, String value) async {
    writes.add(value);
    await delegate.write(key, value);
  }

  @override
  Future<void> delete(String key) => delegate.delete(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerFallbacks);
  late MockRustApi api;
  late _Credentials credentials;
  late _System system;
  late ProviderContainer container;
  late Map<String, String> config;
  final books = <Book>[];
  const cloud = CloudTtsEngine(
    id: 'ali',
    name: '百炼引擎',
    provider: 'alibaba_cloud',
    model: 'qwen3-tts-instruct-flash',
    credentialKey: 'cloud-tts:ali:fixture',
    optionsJson: '{"voiceId":"Cherry","instructions":"保持原指令","format":"wav"}',
  );
  ReadAloudVoice voice(String speaker) => ReadAloudVoice(
    id: readAloudVoiceId('cloud_tts', 'ali', speaker),
    engineType: 'cloud_tts',
    engineId: 'ali',
    speakerId: speaker,
    displayName: speaker,
    traitsJson: '{"instructions":"独立指令","format":"wav"}',
    managedBy: 'user',
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({
      kHttpTtsSeedVersionKey: kHttpTtsSeedVersion,
    });
    api = MockRustApi();
    credentials = _Credentials();
    system = _System();
    config = {};
    books.clear();
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((c) async => config[c.positionalArguments[0]]);
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((c) async {
          config[c.positionalArguments[0] as String] =
              c.positionalArguments[1] as String;
        });
    when(() => api.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => null);
    when(() => api.bookshelfRepository.updateBook(any())).thenAnswer((c) async {
      books.add(c.positionalArguments[0] as Book);
    });
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        systemTtsServiceProvider.overrideWithValue(system),
        cloudTtsCredentialStoreProvider.overrideWithValue(credentials),
        streamAudioPlayerProvider.overrideWithValue(FakeStreamAudioPlayer()),
        cloudTtsPreviewPlayerProvider.overrideWithValue(
          FakeStreamAudioPlayer(),
        ),
      ]),
    );
    addTearDown(container.dispose);
  });
  Future<void> pump(
    WidgetTester tester, {
    int tab = 0,
    Widget? screen,
    Size size = const Size(360, 640),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen ?? ReadAloudConfigScreen(initialTab: tab),
          routes: {
            AppRoutes.readAloudConfig: (_) => const ReadAloudConfigScreen(),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> engines(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Tab, '引擎'));
    await tester.pumpAndSettle();
  }

  void expectSharedList(WidgetTester tester, Finder row, String title) {
    final sheet = find.byType(AppBottomSheet);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text(title)),
      findsOneWidget,
    );
    final bounds = tester.getRect(sheet);
    expect(tester.getRect(row).left, closeTo(bounds.left, .01));
    expect(tester.getRect(row).right, closeTo(bounds.right, .01));
    expect(
      ListTileTheme.of(tester.element(row)).shape,
      const RoundedRectangleBorder(),
    );
    final header = find.descendant(
      of: sheet,
      matching: find.byType(NavigationToolbar),
    );
    expect(tester.widget<NavigationToolbar>(header).centerMiddle, isTrue);
    expect(
      tester
          .getCenter(find.descendant(of: header, matching: find.text(title)))
          .dx,
      closeTo(bounds.center.dx, .01),
    );
  }

  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets('添加引擎选择共用Sheet，边缘长按后进入编辑页 $size', (tester) async {
      await pump(tester, tab: 1, size: size, scale: 1.8);
      await tester.tap(find.byTooltip('添加引擎'));
      await tester.pumpAndSettle();
      final row = find.widgetWithText(ListTile, 'HTTP TTS');
      expectSharedList(tester, row, '添加引擎');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(row);
      final press = await tester.startGesture(
        Offset(bounds.left + 2, bounds.center.dy),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await press.up();
      await tester.pumpAndSettle();
      expect(find.byType(AppSettingsSheet), findsOneWidget);
      expect(find.text('添加 HTTP TTS 引擎'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('添加音色选择引擎共用Sheet，长列表可滚动且标题固定 $size', (tester) async {
      for (var i = 0; i < 16; i++) {
        await api.cloudTtsRepository.save(
          CloudTtsEngine(
            id: 'fixture-$i',
            name: '候选引擎$i',
            provider: 'alibaba_cloud',
            model: cloud.model,
            credentialKey: 'cloud-tts:fixture-$i:test',
          ),
        );
      }
      await pump(tester, size: size, scale: 1.8);
      await tester.tap(find.byTooltip('添加音色'));
      await tester.pumpAndSettle();
      final sheet = find.byType(AppBottomSheet);
      final first = find.widgetWithText(ListTile, '候选引擎0');
      expectSharedList(tester, first, '选择引擎');
      final title = find.descendant(of: sheet, matching: find.text('选择引擎'));
      final before = tester.getRect(title);
      final last = find.widgetWithText(ListTile, '候选引擎15');
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expect(tester.getRect(title), before);
      expect(last.hitTestable(), findsOneWidget);
      final bounds = tester.getRect(last);
      await tester.tapAt(Offset(bounds.right - 2, bounds.center.dy));
      await tester.pumpAndSettle();
      expect(find.byType(AppSettingsSheet), findsOneWidget);
      expect(find.text('添加音色'), findsWidgets);
      expect(find.text('候选引擎15'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        (await api.readAloudVoiceRepository.list()).where(
          (v) => v.managedBy == 'user',
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('引擎按云、HTTP、系统分类，独立卡片与系统引擎选择保留', (tester) async {
    system.supported = true;
    await api.cloudTtsRepository.save(cloud);
    when(() => api.httpTtsRepository.getHttpTts()).thenAnswer(
      (_) async => [
        const HttpTts(id: 8, name: 'HTTP 引擎', url: 'https://fixture.test/tts'),
      ],
    );
    await pump(tester, tab: 1);
    final cloudHeading = find.byKey(const ValueKey('engine-section-cloud'));
    final httpHeading = find.byKey(const ValueKey('engine-section-http'));
    final systemHeading = find.byKey(const ValueKey('engine-section-system'));
    final cloudTile = find.widgetWithText(ListTile, cloud.name);
    final httpTile = find.widgetWithText(ListTile, 'HTTP 引擎');
    final systemTile = find.widgetWithText(ListTile, '系统 TTS');
    expect(find.text('云 TTS'), findsOneWidget);
    expect(find.text('HTTP 协议 TTS'), findsOneWidget);
    expect(
      tester.getTopLeft(cloudHeading).dy,
      lessThan(tester.getTopLeft(cloudTile).dy),
    );
    expect(
      tester.getBottomLeft(cloudTile).dy,
      lessThanOrEqualTo(tester.getTopLeft(httpHeading).dy),
    );
    expect(
      tester.getTopLeft(httpHeading).dy,
      lessThan(tester.getTopLeft(httpTile).dy),
    );
    expect(
      tester.getBottomLeft(httpTile).dy,
      lessThanOrEqualTo(tester.getTopLeft(systemHeading).dy),
    );
    for (final tile in [cloudTile, httpTile]) {
      expect(
        find.ancestor(of: tile, matching: find.byType(Card)),
        findsOneWidget,
      );
    }
    await tester.ensureVisible(systemTile);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(systemHeading).dy,
      lessThan(tester.getTopLeft(systemTile).dy),
    );
    expect(
      find.ancestor(of: systemTile, matching: find.byType(Card)),
      findsOneWidget,
    );
    await tester.tap(systemTile);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '全局'));
    await tester.pumpAndSettle();
    expect(config[kTtsEngineConfigKey], systemTtsEngineUrl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('分类标题在空列表仍保留，不支持系统平台不生成系统引擎卡片', (tester) async {
    when(() => api.httpTtsRepository.getHttpTts()).thenAnswer((_) async => []);
    await pump(tester, tab: 1);
    expect(find.text('云 TTS'), findsOneWidget);
    expect(find.text('HTTP 协议 TTS'), findsOneWidget);
    expect(find.byKey(const ValueKey('engine-section-system')), findsOneWidget);
    expect(find.widgetWithText(ListTile, '系统 TTS'), findsNothing);
    expect(find.text('暂无朗读引擎'), findsOneWidget);
    expect(find.byTooltip('添加引擎'), findsOneWidget);
    expect(find.byTooltip('刷新'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('默认音色页无添加引擎 FAB，点击/滑动 Tab 同步，新增后返回刷新云端音色', (tester) async {
    await pump(tester);
    expect(find.byTooltip('添加引擎'), findsNothing);
    await engines(tester);
    expect(find.byTooltip('添加引擎'), findsOneWidget);
    expect(find.byTooltip('刷新'), findsNothing);
    await api.cloudTtsRepository.save(cloud);
    await api.readAloudVoiceRepository.save(voice('Cherry'));
    await api.readAloudVoiceRepository.save(voice('Serena'));
    await tester.drag(find.byType(TabBarView), const Offset(320, 0));
    await tester.pumpAndSettle();
    expect(find.byTooltip('添加引擎'), findsNothing);
    expect(find.byKey(ValueKey('voice-${voice('Cherry').id}')), findsOneWidget);
    expect(find.byKey(ValueKey('voice-${voice('Serena').id}')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HTTP 添加使用 Sheet，360dp 与键盘弹出时保存栏可见且长表单可滚动', (tester) async {
    final enginesList = <HttpTts>[];
    when(() => api.httpTtsRepository.getHttpTts())
        .thenAnswer((_) async => List.of(enginesList));
    when(() => api.httpTtsRepository.addHttpTts(any())).thenAnswer((c) async {
      enginesList.add((c.positionalArguments[0] as HttpTts).copyWith(id: 7));
      return enginesList.last;
    });
    await pump(tester, tab: 1);
    await tester.tap(find.byTooltip('添加引擎'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'HTTP TTS'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, '名称 *'),
      '新增 HTTP',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'URL *'),
      'http://fixture.test/tts?text={{speakText}}',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.widgetWithText(FilledButton, '保存')).bottom,
      lessThanOrEqualTo(400),
    );
    await tester.ensureVisible(find.text('高级配置'));
    await tester.tap(find.text('高级配置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextFormField, 'JS 库'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'JS 库'),
      'var keep = 1;',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(enginesList.single.name, '新增 HTTP');
    expect(enginesList.single.jsLib, 'var keep = 1;');
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('云端音色 Tab 保存选择保留源指令和凭据引用，取消云端添加不写配置', (tester) async {
    await api.cloudTtsRepository.save(cloud);
    await credentials.write(cloud.credentialKey, 'fixture-private');
    await api.readAloudVoiceRepository.save(voice('Serena'));
    await pump(tester);
    await tester.tap(find.byKey(ValueKey('voice-${voice('Serena').id}')));
    await tester.pumpAndSettle();
    var saved = (await api.cloudTtsRepository.list()).single;
    expect(saved.options['voiceId'], 'Cherry');
    expect(config['cloudTtsVoice:ali'], voice('Serena').id);
    expect(saved.options['instructions'], '保持原指令');
    expect(saved.credentialKey, cloud.credentialKey);
    expect(await credentials.read(saved.credentialKey), 'fixture-private');
    expect(
      tester
          .widget<ListTile>(find.byKey(ValueKey('voice-${voice('Serena').id}')))
          .selected,
      true,
    );
    await engines(tester);
    await tester.tap(find.byTooltip('添加引擎'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '云 TTS'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('cloud-apiKey')),
      'cancelled-key',
    );
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    saved = (await api.cloudTtsRepository.list()).single;
    expect(saved.id, cloud.id);
    expect(saved.options['voiceId'], 'Cherry');
    expect(config['cloudTtsVoice:ali'], voice('Serena').id);
    expect(credentials.writes, isNot(contains('cancelled-key')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('系统目录仅作为添加候选，取消不加入，保存后显示，刷新与删除不会自动填满列表', (tester) async {
    system.supported = true;
    system.voices = const [
      SystemTtsVoice(name: '候选中文一', locale: 'zh-CN', identifier: 'one'),
      SystemTtsVoice(name: '候选中文二', locale: 'zh-CN', identifier: 'two'),
    ];
    await pump(tester);
    expect((await api.readAloudVoiceRepository.list()).length, 2);
    expect(find.text('候选中文一'), findsNothing);
    expect(find.text('候选中文二'), findsNothing);
    expect(find.text('暂无音色，请点击右下角添加音色'), findsOneWidget);
    await tester.tap(find.text('显示已排除音色'));
    await tester.pumpAndSettle();
    expect(find.text('候选中文一'), findsNothing);
    Future<void> open() async {
      await tester.tap(find.byTooltip('添加音色'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(ListTile, '系统 TTS'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ActionChip, '候选中文一'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, '候选中文二'), findsOneWidget);
    }

    await open();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(
      (await api.readAloudVoiceRepository.list()).where(
        (v) => v.managedBy == 'user',
      ),
      isEmpty,
    );
    await open();
    await tester.tap(find.widgetWithText(ActionChip, '候选中文二'));
    await tester.enterText(find.byKey(const ValueKey('voice-name')), '我的中文声');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('我的中文声'), findsOneWidget);
    expect(find.text('候选中文一'), findsNothing);
    expect(find.text('候选中文二'), findsNothing);
    await tester.tap(find.byTooltip('刷新音色'));
    await tester.pumpAndSettle();
    final saved = (await api.readAloudVoiceRepository.list())
        .where((v) => v.managedBy == 'user')
        .single;
    expect(saved.speakerId, 'two');
    expect(saved.displayName, '我的中文声');
    expect(find.text('我的中文声'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除音色'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(find.text('我的中文声'), findsNothing);
    await tester.tap(find.byTooltip('刷新音色'));
    await tester.pumpAndSettle();
    expect(find.text('候选中文二'), findsNothing);
    expect(
      (await api.readAloudVoiceRepository.list()).where(
        (v) => v.managedBy == 'user',
      ),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('同一云端引擎可添加两个独立音色，编辑删除不改变引擎与其他音色', (tester) async {
    await api.cloudTtsRepository.save(cloud);
    await pump(tester);
    expect(find.byTooltip('添加音色'), findsOneWidget);
    expect(find.text('Cherry'), findsNothing);
    for (final speaker in ['Cherry', 'Serena']) {
      await tester.tap(find.byTooltip('添加音色'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, cloud.name));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, speaker));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('voice-style'))).dy -
            tester.getBottomLeft(find.byKey(const ValueKey('voice-name'))).dy,
        greaterThanOrEqualTo(12),
      );
      await tester.enterText(
        find.byKey(const ValueKey('voice-name')),
        '我的 $speaker',
      );
      await tester.enterText(
        find.byKey(const ValueKey('voice-instructions')),
        '$speaker 的独立指令',
      );
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
    }
    var rows = await api.readAloudVoiceRepository.list();
    expect(rows.length, 2);
    expect(rows.map((v) => v.speakerId), containsAll(['Cherry', 'Serena']));
    expect(
      (await api.cloudTtsRepository.list()).single.optionsJson,
      cloud.optionsJson,
    );
    final cherry = find.byKey(ValueKey('voice-${voice('Cherry').id}'));
    await tester.tap(
      find.descendant(
        of: cherry,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑音色'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('voice-name')),
      '改名的 Cherry',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('改名的 Cherry'), findsOneWidget);
    expect(find.text('我的 Serena'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: cherry,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除音色'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    rows = await api.readAloudVoiceRepository.list();
    expect(rows.single.speakerId, 'Serena');
    expect(
      (await api.cloudTtsRepository.list()).single.credentialKey,
      cloud.credentialKey,
    );
    await engines(tester);
    expect(find.byTooltip('试听'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('统一云端引擎行按书/全局范围持久化，页面没有常驻范围按钮', (tester) async {
    await api.cloudTtsRepository.save(cloud);
    container
        .read(audioNotifierProvider.notifier)
        .bindBook(const Book(bookUrl: 'book', name: '书籍'));
    await pump(tester, tab: 1);
    expect(find.widgetWithText(TextButton, '书'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('cloud-engine-ali')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '书'));
    await tester.pumpAndSettle();
    expect(books.last.readConfig?.ttsEngine, 'cloud://ali');
    await tester.tap(find.byKey(const ValueKey('cloud-engine-ali')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '全局'));
    await tester.pumpAndSettle();
    expect(books.last.readConfig?.ttsEngine, isNull);
    expect(config[kTtsEngineConfigKey], 'cloud://ali');
    expect(config['appTtsEngineId'], '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('目录旧行指向已删除引擎时拒绝保存，不恢复旧配置', (tester) async {
    await api.cloudTtsRepository.save(cloud);
    await api.readAloudVoiceRepository.save(voice('Serena'));
    await pump(tester);
    await api.cloudTtsRepository.delete(cloud.id);
    await tester.tap(find.byKey(ValueKey('voice-${voice('Serena').id}')));
    await tester.pumpAndSettle();
    expect(await api.cloudTtsRepository.list(), isEmpty);
    expect(find.textContaining('云端引擎不存在或已停用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('朗读设置移除重复系统语音入口，引擎页保留系统设置', (tester) async {
    system.supported = true;
    await pump(tester, screen: const ReadAloudSettingsScreen());
    final entry = find.text('朗读引擎与音色');
    await tester.scrollUntilVisible(
      entry,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    expect(entry, findsOneWidget);
    expect(find.text('云端朗读引擎'), findsNothing);
    expect(find.text('音色目录'), findsNothing);
    expect(find.text('系统语音'), findsNothing);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, '音色'), findsOneWidget);
    expect(find.widgetWithText(Tab, '引擎'), findsOneWidget);
    await engines(tester);
    expect(find.byTooltip('系统语音设置'), findsOneWidget);
    await tester.tap(find.byTooltip('系统语音设置'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownMenu<String>), findsOneWidget);
    expect(
      (tester
                  .widget<DropdownMenu<String>>(
                    find.byType(DropdownMenu<String>),
                  )
                  .label
              as Text)
          .data,
      '设备 TTS 引擎',
    );
    expect(find.text('语音'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, '关闭'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('朗读划分菜单与标点Sheet保存经过统一设置仓储', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ReadAloudSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('内容划分方式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按符号'));
    await tester.pumpAndSettle();
    expect(config['contentSplitMode'], 'symbols');
    await tester.tap(find.text('划分标点'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsSheet), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '，'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(config['contentSplitSymbols'], contains('，'));
    expect(find.byType(AppSettingsSheet), findsNothing);
  });
}
