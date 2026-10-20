import 'dart:convert';

import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_engine_sheet.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud_voice_sheet.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/widgets/bottom_sheet_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    Widget Function() sheet,
    void Function(Object?) result,
  ) async {
    tester.view.physicalSize = const Size(480, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result(
                await AppBottomSheet.showContent<Object>(
                  context: context,
                  builder: (_) => sheet(),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets('V3 引擎独立选择，只配置资源 ID 和 API Key', (tester) async {
    CloudTtsEditResult? result;
    await open(
      tester,
      () => const CloudTtsEngineSheet(),
      (v) => result = v as CloudTtsEditResult?,
    );
    await tester.tap(find.byKey(const ValueKey('cloud-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('火山引擎（V3／豆包 2.0）').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cloud-region')), findsNothing);
    expect(find.byKey(const ValueKey('cloud-appId')), findsNothing);
    expect(find.byKey(const ValueKey('cloud-secretKey')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cloud-model')))
          .controller!
          .text,
      'seed-tts-2.0',
    );
    await tester.enterText(
      find.byKey(const ValueKey('cloud-apiKey')),
      'private-key',
    );
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(result!.engine.provider, 'volcengine_v3');
    expect(result!.engine.model, 'seed-tts-2.0');
    expect(result!.key, 'private-key');
    expect(jsonEncode(result!.engine.toJson()), isNot(contains('private-key')));
  });
  testWidgets('V3 音色倍率、风格指令和试听保存一致', (tester) async {
    ReadAloudVoice? result, preview;
    await open(
      tester,
      () => ReadAloudVoiceSheet(
        source: const VoiceEditorSource(
          kind: 'cloud_tts',
          id: 'v3',
          name: 'V3',
          provider: 'volcengine_v3',
          voices: [
            ReadAloudVoice(
              id: 'candidate',
              engineType: 'cloud_tts',
              engineId: 'v3',
              speakerId: 'zh_female_vv_uranus_bigtts',
              displayName: 'Vivi 2.0',
            ),
          ],
        ),
        onPreview: (v, _) async {
          preview = v;
        },
        onStop: () async {},
      ),
      (v) => result = v as ReadAloudVoice?,
    );
    for (final field in ['voice-role', 'voice-locale']) {
      expect(find.byKey(ValueKey(field)), findsNothing);
    }
    await tester.enterText(find.byKey(const ValueKey('voice-speed')), '0.5');
    await tester.enterText(find.byKey(const ValueKey('voice-pitch')), '2');
    await tester.enterText(find.byKey(const ValueKey('voice-volume')), '2');
    await tester.enterText(find.byKey(const ValueKey('voice-style')), '平静');
    await tester.enterText(
      find.byKey(const ValueKey('voice-instructions')),
      '保持停顿',
    );
    await tester.ensureVisible(find.text('试听'));
    await tester.tap(find.text('试听'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(result!.speakerId, 'zh_female_vv_uranus_bigtts');
    expect(result!.traitsJson, preview!.traitsJson);
    expect(jsonDecode(result!.traitsJson), {
      'speed': 0.5,
      'pitch': 2.0,
      'volume': 2.0,
      'style': '平静',
      'instructions': '保持停顿',
      'format': 'mp3',
    });
    expect(tester.takeException(), isNull);
  });
}
