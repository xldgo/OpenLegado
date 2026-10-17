import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/services/read_aloud_comparison.dart';
import 'package:flutter_legado/src/services/read_aloud_diagnostics.dart';

import '../fixtures/playlist_audio_player.dart';

Future<void> _drain() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late FakePlaylistAudioPlayer player;
  late ReadAloudDiagnostics diagnostics;
  late ReadAloudComparison comparison;
  late ComparisonFixture fixture;
  var activations = 0, releases = 0;
  Completer<void>? activationGate;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tts-comparison-');
    player = FakePlaylistAudioPlayer();
    diagnostics = ReadAloudDiagnostics(
      directory: () async => root,
      exportDirectory: () async => root,
    );
    fixture = ComparisonFixture(
      label: '测试章节',
      identity: 'fixture',
      audio: [
        for (var i = 0; i < 8; i++)
          ComparisonAudio(
            path: '/cache/$i.wav',
            sha256: 'hash$i',
            bytes: i + 1,
          ),
      ],
    );
    activations = releases = 0;
    activationGate = null;
    comparison = ReadAloudComparison(
      player: player,
      diagnostics: diagnostics,
      loadFixture: () async => fixture,
      saveReport: (file, mode) => file.copy('${root.path}/${mode.name}.jsonl'),
      closeSamples: () async {},
      beforeRun: () async {
        activations++;
        await activationGate?.future;
      },
      afterRun: () async {
        releases++;
      },
    );
    await comparison.prepare();
  });
  tearDown(() async {
    await comparison.close();
    await diagnostics.stop();
    diagnostics.dispose();
    await root.delete(recursive: true);
  });

  test('固定组一次装入全部样本，自然换项不追加，完成保存完整清单', () async {
    await comparison.start(ReadAloudComparisonMode.fixed);
    expect(player.items.map((a) => a.path), fixture.audio.map((a) => a.path));
    expect(player.starts, 1);
    expect(player.playedLocalFiles.single.speed, 1);
    for (var i = 0; i < 8; i++) {
      player.advance();
    }
    await comparison.stop();
    expect(player.appendBatches, isEmpty);
    expect(comparison.running, isFalse);
    expect(comparison.busy, isFalse);
    expect(activations, 1);
    expect(releases, 1);
    final records =
        (await comparison.reports[ReadAloudComparisonMode.fixed]!.readAsLines())
            .map((s) => jsonDecode(s) as Map<String, dynamic>)
            .toList();
    final start = records.singleWhere((r) => r['event'] == 'comparison.start');
    expect(start['mode'], 'fixed');
    expect(
      (start['samples'] as List).map((s) => s['sha256']),
      fixture.audio.map((s) => s.sha256),
    );
    expect(
      records
          .where((r) => r['event'] == 'comparison.item_started')
          .map((r) => r['index']),
      List.generate(8, (i) => i),
    );
  });

  test('动态组从三项开始，每次换段补一项，前方维持两项且不重新装载', () async {
    await comparison.start(ReadAloudComparisonMode.dynamic);
    expect(player.items.map((i) => i.tag), [0, 1, 2]);
    expect(player.appendBatches, isEmpty);
    for (var i = 1; i <= 5; i++) {
      player.advance();
      await _drain();
      expect(player.items.length, i + 3);
      expect(player.items.length - player.current - 1, 2);
    }
    expect(player.appendBatches.map((b) => b.single.tag), [3, 4, 5, 6, 7]);
    expect(player.items.map((i) => i.path), fixture.audio.map((i) => i.path));
    expect(player.starts, 1);
    expect(player.nativeResumes, 0);
  });

  test('快速换段只异步唤醒补充，按已确认项目读取储备', () async {
    await comparison.start(ReadAloudComparisonMode.dynamic);
    player.advance();
    player.advance();
    expect(player.appendBatches, isEmpty);
    await _drain();
    expect(player.items.map((i) => i.tag), [0, 1, 2, 3, 4]);
    expect(player.starts, 1);
    expect(comparison.currentIndex, 2);
  });

  test('末项暂态回调不提前停止，停止前取消待补充唤醒', () async {
    await comparison.start(ReadAloudComparisonMode.dynamic);
    player.started!(7);
    player.completed!(7);
    expect(comparison.running, isTrue);
    expect(comparison.currentIndex, 0);
    await comparison.stop();
    await _drain();
    expect(player.appendBatches, isEmpty);
    expect(comparison.running, isFalse);
  });

  test('新组清理采集但保留已另存的A日志，且两组清单一致', () async {
    await comparison.start(ReadAloudComparisonMode.fixed);
    await comparison.stop();
    final a = comparison.reports[ReadAloudComparisonMode.fixed]!;
    final savedA = await a.readAsString();
    await comparison.start(ReadAloudComparisonMode.dynamic);
    comparison.mark();
    await comparison.stop();
    expect(await a.readAsString(), savedA);
    final b = await comparison.reports[ReadAloudComparisonMode.dynamic]!
        .readAsString();
    expect(b, isNot(contains('"mode":"fixed"')));
    final records = b
        .trim()
        .split('\n')
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();
    expect(
      records
          .where((r) => r['event'] == 'comparison.heard_replay')
          .single['index'],
      0,
    );
    final aStart = savedA
        .trim()
        .split('\n')
        .map((s) => jsonDecode(s))
        .singleWhere((r) => r['event'] == 'comparison.start');
    final bStart = records.singleWhere((r) => r['event'] == 'comparison.start');
    expect(bStart['samples'], aStart['samples']);
  });

  test('停止后迟到换项与位置回调不会续播或改变当前段', () async {
    await comparison.start(ReadAloudComparisonMode.dynamic);
    final oldStarted = player.started!, oldProgress = player.progress!;
    await comparison.stop();
    oldStarted(4);
    oldProgress(const Duration(seconds: 3), const Duration(seconds: 5), 4);
    await _drain();
    expect(comparison.currentIndex, 0);
    expect(comparison.position, Duration.zero);
    expect(player.appendBatches, isEmpty);
    expect(player.nativeResumes, 0);
  });

  test('等待正文停止期间退出，不得随后加载音频，并归还已取得的焦点', () async {
    activationGate = Completer<void>();
    final starting = comparison.start(ReadAloudComparisonMode.fixed);
    final stopping = comparison.stop();
    activationGate!.complete();
    await Future.wait([starting, stopping]);
    expect(player.starts, 0);
    expect(diagnostics.enabled, isFalse);
    expect(releases, 1);
  });

  test('追加失败停止本组，不回退固定组或重播，保留诊断结果', () async {
    await comparison.start(ReadAloudComparisonMode.dynamic);
    player.appendError = StateError('注入追加失败');
    player.advance();
    await _drain();
    await comparison.stop();
    expect(comparison.error, contains('追加音频失败'));
    expect(comparison.running, isFalse);
    expect(player.starts, 1);
    expect(releases, 1);
    expect(comparison.reports[ReadAloudComparisonMode.dynamic], isNotNull);
  });
}
