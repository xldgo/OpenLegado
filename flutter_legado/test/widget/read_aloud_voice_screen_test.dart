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
  testWidgets('选择情感写入独立设置并显示选中，排除隐藏、恢复保持选择', (tester) async {
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
