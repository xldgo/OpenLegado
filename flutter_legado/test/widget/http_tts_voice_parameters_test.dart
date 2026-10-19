import 'dart:convert';

import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud_voice_sheet.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/widgets/bottom_sheet_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final a = ReadAloudVoice(
    id: readAloudVoiceId('http', '1', 'a'),
    engineType: 'http',
    engineId: '1',
    speakerId: 'a',
    displayName: '角色甲',
    traitsJson: '["中文","女"]',
    emotionCatalogJson: '[{"emotionName":"高兴","emotionTag":"happy"}]',
  );
  final b = ReadAloudVoice(
    id: readAloudVoiceId('http', '1', 'b'),
    engineType: 'http',
    engineId: '1',
    speakerId: 'b',
    displayName: '角色乙',
    traitsJson: '["男"]',
    emotionCatalogJson: '[{"emotionName":"平静","emotionTag":"calm"}]',
  );
  ReadAloudVoice? saved, preview;
  Future<void> open(
    WidgetTester tester, {
    ReadAloudVoice? existing,
    String? override,
  }) async {
    saved = null;
    preview = null;
    tester.view.physicalSize = const Size(360, 800);
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
                      kind: 'http',
                      id: '1',
                      name: '测试引擎',
                      voices: existing == null ? [a, b] : [existing],
                    ),
                    voice: existing,
                    httpEmotionTag: override,
                    onPreview: (voice, text) async {
                      preview = voice;
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

  testWidgets('保存角色与情感保留目录标签，试听与保存参数一致', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ActionChip, '高兴'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('voice-emotion')),
      ' happy ',
    );
    await tester.ensureVisible(find.text('试听'));
    await tester.tap(find.text('试听'));
    await tester.pumpAndSettle();
    expect(jsonDecode(preview!.traitsJson), {
      'tags': ['中文', '女'],
      'emotionTag': 'happy',
    });
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved!.id, a.id);
    expect(saved!.traitsJson, preview!.traitsJson);
    expect(saved!.emotionCatalogJson, a.emotionCatalogJson);
  });

  testWidgets('切换角色更换标签与情感目录，不携带前一个角色的情感', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ActionChip, '高兴'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '角色乙'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, '高兴'), findsNothing);
    expect(find.widgetWithText(ActionChip, '平静'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, '平静'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved!.id, b.id);
    expect(jsonDecode(saved!.traitsJson), {
      'tags': ['男'],
      'emotionTag': 'calm',
    });
  });

  testWidgets('编辑保留未知参数，默认情感清空预设并保持稳定身份', (tester) async {
    final existing = a.copyWith(
      traitsJson: '{"tags":["女"],"custom":"保留","emotionTag":"happy"}',
    );
    await open(tester, existing: existing);
    await tester.tap(find.widgetWithText(ActionChip, '默认情感'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved!.id, existing.id);
    expect(jsonDecode(saved!.traitsJson), {
      'tags': ['女'],
      'custom': '保留',
      'emotionTag': null,
    });
  });

  testWidgets('目录外情感被表单拒绝，显式默认覆盖正确回显', (tester) async {
    final existing = a.copyWith(traitsJson: '{"emotionTag":"happy"}');
    await open(tester, existing: existing, override: '');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('voice-emotion')))
          .controller!
          .text,
      '',
    );
    await tester.enterText(
      find.byKey(const ValueKey('voice-emotion')),
      'unsupported',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请选择当前音色目录中的情感'), findsOneWidget);
    expect(saved, isNull);
    expect(tester.takeException(), isNull);
  });
}
