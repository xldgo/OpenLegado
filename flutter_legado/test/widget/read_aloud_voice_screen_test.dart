import '../fixtures/app_test_api.dart';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/features/audio/application/audio_notifier.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/data/repositories/mock_read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/platform/tts/system_tts.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud_voice_panel.dart';
import 'package:flutter_legado/src/features/read_aloud/tts_providers.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud_voice_sheet.dart';
import 'package:flutter_legado/src/data/services/http_tts_export_document.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_providers.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';

import '../mocks/mocks.dart';

class _System extends Fake implements SystemTts {
  @override
  bool get isSupported => false;
  @override
  String get selectedEngine => '';
  @override
  String get selectedVoice => '';
  @override
  Future<void> dispose() async {}
}

class _Api extends MockRustApi {
  final voices = MockReadAloudVoiceRepository();
  @override
  ReadAloudVoiceRepository get readAloudVoiceRepository => voices;
}

void main() {
  setUpAll(registerFallbacks);
  void testVoice(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        final panel = find.byType(ReadAloudVoicePanel);
        if (tester.any(panel)) {
          await tester.state<ReadAloudVoicePanelState>(panel).stopPreview();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });
  }

  testVoice('编辑已选预设后情感写回默认值，保留标签并用于列表试听', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = _Api();
    api.voices.importHttp(1, {
      'speakersJson': '[{"speakerName":"角色","toneID":"a","tags":["女"]}]',
      'emotionsJson': '[{"emotionName":"高兴","emotionTag":"happy"},{"emotionName":"平静","emotionTag":"calm"}]',
    });
    final voice = (await api.voices.list()).single;
    await api.voices.save(
      voice.copyWith(traitsJson: '{"tags":["女"],"emotionTag":"happy"}'),
    );
    final settings = <String, String>{
      'ttsVoice:1': jsonEncode({'voiceId': voice.id, 'emotionTag': 'happy'}),
    };
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((call) async => settings[call.positionalArguments[0]]);
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((call) async {
          settings[call.positionalArguments[0] as String] =
              call.positionalArguments[1] as String;
        });
    final emotions = <String?>[];
    when(
      () => api.httpTtsSynthesizer.synthesize(
        engineId: any(named: 'engineId'),
        text: any(named: 'text'),
        engineUrl: any(named: 'engineUrl'),
        speed: any(named: 'speed'),
        pitch: any(named: 'pitch'),
        volume: any(named: 'volume'),
        voiceName: any(named: 'voiceName'),
        toneId: any(named: 'toneId'),
        speakerName: any(named: 'speakerName'),
        emotionTag: any(named: 'emotionTag'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((call) async {
      emotions.add(call.namedArguments[#emotionTag] as String?);
      return const HttpTtsAudio(audioPath: '/voice.wav');
    });
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...api.overrides,
          systemTtsServiceProvider.overrideWithValue(_System()),
          streamAudioPlayerProvider.overrideWithValue(FakeStreamAudioPlayer()),
          cloudTtsPreviewPlayerProvider.overrideWithValue(
            FakeStreamAudioPlayer(),
          ),
        ]),
        child: const MaterialApp(home: Scaffold(body: ReadAloudVoicePanel())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑音色'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadAloudVoiceSheet), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, '平静'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final saved = (await api.voices.list()).single;
    expect(saved.id, voice.id);
    expect(jsonDecode(saved.traitsJson), {
      'tags': ['女'],
      'emotionTag': 'calm',
    });
    expect(jsonDecode(settings['ttsVoice:1']!)['emotionTag'], isNull);
    await tester.tap(find.byTooltip('试听'));
    await tester.pumpAndSettle();
    expect(emotions, ['calm']);
    final exported = (jsonDecode(
      httpTtsExportDocument([const HttpTts(id: 1)], [saved]),
    ) as List).single;
    expect(jsonDecode(exported['speakersJson']).single['tags'], ['女']);
    expect(tester.takeException(), isNull);
  });
  testVoice('选择情感写入独立设置并显示选中，排除隐藏、恢复保持选择', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = _Api();
    final settings = <String, String>{};
    api.voices.importHttp(1, {
      'speakersJson': '[{"name":"中文女声","toneID":"a"}]',
      'emotionsJson': '[{"name":"高兴","tag":"happy"}]',
    });
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((call) async => settings[call.positionalArguments[0]]);
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((call) async {
          settings[call.positionalArguments[0] as String] =
              call.positionalArguments[1] as String;
        });
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...api.overrides,
          systemTtsServiceProvider.overrideWithValue(_System()),
          streamAudioPlayerProvider.overrideWithValue(FakeStreamAudioPlayer()),
          cloudTtsPreviewPlayerProvider.overrideWithValue(
            FakeStreamAudioPlayer(),
          ),
        ]),
        child: const MaterialApp(home: Scaffold(body: ReadAloudVoicePanel())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文女声'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('高兴'));
    await tester.pumpAndSettle();
    final saved = jsonDecode(settings['ttsVoice:1']!);
    expect(saved['emotionTag'], 'happy');
    // 情感传给合成器由试听单测及上一个界面用例覆盖，这里只验证选择与管理。
    expect(find.textContaining('已选择'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('排除音色'));
    await tester.pumpAndSettle();
    expect((await api.voices.list()).single.excluded, true);
    expect(find.text('中文女声'), findsNothing);
    await tester.tap(find.text('显示已排除音色'));
    await tester.pumpAndSettle();
    expect(find.text('中文女声'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复音色'));
    await tester.pumpAndSettle();
    expect((await api.voices.list()).single.excluded, false);
    expect(find.textContaining('已选择'), findsOneWidget);
    final tile = find.ancestor(
      of: find.text('中文女声'),
      matching: find.byType(ListTile),
    );
    await tester.tap(find.descendant(of: tile, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect((await api.voices.list()).single.enabled, false);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用引擎默认音色'));
    await tester.pumpAndSettle();
    expect(settings['ttsVoice:1'], '');
    expect(find.textContaining('已选择'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
