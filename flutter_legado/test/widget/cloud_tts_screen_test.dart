import 'dart:async';

import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_screen.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_providers.dart';
import 'package:flutter_legado/src/platform/tts/cloud_tts_credential_store.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';

import '../mocks/mocks.dart';

class _PreviewSynthesizer implements CloudTtsSynthesizer {
  Completer<HttpTtsSynthesisResult>? pending;
  HttpTtsCancellation? cancellation;
  Object? error;
  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required String engineId,
    required String text,
    HttpTtsCancellation? cancellation,
  }) async {
    this.cancellation = cancellation;
    if (error != null) throw error!;
    return pending?.future ??
        const HttpTtsAudio(audioPath: '/fixture/preview.wav');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerFallbacks);
  testWidgets('添加/编辑保留设备凭据，API Key 不显示；删除清理两侧', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = MockRustApi();
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
        child: const MaterialApp(home: CloudTtsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加云端引擎'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('云端测试'));
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
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(await api.cloudTtsRepository.list(), isEmpty);
    expect(await credentials.read(key), isNull);
    expect(tester.takeException(), isNull);
  });
  for (final failure in [false, true]) {
    testWidgets(failure ? '试听失败清除停止状态，不误报正在播放' : '退出试听取消在途合成，迟到音频不播放', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockRustApi();
      await api.cloudTtsRepository.save(
        const CloudTtsEngine(
          id: 'fixture',
          name: '试听引擎',
          credentialKey: 'cloud-tts:fixture:key',
        ),
      );
      final synth = _PreviewSynthesizer();
      if (failure) {
        synth.error = StateError('fixture 合成失败');
      } else {
        synth.pending = Completer<HttpTtsSynthesisResult>();
      }
      final preview = FakeStreamAudioPlayer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookApiProvider.overrideWithValue(api),
            cloudTtsPreviewPlayerProvider.overrideWithValue(preview),
            cloudTtsSynthesizerProvider.overrideWithValue(synth),
            streamAudioPlayerProvider.overrideWithValue(
              FakeStreamAudioPlayer(),
            ),
          ],
          child: const MaterialApp(home: CloudTtsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('试听'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '试听'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      if (failure) {
        expect(find.textContaining('fixture 合成失败'), findsOneWidget);
        expect(find.text('停止试听'), findsNothing);
      } else {
        expect(synth.cancellation, isNotNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(synth.cancellation!.isCancelled, true);
        synth.pending!.complete(
          const HttpTtsAudio(audioPath: '/fixture/late.wav'),
        );
        await tester.pumpAndSettle();
        expect(preview.disposeCount, 1);
      }
      expect(preview.playedLocalFiles, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('新建 MiMo 使用模型/音色/WAV 默认值，切换服务商清空旧密钥，编辑保留 Provider', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = MockRustApi();
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
        child: const MaterialApp(home: CloudTtsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加云端引擎'));
    await tester.pumpAndSettle();
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
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cloud-voiceId')))
          .controller!
          .text,
      'mimo_default',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cloud-baseUrl')))
          .controller!
          .text,
      '',
    );
    expect(find.byKey(const ValueKey('cloud-speed')), findsNothing);
    final format = tester.widget<DropdownMenu<String>>(
      find.byKey(const ValueKey('cloud-format-mimo')),
    );
    expect(format.dropdownMenuEntries.map((e) => e.value), ['wav']);
    await tester.enterText(
      find.byKey(const ValueKey('cloud-apiKey')),
      'mimo-fixture-key',
    );
    await tester.ensureVisible(find.text('冰糖'));
    await tester.tap(find.text('冰糖'));
    await tester.ensureVisible(find.text('平静'));
    await tester.tap(find.text('平静'));
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final saved = (await api.cloudTtsRepository.list()).single;
    expect(saved.provider, 'mimo');
    expect(saved.options['format'], 'wav');
    expect(saved.options['voiceId'], '冰糖');
    expect(saved.options['style'], '平静');
    expect(saved.options.containsKey('speed'), false);
    expect(await credentials.read(saved.credentialKey), 'mimo-fixture-key');
    await tester.tap(find.text('Xiaomi MiMo'));
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
