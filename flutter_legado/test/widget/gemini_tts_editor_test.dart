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

  testWidgets('Gemini 引擎只配置模型和 API Key，默认使用 3.8', (tester) async {
    CloudTtsEditResult? result;
    await open(
      tester,
      () => const CloudTtsEngineSheet(),
      (v) => result = v as CloudTtsEditResult?,
    );
    await tester.tap(find.byKey(const ValueKey('cloud-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini TTS').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cloud-region')), findsNothing);
    expect(find.byKey(const ValueKey('cloud-appId')), findsNothing);
    expect(find.byKey(const ValueKey('cloud-secretKey')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cloud-model')))
          .controller!
          .text,
      'gemini-3.8-flash-tts',
    );
    await tester.enterText(
      find.byKey(const ValueKey('cloud-apiKey')),
      'private-key',
    );
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(result!.engine.provider, 'gemini_tts');
    expect(result!.engine.model, 'gemini-3.8-flash-tts');
    expect(result!.key, 'private-key');
    expect(jsonEncode(result!.engine.toJson()), isNot(contains('private-key')));
  });
  testWidgets('Gemini 音色独立设置风格和指令，试听与保存参数一致', (tester) async {
    ReadAloudVoice? result, preview;
    await open(
      tester,
      () => ReadAloudVoiceSheet(
        source: const VoiceEditorSource(
          kind: 'cloud_tts',
          id: 'gemini',
          name: 'Gemini',
          provider: 'gemini_tts',
          voices: [
            ReadAloudVoice(
              id: 'candidate',
              engineType: 'cloud_tts',
              engineId: 'gemini',
              speakerId: 'Kore',
              displayName: 'Kore',
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
    for (final field in [
      'voice-role',
      'voice-speed',
      'voice-pitch',
      'voice-volume',
      'voice-locale',
    ]) {
      expect(find.byKey(ValueKey(field)), findsNothing);
    }
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
    expect(result!.speakerId, 'Kore');
    expect(result!.traitsJson, preview!.traitsJson);
    expect(jsonDecode(result!.traitsJson), {
      'style': '平静',
      'instructions': '保持停顿',
      'format': 'wav',
    });
    expect(tester.takeException(), isNull);
  });
}
