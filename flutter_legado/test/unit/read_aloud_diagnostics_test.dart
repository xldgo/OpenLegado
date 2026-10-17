import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/services/read_aloud_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late ReadAloudDiagnostics diagnostics;
  File getLog() => File('${root.path}/read_aloud_diagnostics/events.jsonl');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('read-aloud-diagnostics-');
    diagnostics = ReadAloudDiagnostics(
      directory: () async => root,
      exportDirectory: () async => root,
    );
  });
  tearDown(() async {
    await diagnostics.stop();
    diagnostics.dispose();
    await root.delete(recursive: true);
  });

  test('默认关闭时不写日志，显式开启和停止后才产生诊断文件', () async {
    diagnostics.event('ignored');
    await diagnostics.flush();
    expect(await getLog().exists(), isFalse);
    await diagnostics.start();
    diagnostics.event('player.play', {'tag': 7, 'positionMs': 250});
    await diagnostics.stop();
    final records = await getLog().readAsLines();
    final events = records.map((line) => jsonDecode(line)['event']);
    expect(
      events,
      containsAllInOrder(['capture.start', 'player.play', 'capture.stop']),
    );
    diagnostics.event('after.stop');
    await diagnostics.flush();
    expect(await getLog().readAsLines(), records);
  });

  test('标记故障写入时间戳与会话身份', () async {
    await diagnostics.start();
    diagnostics.mark();
    await diagnostics.stop();
    final marker = (await getLog().readAsLines())
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .singleWhere((entry) => entry['event'] == 'user.heard_replay');
    expect(marker['session'], diagnostics.session);
    expect(marker['wallMs'], isPositive);
    expect(marker['monoUs'], isNonNegative);
  });

  test('旧采集的迟到耗时结果不混入下一次采集', () async {
    await diagnostics.start();
    final old = diagnostics.begin('old.job');
    await diagnostics.stop();
    await diagnostics.start();
    old!.finish({'outcome': 'audio'});
    await diagnostics.stop();
    final events = (await getLog().readAsLines()).map(
      (line) => jsonDecode(line)['event'],
    );
    expect(events, contains('old.job.begin'));
    expect(events, isNot(contains('old.job.end')));
  });

  test('突发事件有界，超过容量不会无限堆积或阻断调用', () async {
    await diagnostics.start();
    for (var i = 0; i < 1000; i++) {
      diagnostics.event('burst', {'number': i});
    }
    await diagnostics.flush();
    await diagnostics.stop();
    final records = (await getLog().readAsLines()).map(
      (line) => jsonDecode(line) as Map<String, dynamic>,
    );
    expect(
      records.where((e) => e['event'] == 'burst').length,
      ReadAloudDiagnostics.maxBufferedEvents,
    );
  });

  test('文件轮转只保留最近两份并保持大小上限', () async {
    await diagnostics.start();
    for (var batch = 0; batch < 40; batch++) {
      for (var i = 0; i < 100; i++) {
        diagnostics.event('rotation', {'batch': batch, 'fixture': 'x' * 450});
      }
      await diagnostics.flush();
    }
    await diagnostics.stop();
    final previous = File('${getLog().path}.previous');
    expect(await previous.exists(), isTrue);
    expect(
      await getLog().length(),
      lessThanOrEqualTo(ReadAloudDiagnostics.maxFileBytes),
    );
    expect(
      await previous.length(),
      lessThanOrEqualTo(ReadAloudDiagnostics.maxFileBytes),
    );
    expect(
      (await getLog().readAsLines()).map((line) => jsonDecode(line)['event']),
      contains('capture.stop'),
    );
  });

  test('文件标识忽略所在目录且不泄露原文件名', () {
    final first = ReadAloudDiagnostics.fileKey(
      'file:///private/cache/a%20b.wav',
    );
    final second = ReadAloudDiagnostics.fileKey('/other/a%20b.wav');
    expect(first, second);
    expect(first, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(first, isNot(contains('a b')));
  });

  test('导出停止采集并包含用户标记，重复导出复用同一临时文件', () async {
    await diagnostics.start();
    diagnostics.mark();
    final exported = await diagnostics.export();
    expect(diagnostics.enabled, isFalse);
    expect(exported, isNotNull);
    final events = (await exported!.readAsLines()).map(
      (line) => jsonDecode(line)['event'],
    );
    expect(
      events,
      containsAllInOrder([
        'user.heard_replay',
        'capture.export',
        'capture.stop',
      ]),
    );
    expect((await diagnostics.export())!.path, exported.path);
  });
}
