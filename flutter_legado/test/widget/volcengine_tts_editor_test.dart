import 'dart:convert';

import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
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

  testWidgets('火山引擎仅展示 App ID、Token 和业务集群，缺 App ID 不保存', (tester) async {
    CloudTtsEditResult? result;
    await open(
      tester,
      () => const CloudTtsEngineSheet(),
      (v) => result = v as CloudTtsEditResult?,
    );
    await tester.tap(find.byKey(const ValueKey('cloud-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('火山引擎（V1）').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cloud-region')), findsNothing);
    expect(find.byKey(const ValueKey('cloud-secretKey')), findsNothing);
    expect(find.text('业务集群'), findsOneWidget);
    expect(find.text('Access Token'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('cloud-apiKey')),
      'token-private',
    );
    await save(tester);
    expect(result, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('cloud-appId')),
      ' app-fixture ',
    );
    await save(tester);
    expect(result!.engine.provider, 'volcengine');
    expect(result!.engine.appId, 'app-fixture');
    expect(result!.engine.model, 'volcano_tts');
    expect(result!.key, 'token-private');
    expect(
      jsonEncode(result!.engine.toJson()),
      isNot(contains('token-private')),
    );
  });
  testWidgets('火山编辑保留 App ID 与 Token 引用', (tester) async {
    CloudTtsEditResult? result;
    await open(
      tester,
      () => const CloudTtsEngineSheet(
        engine: CloudTtsEngine(
          id: 'volc',
          name: '火山',
          provider: 'volcengine',
          appId: 'app',
          model: 'custom_cluster',
          credentialKey: 'cloud-tts:volc:fixture',
        ),
      ),
      (v) => result = v as CloudTtsEditResult?,
    );
    await tester.enterText(find.byKey(const ValueKey('cloud-name')), '改名');
    await save(tester);
    expect(result!.key, isNull);
    expect(result!.engine.appId, 'app');
    expect(result!.engine.model, 'custom_cluster');
    expect(result!.engine.credentialKey, 'cloud-tts:volc:fixture');
  });
  testWidgets('火山音色参数范围与协议一致，不展示角色或无效指令', (tester) async {
    ReadAloudVoice? result;
    await open(
      tester,
      () => ReadAloudVoiceSheet(
        source: const VoiceEditorSource(
          kind: 'cloud_tts',
          id: 'volc',
          name: '火山',
          provider: 'volcengine',
          voices: [
            ReadAloudVoice(
              id: 'voice',
              engineType: 'cloud_tts',
              engineId: 'volc',
              speakerId: 'BV001_streaming',
              displayName: '通用女声',
            ),
          ],
        ),
        onPreview: (_, _) async {},
        onStop: () async {},
      ),
      (v) => result = v as ReadAloudVoice?,
    );
    expect(find.byKey(const ValueKey('voice-role')), findsNothing);
    expect(find.byKey(const ValueKey('voice-instructions')), findsNothing);
    expect(find.byKey(const ValueKey('voice-locale')), findsNothing);
    expect(find.text('情感'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('voice-speed')), '0.19');
    await save(tester);
    expect(result, isNull);
    await tester.enterText(find.byKey(const ValueKey('voice-speed')), '0.2');
    await tester.enterText(find.byKey(const ValueKey('voice-pitch')), '0');
    await save(tester);
    expect(result, isNull);
    await tester.enterText(find.byKey(const ValueKey('voice-pitch')), '0.1');
    await tester.enterText(find.byKey(const ValueKey('voice-volume')), '3');
    await tester.enterText(find.byKey(const ValueKey('voice-style')), 'happy');
    await save(tester);
    expect(jsonDecode(result!.traitsJson), {
      'speed': 0.2,
      'pitch': 0.1,
      'volume': 3.0,
      'style': 'happy',
      'format': 'mp3',
    });
  });
}
