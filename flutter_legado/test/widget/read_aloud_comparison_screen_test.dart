import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/features/settings/presentation/read_aloud_comparison_screen.dart';
import 'package:flutter_legado/src/services/read_aloud_comparison.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';

import '../fixtures/playlist_audio_player.dart';

void main() {
  testWidgets('准备期间禁用两组按钮，样本就绪后允许选择，不自动播放', (tester) async {
    final fixture = Completer<ComparisonFixture>();
    final player = FakePlaylistAudioPlayer();
    final comparison = ReadAloudComparison(
      player: player,
      loadFixture: () => fixture.future,
      saveReport: (file, _) async => file,
      closeSamples: () async {},
      beforeRun: () async {},
      afterRun: () async {},
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: ReadAloudComparisonScreen(comparison: comparison),
        ),
      ),
    );
    await tester.pump();
    final a = find.widgetWithText(FilledButton, '播放A：固定列表');
    final b = find.widgetWithText(FilledButton, '播放B：动态追加');
    expect(tester.widget<FilledButton>(a).onPressed, isNull);
    expect(tester.widget<FilledButton>(b).onPressed, isNull);
    fixture.complete(
      ComparisonFixture(
        label: '测试书 · 测试章',
        identity: 'same',
        audio: [
          for (var i = 0; i < 6; i++)
            ComparisonAudio(path: '/cache/$i.wav', sha256: '$i', bytes: 1),
        ],
      ),
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(a).onPressed, isNotNull);
    expect(tester.widget<FilledButton>(b).onPressed, isNotNull);
    expect(find.text('测试书 · 测试章'), findsOneWidget);
    expect(player.starts, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await comparison.close();
  });
}
