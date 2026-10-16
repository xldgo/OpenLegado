import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/features/read_aloud/http_tts_seed.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud_config_screen.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_providers.dart';
import 'package:flutter_legado/src/platform/tts/cloud_tts_credential_store.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';

import '../mocks/mocks.dart';

MockRustApi _api() {
  final api = MockRustApi();
  when(() => api.configRepository.getConfig(any()))
      .thenAnswer((_) async => null);
  when(() => api.configRepository.setConfig(any(), any()))
      .thenAnswer((_) async {});
  return api;
}

Future<void> _openCloudEditor(WidgetTester tester) async {
  await tester.tap(find.byTooltip('添加引擎'));
  await tester.pumpAndSettle();
  expect(find.byType(BottomSheet), findsOneWidget);
  await tester.tap(find.widgetWithText(ListTile, '云 TTS'));
  await tester.pumpAndSettle();
  expect(find.byType(BottomSheet), findsOneWidget);
  expect(find.byType(AlertDialog), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerFallbacks);
  testWidgets('添加/编辑保留设备凭据，API Key 不显示；删除清理两侧', (tester) async {
    SharedPreferences.setMockInitialValues({
      kHttpTtsSeedVersionKey: kHttpTtsSeedVersion,
    });
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _api();
    final credentials = MemoryCloudTtsCredentialStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWithValue(api),
          cloudTtsCredentialStoreProvider.overrideWithValue(credentials),
          cloudTtsPreviewPlayerProvider.overrideWithValue(
            FakeStreamAudioPlayer(),
          ),
          streamAudioPlayerProvider.overrideWithValue(FakeStreamAudioPlayer()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ReadAloudConfigScreen(initialTab: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openCloudEditor(tester);
    await tester.enterText(find.byKey(const ValueKey('cloud-name')), '云端测试');
    await tester.enterText(
      find.byKey(const ValueKey('cloud-apiKey')),
      'fixture-private',
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('cloud-apiKey')),
              matching: find.byType(TextField),
            ),
          )
          .obscureText,
      true,
    );
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    var saved = (await api.cloudTtsRepository.list()).single;
    final id = saved.id;
    final key = saved.credentialKey;
    expect(await credentials.read(key), 'fixture-private');
    expect(find.text('云端测试'), findsOneWidget);
    expect(saved.toJson().values, isNot(contains('fixture-private')));
    await tester.tap(find.byTooltip('编辑云端引擎'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cloud-apiKey')))
          .controller!
          .text,
      '',
    );
    await tester.enterText(find.byKey(const ValueKey('cloud-name')), '新名称');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    saved = (await api.cloudTtsRepository.list()).single;
    expect(saved.id, id);
    expect(saved.credentialKey, key);
    expect(saved.name, '新名称');
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(await api.cloudTtsRepository.list(), isEmpty);
    expect(await credentials.read(key), isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('新建 MiMo 使用模型/音色/WAV 默认值，切换服务商清空旧密钥，编辑保留 Provider', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      kHttpTtsSeedVersionKey: kHttpTtsSeedVersion,
    });
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _api();
    final credentials = MemoryCloudTtsCredentialStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWithValue(api),
          cloudTtsCredentialStoreProvider.overrideWithValue(credentials),
          cloudTtsPreviewPlayerProvider.overrideWithValue(
            FakeStreamAudioPlayer(),
          ),
          streamAudioPlayerProvider.overrideWithValue(FakeStreamAudioPlayer()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ReadAloudConfigScreen(initialTab: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openCloudEditor(tester);
    await tester.enterText(
      find.byKey(const ValueKey('cloud-apiKey')),
      'previous-service-key',
    );
    await tester.enterText(
      find.byKey(const ValueKey('cloud-baseUrl')),
      'https://old-provider.example/v1',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('cloud-provider')));
    await tester.tap(find.byKey(const ValueKey('cloud-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xiaomi MiMo').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cloud-apiKey')))
          .controller!
          .text,
      '',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cloud-model')))
          .controller!
          .text,
      'mimo-v2.5-tts',
    );
    expect(find.byKey(const ValueKey('cloud-voiceId')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cloud-baseUrl')))
          .controller!
          .text,
      '',
    );
    expect(find.byKey(const ValueKey('cloud-speed')), findsNothing);
    expect(find.byType(DropdownMenu<String>), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('cloud-apiKey')),
      'mimo-fixture-key',
    );
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final saved = (await api.cloudTtsRepository.list()).single;
    expect(saved.provider, 'mimo');
    expect(saved.options, isEmpty);
    expect(saved.options, isEmpty);
    expect(saved.options.containsKey('speed'), false);
    expect(await credentials.read(saved.credentialKey), 'mimo-fixture-key');
    await tester.tap(find.byTooltip('编辑云端引擎'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('cloud-provider')),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cloud-apiKey')))
          .controller!
          .text,
      '',
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('新建百炼 使用模型/音色/WAV 默认值，切换服务商清空旧密钥，编辑保留 Provider', (tester) async {
    SharedPreferences.setMockInitialValues({
      kHttpTtsSeedVersionKey: kHttpTtsSeedVersion,
    });
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _api();
    final credentials = MemoryCloudTtsCredentialStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWithValue(api),
          cloudTtsCredentialStoreProvider.overrideWithValue(credentials),
          cloudTtsPreviewPlayerProvider.overrideWithValue(
            FakeStreamAudioPlayer(),
          ),
          streamAudioPlayerProvider.overrideWithValue(FakeStreamAudioPlayer()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ReadAloudConfigScreen(initialTab: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openCloudEditor(tester);
    await tester.enterText(
      find.byKey(const ValueKey('cloud-apiKey')),
      'previous-service-key',
    );
    await tester.enterText(
      find.byKey(const ValueKey('cloud-baseUrl')),
      'https://old-provider.example/v1',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('cloud-provider')));
    await tester.tap(find.byKey(const ValueKey('cloud-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('阿里云百炼').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cloud-apiKey')))
          .controller!
          .text,
      '',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cloud-model')))
          .controller!
          .text,
      'qwen3-tts-flash',
    );
    expect(find.byKey(const ValueKey('cloud-voiceId')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cloud-baseUrl')))
          .controller!
          .text,
      '',
    );
    expect(find.byKey(const ValueKey('cloud-speed')), findsNothing);
    expect(find.byType(DropdownMenu<String>), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('cloud-apiKey')),
      'alibaba-fixture-key',
    );
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final saved = (await api.cloudTtsRepository.list()).single;
    expect(saved.provider, 'alibaba_cloud');
    expect(saved.options, isEmpty);
    expect(saved.options, isEmpty);
    expect(saved.options, isEmpty);
    expect(saved.options.containsKey('speed'), false);
    expect(await credentials.read(saved.credentialKey), 'alibaba-fixture-key');
    await tester.tap(find.byTooltip('编辑云端引擎'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('cloud-provider')),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cloud-apiKey')))
          .controller!
          .text,
      '',
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
