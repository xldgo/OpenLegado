import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/file_read_aloud_engine.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/read_aloud_engine.dart';

import '../fixtures/playlist_audio_player.dart';

class _Lease implements TtsAudioLease {
  int releases = 0;
  @override
  Future<void> release() async {
    releases++;
  }
}

class _Session {
  bool current = true;
  int completed = 0;
  final offsets = <int>[];
  final errors = <Object>[];
  late final value = ReadAloudSession(
    isCurrent: () => current,
    onCompleted: () => completed++,
    onProgress: offsets.add,
    onError: errors.add,
  );
}

Future<void> flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<ReadAloudPlaylistCue> cues(int count) => [
  for (var i = 0; i < count; i++)
    ReadAloudPlaylistCue(
      request: ReadAloudRequest(text: '正文$i。', engineId: 1, speed: 1.5),
      sourceOffset: 10 + i * 6,
      paragraphIndex: i,
    ),
];
void main() {
  late FakePlaylistAudioPlayer player;
  late FileReadAloudEngine engine;
  late List<_Lease> leases;
  late List<String> inputs;
  late Future<HttpTtsSynthesisResult> Function(
    ReadAloudRequest,
    HttpTtsCancellation,
  )
  synth;
  setUp(() {
    player = FakePlaylistAudioPlayer();
    leases = [];
    inputs = [];
    synth = (request, cancellation) async {
      inputs.add(request.text);
      final lease = _Lease();
      leases.add(lease);
      return HttpTtsAudio(
        audioPath: '/cache/${request.text}.wav',
        lease: lease,
      );
    };
    engine = FileReadAloudEngine(
      player: player,
      synthesize: (r, c) => synth(r, c),
    );
  });
  tearDown(() async {
    await engine.stop();
  });

  test('历史项不阻塞前方两项，章内只追加，停止确认后统一释放租约', () async {
    final session = _Session();
    final plan = cues(8);
    final started = <int>[];
    expect(
      await engine.speakPlaylist(
        plan,
        session.value,
        onCueStarted: (cue) => started.add(cue.paragraphIndex),
      ),
      ReadAloudStart.started,
    );
    await flush();
    expect(inputs.length, 3);
    expect(player.starts, 1);
    expect(player.appendBatches.single, hasLength(2));
    expect(leases.every((l) => l.releases == 0), isTrue);
    for (var i = 0; i < 7; i++) {
      player.advance();
      await flush();
      expect(session.completed, 0);
      expect(player.items.length - player.current - 1, lessThanOrEqualTo(2));
      expect(leases.map((lease) => lease.releases), everyElement(0));
    }
    expect(started, List.generate(8, (i) => i));
    player.report(500);
    expect(session.offsets.last, 7 * 6 + 2);
    player.advance();
    await flush();
    expect(session.completed, 1);
    expect(player.items, hasLength(8));
    expect(player.playedLocalFiles.length, 1);
    expect(inputs, plan.map((cue) => cue.request.text).toList());
    await engine.stop();
    expect(leases.map((l) => l.releases), everyElement(1));
  });

  test('起播只合并唤醒，执行时按已确认项目补足前方两项', () async {
    final session = _Session();
    final started = <int>[];
    await engine.speakPlaylist(
      cues(6),
      session.value,
      onCueStarted: (cue) => started.add(cue.paragraphIndex),
    );
    await flush();
    expect(inputs, hasLength(3));
    player.advance();
    player.advance();
    expect(inputs, hasLength(3));
    expect(started, [0, 1, 2]);
    await flush();
    expect(inputs, hasLength(5));
    expect(player.items, hasLength(5));
    expect(player.appendBatches.map((b) => b.length), [2, 2]);
    expect(session.completed, 0);
  });

  test('起播和末项完成必须属于确认项目，不被暂态标签提前切章', () async {
    final session = _Session();
    final plan = cues(3);
    final started = <int>[];
    await engine.speakPlaylist(
      plan,
      session.value,
      onCueStarted: (cue) => started.add(cue.paragraphIndex),
    );
    await flush();
    player.started!(plan.last);
    player.completed!(plan.last);
    expect(started, [0]);
    expect(session.completed, 0);
    player.advance();
    player.advance();
    expect(session.completed, 0);
    player.advance();
    expect(started, [0, 1, 2]);
    expect(session.completed, 1);
  });

  test('暂停恢复不重新装载，新的会话从当前片起点映射原文进度', () async {
    final old = _Session();
    await engine.speakPlaylist(cues(4), old.value, onCueStarted: (_) {});
    await flush();
    player.advance();
    await flush();
    player.report(500);
    final previous = old.offsets.length;
    await engine.pause();
    expect(engine.canResume, isTrue);
    player.report(900);
    expect(old.offsets.length, previous);
    final next = _Session();
    expect(await engine.resume(next.value), ReadAloudStart.started);
    player.report(500);
    expect(next.offsets.last, 2);
    expect(player.starts, 1);
    expect(player.nativeResumes, 1);
    expect(old.completed, 0);
  });

  test('快速换项不裁剪原生历史来源，停止屏障完成后才释放文件', () async {
    await engine.speakPlaylist(cues(3), _Session().value, onCueStarted: (_) {});
    await flush();
    player.advance();
    player.advance();
    await flush();
    expect(player.items, hasLength(3));
    expect(player.current, 2);
    expect(leases.map((lease) => lease.releases), everyElement(0));
    final stopped = Completer<void>();
    final stop = engine.stop(playbackStopped: stopped.future);
    await flush();
    expect(leases.map((lease) => lease.releases), everyElement(0));
    stopped.complete();
    await stop;
    expect(leases.map((lease) => lease.releases), everyElement(1));
  });

  test('后续合成失败不提前打断当前文件，到边界暂停并定位未播放的正文', () async {
    final session = _Session();
    final started = <int>[];
    final delegate = synth;
    synth = (r, c) async {
      if (r.text == '正文1。') throw StateError('后续合成失败');
      return delegate(r, c);
    };
    await engine.speakPlaylist(
      cues(3),
      session.value,
      onCueStarted: (cue) => started.add(cue.paragraphIndex),
    );
    await flush();
    expect(session.errors, isEmpty);
    expect(player.isPlaying, isTrue);
    player.advance();
    await flush();
    expect(session.errors, hasLength(1));
    expect(started, [0, 1]);
    expect(session.offsets.last, 6);
    expect(session.completed, 0);
    expect(engine.canResume, isFalse);
  });

  test('下一文件未就绪时等待，迟到入队恢复，不把队尾误判为章末', () async {
    final gate = Completer<HttpTtsSynthesisResult>();
    final delegate = synth;
    synth = (r, c) => r.text == '正文1。' ? gate.future : delegate(r, c);
    final session = _Session();
    await engine.speakPlaylist(cues(2), session.value, onCueStarted: (_) {});
    await flush();
    player.advance();
    await flush();
    expect(session.completed, 0);
    final lease = _Lease();
    leases.add(lease);
    gate.complete(HttpTtsAudio(audioPath: '/cache/late.wav', lease: lease));
    await flush();
    expect(player.isPlaying, isTrue);
    player.advance();
    await flush();
    expect(session.completed, 1);
  });

  test('后一个合成阻塞时先追加已就绪项，不等待凑齐批次', () async {
    final gate = Completer<HttpTtsSynthesisResult>();
    final delegate = synth;
    synth = (r, c) => r.text == '正文2。' ? gate.future : delegate(r, c);
    final session = _Session();
    await engine.speakPlaylist(cues(3), session.value, onCueStarted: (_) {});
    await flush();
    expect(player.items, hasLength(2));
    expect(player.appendBatches.single, hasLength(1));
    player.advance();
    await flush();
    expect(session.completed, 0);
    final lease = _Lease();
    leases.add(lease);
    gate.complete(HttpTtsAudio(audioPath: '/cache/last.wav', lease: lease));
    await flush();
    expect(player.items, hasLength(3));
    expect(player.appendBatches.map((batch) => batch.length), [1, 1]);
    expect(leases.map((item) => item.releases), everyElement(0));
  });

  test('补充调度前停止，不启动迟到合成或追加，已准备租约全部回收', () async {
    await engine.speakPlaylist(cues(3), _Session().value, onCueStarted: (_) {});
    for (var i = 0; i < 8; i++) {
      await Future<void>.value();
    }
    expect(inputs, hasLength(1));
    expect(player.appendBatches, isEmpty);
    await engine.stop();
    await flush();
    expect(player.appendBatches, isEmpty);
    expect(player.items, isEmpty);
    expect(leases.map((item) => item.releases), everyElement(1));
  });

  test('停止后旧合成迟到只释放旧租约，不入队或阻塞新会话', () async {
    final gate = Completer<HttpTtsSynthesisResult>();
    final delegate = synth;
    var blocked = true;
    synth = (r, c) =>
        blocked && r.text == '正文1。' ? gate.future : delegate(r, c);
    final old = _Session();
    await engine.speakPlaylist(cues(4), old.value, onCueStarted: (_) {});
    await flush();
    final oldCallback = player.started!;
    await engine.stop();
    blocked = false;
    final next = _Session();
    await engine.speakPlaylist(cues(2), next.value, onCueStarted: (_) {});
    await flush();
    expect(player.items, hasLength(2));
    final orphan = _Lease();
    gate.complete(HttpTtsAudio(audioPath: '/old.wav', lease: orphan));
    oldCallback(cues(1).first);
    await flush();
    expect(orphan.releases, 1);
    expect(player.items.map((e) => e.path), isNot(contains('/old.wav')));
    player.advance();
    await flush();
    player.advance();
    await flush();
    expect(next.completed, 1);
    expect(old.completed, 0);
  });

  test('首项合成失败不报告起播成功', () async {
    final session = _Session();
    synth = (r, c) async {
      throw StateError('首项失败');
    };
    await expectLater(
      engine.speakPlaylist(cues(2), session.value, onCueStarted: (_) {}),
      throwsStateError,
    );
    expect(player.starts, 0);
    expect(session.completed, 0);
  });

  test('暂停恰逢追加完成，续播不会重复入队相同正文', () async {
    player.appendGate = Completer<void>();
    final first = _Session();
    await engine.speakPlaylist(cues(4), first.value, onCueStarted: (_) {});
    await flush();
    expect(inputs, hasLength(3));
    await engine.pause();
    player.appendGate!.complete();
    await flush();
    final next = _Session();
    await engine.resume(next.value);
    await flush();
    for (var i = 0; i < 4; i++) {
      player.advance();
      await flush();
    }
    expect(inputs, cues(4).map((cue) => cue.request.text).toList());
    expect(next.completed, 1);
    await engine.stop();
    expect(leases.map((lease) => lease.releases), everyElement(1));
  });

  test('原生首项装载失败先停止后释放音频，不保留可续播状态', () async {
    player.startError = StateError('文件解码失败');
    await expectLater(
      engine.speakPlaylist(cues(2), _Session().value, onCueStarted: (_) {}),
      throwsStateError,
    );
    expect(leases.single.releases, 1);
    expect(player.items, isEmpty);
    expect(engine.canResume, isFalse);
  });
  test('追加失败保护可能被原生引用的文件，停止后才释放', () async {
    player.appendError = StateError('追加失败');
    await engine.speakPlaylist(cues(3), _Session().value, onCueStarted: (_) {});
    await flush();
    expect(leases, hasLength(3));
    expect(leases.map((lease) => lease.releases), everyElement(0));
    await engine.stop();
    expect(leases.map((lease) => lease.releases), everyElement(1));
  });

  test('暂停确认前已经发生原生换项，续播同步新片原文归属', () async {
    final started = <int>[];
    await engine.speakPlaylist(
      cues(3),
      _Session().value,
      onCueStarted: (cue) => started.add(cue.paragraphIndex),
    );
    await flush();
    await engine.pause();
    // 平台在暂停确认前完成的换项，此刻Dart会话已取消。
    player.current = 1;
    player.started!(player.currentPlaylistTag!);
    expect(started, [0]);
    final next = _Session();
    await engine.resume(next.value);
    expect(started, [0, 1]);
    player.report(500);
    expect(next.offsets.last, 8);
  });
}
