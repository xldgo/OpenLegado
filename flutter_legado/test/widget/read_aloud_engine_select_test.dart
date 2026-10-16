import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_providers.dart';
// P0 缺陷回归：朗读条引擎选择器（2026-10-03）
//
// 背景：选择器曾把 '名称,URL' 复合串存入 TtsConfig.engineUrl，Rust tts_speak
// 把该值当 URL 模板与缓存键 → 选完引擎合成仍失败、朗读降级。修复后统一存裸
// URL；对话框当前项高亮改按 URL 匹配（不再 split(',') 取名）。
//
// 本用例走真实交互路径（点开引擎对话框 → 选中引擎），断言：
// 1) 选中后 config.engineUrl == engine.url（不含逗号）；
// 2) 重开对话框：当前 URL 映射到稳定引擎 ID 并高亮；
// 3) 存量「名称,URL」形态也能正确高亮（显示侧归一）。
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/platform/tts/system_tts.dart';
import 'package:flutter_legado/src/widgets/reader/read_aloud_bar.dart';

import '../mocks/mocks.dart';

class _CloudRepository extends Mock implements CloudTtsRepository {}

void main() {
  setUpAll(registerFallbacks);

  const engineName = '本地引擎';
  const engineUrl = 'http://192.168.1.2:8770/tts?text={{text}}';

  late MockRustApi api;
  late MockAudioService audioService;
  late FakeStreamAudioPlayer fakePlayer;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockRustApi();
    audioService = MockAudioService();
    fakePlayer = FakeStreamAudioPlayer();
    container = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWithValue(api),
        streamAudioPlayerProvider.overrideWithValue(fakePlayer),
        audioServiceProvider.overrideWithValue(audioService),
        cloudTtsRepositoryProvider.overrideWithValue(api.cloudTtsRepository),
      ],
    );
    addTearDown(container.dispose);

    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((_) async => null);
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((_) async {});
    when(() => api.httpTtsRepository.getHttpTts()).thenAnswer(
      (_) async => [const HttpTts(id: 1, name: engineName, url: engineUrl)],
    );
    when(() => audioService.dispose()).thenAnswer((_) async {});
  });

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

  testWidgets('选中引擎后 engineUrl 存裸 URL（不含逗号）', (tester) async {
    await pumpBar(tester);
    await openEngineDialog(tester);

    await tester.tap(find.text(engineName));
    await tester.pumpAndSettle();

    final stored = container.read(audioNotifierProvider).config.engineUrl;
    expect(stored, engineUrl);
    expect(stored.contains(','), isFalse);
    expect(find.text('已切换引擎：$engineName'), findsOneWidget);

    await settleSnackBar(tester);
  });

  testWidgets('控制条挂载和重开不重置当前语速或写配置', (tester) async {
    container
        .read(audioNotifierProvider.notifier)
        .updateConfig(speed: 1.8, persistBookSpeed: false);
    await pumpBar(tester);
    expect(container.read(audioNotifierProvider).config.speed, 1.8);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpBar(tester);
    expect(container.read(audioNotifierProvider).config.speed, 1.8);
    verifyNever(() => api.configRepository.setConfig(any(), any()));
  });

  testWidgets('没有 HTTP 引擎时可选择系统 TTS，并保存固定标识', (tester) async {
    when(() => api.httpTtsRepository.getHttpTts()).thenAnswer((_) async => []);
    await pumpBar(tester);
    await openEngineDialog(tester);
    expect(find.text('系统 TTS'), findsOneWidget);
    await tester.tap(find.text('系统 TTS'));
    await tester.pumpAndSettle();
    expect(
      container.read(audioNotifierProvider).config.engineUrl,
      systemTtsEngineUrl,
    );
    verify(
      () => api.configRepository.setConfig(
        kTtsEngineConfigKey,
        systemTtsEngineUrl,
      ),
    ).called(1);
    verifyNever(() => api.httpTtsRepository.addHttpTts(any()));
    await settleSnackBar(tester);
  });

  testWidgets('重开对话框：当前 URL 映射到稳定引擎 ID 并高亮', (tester) async {
    await pumpBar(tester);
    container
        .read(audioNotifierProvider.notifier)
        .updateConfig(engineUrl: engineUrl);
    await tester.pump();

    await openEngineDialog(tester);

    final group = tester.widget<RadioGroup<String>>(
      find.byType(RadioGroup<String>),
    );
    expect(group.groupValue, 'id:1');

    // 关闭对话框：点选当前项（幂等，仍写入裸 URL）
    await tester.tap(find.text(engineName));
    await tester.pumpAndSettle();
    await settleSnackBar(tester);
  });

  testWidgets('点击已选中的引擎项：对话框关闭（已项不再吞点击）', (tester) async {
    await pumpBar(tester);
    container
        .read(audioNotifierProvider.notifier)
        .updateConfig(engineUrl: engineUrl);
    await tester.pump();

    await openEngineDialog(tester);
    expect(find.text('选择朗读引擎'), findsOneWidget);

    // 已选中项：RadioListTile 默认对 checked 直接 return（本版无 onTap 参数）；
    // 修复后（toggleable + onChanged 兜底当前项）点击应关闭对话框
    await tester.tap(find.text(engineName));
    await tester.pumpAndSettle();

    expect(find.text('选择朗读引擎'), findsNothing);
    await settleSnackBar(tester);
  });

  testWidgets('存量「名称,URL」形态：显示侧归一并正确高亮', (tester) async {
    await pumpBar(tester);
    container
        .read(audioNotifierProvider.notifier)
        .updateConfig(engineUrl: '$engineName,$engineUrl');
    await tester.pump();

    await openEngineDialog(tester);

    final group = tester.widget<RadioGroup<String>>(
      find.byType(RadioGroup<String>),
    );
    expect(group.groupValue, 'id:1');

    // 关闭对话框：RadioGroup 对已选中项不再回调 onChanged，点遮罩收起
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  });
  testWidgets('云端选择复用全局引擎设置，重开仍显示选中', (tester) async {
    await api.cloudTtsRepository.save(
      const CloudTtsEngine(
        id: 'fixture',
        name: '云端测试',
        credentialKey: 'cloud-tts:fixture:key',
      ),
    );
    await pumpBar(tester);
    await openEngineDialog(tester);
    await tester.tap(find.text('云端测试'));
    await tester.pumpAndSettle();
    expect(
      container.read(audioNotifierProvider).config.engineUrl,
      'cloud://fixture',
    );
    await settleSnackBar(tester);
    await openEngineDialog(tester);
    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'cloud://fixture',
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  });
  testWidgets('云端列表失败不阻断 HTTP 引擎选择', (tester) async {
    final repository = _CloudRepository();
    when(repository.list).thenThrow(StateError('fixture 云端读取失败'));
    container.updateOverrides([
      bookApiProvider.overrideWithValue(api),
      streamAudioPlayerProvider.overrideWithValue(fakePlayer),
      audioServiceProvider.overrideWithValue(audioService),
      cloudTtsRepositoryProvider.overrideWithValue(repository),
    ]);
    await pumpBar(tester);
    await openEngineDialog(tester);
    expect(find.text(engineName), findsOneWidget);
    await tester.tap(find.text(engineName));
    await tester.pumpAndSettle();
    expect(container.read(audioNotifierProvider).config.engineUrl, engineUrl);
    await settleSnackBar(tester);
    expect(tester.takeException(), isNull);
  });
}
