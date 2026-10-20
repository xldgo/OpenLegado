import 'dart:convert';

import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_voice_catalog.dart';
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

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
  }

  testWidgets('Polly 新引擎要求两项密钥及区域，即使使用自定义端点', (tester) async {
    CloudTtsEditResult? result;
    await open(
      tester,
      () => const CloudTtsEngineSheet(),
      (v) => result = v as CloudTtsEditResult?,
    );
    await tester.tap(find.byKey(const ValueKey('cloud-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AWS Polly').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cloud-apiKey')),
      'access-private',
    );
    await tester.enterText(
      find.byKey(const ValueKey('cloud-baseUrl')),
      'https://example.com',
    );
    await save(tester);
    expect(result, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('cloud-secretKey')),
      'secret-private',
    );
    await save(tester);
    expect(result, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('cloud-region')),
      'us-east-1',
    );
    for (final name in ['apiKey', 'secretKey']) {
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(ValueKey('cloud-$name')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.obscureText, isTrue);
      expect(field.enableSuggestions, isFalse);
    }
    await save(tester);
    expect(result!.engine.provider, 'aws_polly');
    expect(result!.engine.model, 'neural');
    expect(result!.key, 'access-private');
    expect(result!.secretKey, 'secret-private');
    expect(jsonEncode(result!.engine.toJson()), isNot(contains('private')));
  });
  testWidgets('Polly 编辑空密钥表示保留原值', (tester) async {
    CloudTtsEditResult? result;
    await open(
      tester,
      () => const CloudTtsEngineSheet(
        engine: CloudTtsEngine(
          id: 'polly',
          name: 'Polly',
          provider: 'aws_polly',
          model: 'neural',
          region: 'us-east-1',
          credentialKey: 'cloud-tts:polly:fixture',
        ),
      ),
      (v) => result = v as CloudTtsEditResult?,
    );
    await save(tester);
    expect(result!.key, isNull);
    expect(result!.secretKey, isNull);
    expect(result!.engine.credentialKey, 'cloud-tts:polly:fixture');
  });
  testWidgets('Polly 音色仅显示有效参数，PCM 采样率校验与请求保存一致', (tester) async {
    ReadAloudVoice? result;
    await open(
      tester,
      () => ReadAloudVoiceSheet(
        source: VoiceEditorSource(
          kind: 'cloud_tts',
          id: 'polly',
          name: 'Polly',
          provider: 'aws_polly',
          voices: const [],
          loadCatalog: (_) async => const [
            CloudTtsVoiceDescriptor(
              id: 'Zhiyu',
              name: '智语',
              locale: 'cmn-CN',
              supportedModels: ['standard', 'neural'],
            ),
          ],
        ),
        onPreview: (_, _) async {},
        onStop: () async {},
      ),
      (v) => result = v as ReadAloudVoice?,
    );
    expect(find.text('可用模型：standard、neural'), findsOneWidget);
    expect(find.byKey(const ValueKey('voice-style')), findsNothing);
    expect(find.byKey(const ValueKey('voice-speed')), findsNothing);
    expect(find.byKey(const ValueKey('voice-instructions')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('voice-format')));
    await tester.tap(find.byKey(const ValueKey('voice-format')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('wav').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('voice-sample-rate')),
      '24000',
    );
    await save(tester);
    expect(result, isNull);
    expect(find.text('PCM/WAV 仅支持 8000、16000'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('voice-sample-rate')),
      '8000',
    );
    await save(tester);
    final traits = jsonDecode(result!.traitsJson) as Map;
    expect(result!.speakerId, 'Zhiyu');
    expect(traits['locale'], 'cmn-CN');
    expect(traits['format'], 'wav');
    expect(traits['sampleRate'], 8000);
    expect(traits.containsKey('supportedModels'), isFalse);
    expect(traits.containsKey('style'), isFalse);
  });
}
