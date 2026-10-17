import '../fixtures/app_test_api.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_legado/src/domain/contracts/http_tts_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/imports/application/association_notifier.dart';
import 'package:flutter_legado/src/features/audio/application/audio_notifier.dart';
import 'package:flutter_legado/src/widgets/reader/read_aloud_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

class _Engines extends Mock implements HttpTtsRepository {}

void main() {
  late _Engines engines;
  late MockRustApi api;
  late ProviderContainer container;
  const engine = HttpTts(
    id: 7,
    name: '窄接口引擎',
    url: 'http://tts.test/?text={{text}}',
  );
  setUpAll(registerFallbacks);
  setUp(() {
    SharedPreferences.setMockInitialValues({
      kHttpTtsSeedVersionKey: kHttpTtsSeedVersion,
    });
    api = MockRustApi();
    engines = _Engines();
    final audio = MockAudioService();
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((_) async => null);
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((_) async {});
    when(() => audio.dispose()).thenAnswer((_) async {});
    when(() => engines.getHttpTts()).thenAnswer((_) async => [engine]);
    when(() => api.httpTtsRepository.getHttpTts())
        .thenThrow(StateError('不应读取根接口中的其他引擎实例'));
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        httpTtsRepositoryProvider.overrideWithValue(engines),
        audioServiceProvider.overrideWithValue(audio),
        streamAudioPlayerProvider.overrideWithValue(FakeStreamAudioPlayer()),
      ]),
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('配置页独立读取窄接口，加载与刷新不落到根实现', (tester) async {
    await pump(tester, const ReadAloudConfigScreen(initialTab: 1));
    expect(find.text(engine.name), findsOneWidget);
    verify(() => engines.getHttpTts()).called(1);
    verifyNever(() => api.httpTtsRepository.getHttpTts());
    expect(tester.takeException(), isNull);
  });

  testWidgets('正文朗读条选择器复用窄接口，引擎 URL 不变', (tester) async {
    await pump(
      tester,
      Stack(
        children: [
          ReadAloudBar(
            onDismiss: () {},
            onOpenCatalog: () {},
            onBackstage: () {},
          ),
        ],
      ),
    );
    await tester.tap(find.byTooltip('选择朗读引擎'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(engine.name));
    await tester.pumpAndSettle();
    expect(container.read(audioNotifierProvider).config.engineUrl, engine.url);
    verify(() => engines.getHttpTts()).called(1);
    verifyNever(() => api.httpTtsRepository.getHttpTts());
    expect(tester.takeException(), isNull);
  });

  test('关联导入的本地快照与确认写入共用窄接口', () async {
    final dir = Directory.systemTemp.createTempSync('legado-http-tts-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final input = [
      engine.toJson(),
      const HttpTts(name: '新增', url: 'http://new').toJson(),
    ];
    final file = File('${dir.path}${Platform.pathSeparator}engines.json')
      ..writeAsStringSync(jsonEncode(input));
    final notifier = container.read(associationNotifierProvider.notifier);
    await notifier.loadFromFile(file.path);
    final state = container.read(associationNotifierProvider);
    expect(state.error, isNull);
    expect(state.type, ImportType.httpTts);
    expect(state.items.map((e) => e.status), [
      ImportItemStatus.exists,
      ImportItemStatus.isNew,
    ]);
    when(() => engines.importHttpTts(jsonEncode(input)))
        .thenAnswer((_) async => 2);
    final result = await notifier.confirmImport(ImportType.httpTts, input);
    expect(result.success, 2);
    expect(result.failed, 0);
    verify(() => engines.getHttpTts()).called(1);
    verify(() => engines.importHttpTts(jsonEncode(input))).called(1);
    verifyNever(() => api.httpTtsRepository.getHttpTts());
    verifyNever(() => api.httpTtsRepository.importHttpTts(any()));
  });

  test('关联导入保留失败状态与原错误，不伪造成功', () async {
    const input = <Map<String, dynamic>>[
      {'name': '失败', 'url': 'http://a'},
    ];
    when(() => engines.importHttpTts(jsonEncode(input)))
        .thenThrow(StateError('写入失败'));
    final result = await container
        .read(associationNotifierProvider.notifier)
        .confirmImport(ImportType.httpTts, input);
    expect(result.success, 0);
    expect(result.failed, 1);
    expect(container.read(associationNotifierProvider).isLoading, isFalse);
    expect(container.read(associationNotifierProvider).error, contains('写入失败'));
    verifyNever(() => api.httpTtsRepository.importHttpTts(any()));
  });
}
