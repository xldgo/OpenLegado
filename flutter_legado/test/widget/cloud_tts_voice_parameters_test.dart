import 'dart:convert';

import 'package:flutter_legado/src/domain/contracts/cloud_tts_provider.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud_voice_sheet.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/widgets/bottom_sheet_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  ReadAloudVoice? saved, preview;
  String? previewText;
  Future<void> open(
    WidgetTester tester, {
    String provider = 'alibaba_cloud',
    Map<String, dynamic>? traits,
  }) async {
    saved = null;
    preview = null;
    previewText = null;
    final profile = cloudTtsProfile(provider);
    final voice = ReadAloudVoice(
      id: readAloudVoiceId('cloud_tts', 'engine', profile.voice),
      engineType: 'cloud_tts',
      engineId: 'engine',
      speakerId: profile.voice,
      displayName: '原音色',
      traitsJson: jsonEncode(traits ?? {}),
      managedBy: 'user',
    );
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await AppBottomSheet.showContent<ReadAloudVoice>(
                  context: context,
                  builder: (_) => ReadAloudVoiceSheet(
                    source: VoiceEditorSource(
                      kind: 'cloud_tts',
                      id: 'engine',
                      name: profile.name,
                      provider: provider,
                      voices: [voice],
                    ),
                    voice: traits == null ? null : voice,
                    onPreview: (voice, text) async {
                      preview = voice;
                      previewText = text;
                    },
                    onStop: () async {},
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  for (final provider in cloudTtsProviderProfiles.keys) {
    testWidgets('$provider 重命名保存保留未展示参数和身份', (tester) async {
      final traits = {
        'locale': 'English',
        'role': '旁白',
        'pitch': 1.2,
        'volume': 0.8,
        'sampleRate': provider == 'aws_polly' ? 16000 : 24000,
        'speed': 1.5,
        'style': '平静',
        'instructions': '保留指令',
        'format': 'wav',
      };
      await open(tester, provider: provider, traits: traits);
      await tester.enterText(find.byKey(const ValueKey('voice-name')), '修改名称');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved!.displayName, '修改名称');
      expect(
        saved!.id,
        readAloudVoiceId(
          'cloud_tts',
          'engine',
          cloudTtsProfile(provider).voice,
        ),
      );
      expect(jsonDecode(saved!.traitsJson), traits);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('百炼语言编辑去除首尾空白，试听和保存参数一致', (tester) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('voice-locale')),
      ' English ',
    );
    await tester.ensureVisible(find.text('试听'));
    await tester.tap(find.text('试听'));
    await tester.pumpAndSettle();
    expect(jsonDecode(preview!.traitsJson)['locale'], 'English');
    expect(jsonDecode(preview!.traitsJson).containsKey('speed'), isFalse);
    expect(previewText, '这是朗读试听。欢迎使用开源阅读。');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved!.traitsJson, preview!.traitsJson);
  });

  testWidgets('百炼语言正确回显，清空恢复自动识别且保留其他参数', (tester) async {
    await open(tester, traits: {'locale': 'Chinese', 'pitch': 1.2});
    final field = find.byKey(const ValueKey('voice-locale'));
    expect(tester.widget<TextFormField>(field).controller!.text, 'Chinese');
    await tester.enterText(field, '   ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(jsonDecode(saved!.traitsJson)['locale'], '');
    expect(jsonDecode(saved!.traitsJson)['pitch'], 1.2);
  });

  testWidgets('OpenAI 保留参数且合成语速仍可编辑，不展示无效语言设置', (tester) async {
    await open(tester, provider: 'openai_speech', traits: {'speed': 1.5});
    expect(find.byKey(const ValueKey('voice-locale')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('voice-speed')), '2.0');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(jsonDecode(saved!.traitsJson)['speed'], 2.0);
  });
}
