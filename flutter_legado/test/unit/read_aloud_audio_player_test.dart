import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as audio;
import 'package:flutter_legado/src/services/audio_playlist_player.dart';
import 'package:flutter_legado/src/services/read_aloud_audio_player.dart';

class _Native extends Fake implements audio.AudioPlayer {
  final events = StreamController<audio.PlaybackEvent>.broadcast(sync: true);
  final positions = StreamController<Duration>.broadcast(sync: true);
  final errors = StreamController<audio.PlayerException>.broadcast(sync: true);
  final sequences = StreamController<audio.SequenceState>.broadcast(sync: true);
  final discontinuities =
      StreamController<audio.PositionDiscontinuity>.broadcast(sync: true);
  final states = StreamController<audio.ProcessingState>.broadcast(sync: true);
  @override
  audio.PlaybackEvent playbackEvent = audio.PlaybackEvent();
  @override
  Stream<audio.SequenceState> get sequenceStateStream => sequences.stream;
  @override
  Stream<audio.PositionDiscontinuity> get positionDiscontinuityStream =>
      discontinuities.stream;
  @override
  Stream<audio.ProcessingState> get processingStateStream => states.stream;
  @override
  List<audio.IndexedAudioSource> sequence = [];
  @override
  int? currentIndex;
  @override
  audio.ProcessingState processingState = audio.ProcessingState.idle;
  @override
  bool playing = false;
  @override
  Duration position = Duration.zero;
  @override
  Duration duration = const Duration(seconds: 1);
  int loads = 0, plays = 0, stops = 0, clears = 0, pauses = 0, appends = 0;
  @override
  double speed = 1;
  Completer<void>? loadGate;
  Completer<void>? appendGate;
  final seeks = <(Duration?, int?)>[];
  Object? loadError;
  @override
  Stream<audio.PlaybackEvent> get playbackEventStream => events.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<audio.PlayerException> get errorStream => errors.stream;
  @override
  audio.SequenceState get sequenceState => audio.SequenceState(
    sequence: sequence,
    currentIndex: currentIndex,
    shuffleIndices: List.generate(sequence.length, (i) => i),
    shuffleModeEnabled: false,
    loopMode: audio.LoopMode.off,
  );
  void emit() {
    playbackEvent = audio.PlaybackEvent(
      currentIndex: currentIndex,
      processingState: processingState,
      duration: duration,
      updatePosition: position,
      updateTime: playbackEvent.updateTime.add(const Duration(milliseconds: 1)),
    );
    sequences.add(sequenceState);
    states.add(processingState);
    events.add(playbackEvent);
  }

  void transition(int index, {bool natural = true, bool resetPosition = true}) {
    final previous = playbackEvent;
    currentIndex = index;
    if (resetPosition) position = Duration.zero;
    processingState = audio.ProcessingState.ready;
    emit();
    discontinuities.add(
      audio.PositionDiscontinuity(
        natural
            ? audio.PositionDiscontinuityReason.autoAdvance
            : audio.PositionDiscontinuityReason.seek,
        previous,
        playbackEvent,
      ),
    );
  }

  void finish() {
    position = duration;
    processingState = audio.ProcessingState.completed;
    emit();
  }

  @override
  Future<Duration?> setAudioSources(
    List<audio.AudioSource> sources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    audio.ShuffleOrder? shuffleOrder,
  }) async {
    loads++;
    sequence = sources.expand((s) => s.sequence).toList();
    currentIndex = 0;
    if (loadError != null) throw loadError!;
    await loadGate?.future;
    processingState = audio.ProcessingState.ready;
    emit();
    return duration;
  }

  @override
  Future<void> addAudioSources(List<audio.AudioSource> sources) async {
    appends++;
    sequence.addAll(sources.expand((source) => source.sequence));
    emit();
    await appendGate?.future;
  }

  @override
  Future<void> clearAudioSources() async {
    clears++;
    sequence = [];
    currentIndex = null;
  }

  @override
  Future<void> setSpeed(double value) async {
    speed = value;
  }

  @override
  Future<void> play() async {
    plays++;
    playing = true;
    emit();
  }

  @override
  Future<void> pause() async {
    pauses++;
    playing = false;
    emit();
  }

  @override
  Future<void> stop() async {
    stops++;
    playing = false;
    processingState = audio.ProcessingState.idle;
    if (loadGate?.isCompleted == false) {
      loadGate!.completeError(audio.PlayerInterruptedException('已停止'));
    }
  }

  @override
  Future<void> seek(Duration? value, {int? index}) async {
    seeks.add((value, index));
    if (index != null) currentIndex = index;
    position = value ?? Duration.zero;
    processingState = audio.ProcessingState.ready;
    emit();
  }

  @override
  Future<void> seekToNext() => seek(Duration.zero, index: currentIndex! + 1);
  @override
  Future<void> dispose() async {
    await events.close();
    await positions.close();
    await errors.close();
    await sequences.close();
    await discontinuities.close();
    await states.close();
  }
}

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Native native;
  late ReadAloudAudioPlayer player;
  late List<Object> started, ended, failures;
  late List<(Duration, Object)> progress;
  setUp(() {
    native = _Native();
    player = ReadAloudAudioPlayer(createPlayer: () => native);
    started = [];
    ended = [];
    failures = [];
    progress = [];
  });
  tearDown(() => player.dispose());
  Future<void> start(Object tag) => player.startPlaylist(
    AudioPlaylistItem(path: '/cache/a.wav', tag: tag),
    speed: 1.5,
    onStarted: started.add,
    onCompleted: ended.add,
    onProgress: (position, _, tag) => progress.add((position, tag)),
    onError: failures.add,
  );
  test('追加文件不重建或重新装载播放器，换项通知与最终完成均只消费一次', () async {
    final a = Object(), b = Object();
    await start(a);
    await player.appendPlaylist([
      AudioPlaylistItem(path: '/cache/b.wav', tag: b),
    ]);
    expect(native.loads, 1);
    expect(native.plays, 1);
    expect(native.sequence.length, 2);
    expect(native.speed, 1.5);
    native.transition(1);
    native.emit();
    expect(started, [a, b]);
    expect(ended, [a]);
    expect(native.sequence.length, 2);
    expect(player.currentTag, same(b));
    native.finish();
    native.finish();
    expect(ended, [a, b]);
    expect(failures, isEmpty);
  });
  test('一次批量追加保持顺序，不重新装载或定位当前音频', () async {
    final a = Object(), b = Object(), c = Object();
    await start(a);
    native.position = const Duration(milliseconds: 400);
    await player.appendPlaylist([
      AudioPlaylistItem(path: '/b.wav', tag: b),
      AudioPlaylistItem(path: '/c.wav', tag: c),
    ]);
    expect(native.appends, 1);
    expect(native.sequence.map((source) => source.tag), [a, b, c]);
    expect(native.loads, 1);
    expect(native.seeks, isEmpty);
    expect(native.position.inMilliseconds, 400);
    await player.appendPlaylist([]);
    expect(native.appends, 1);
  });
  test('位置与无应用操作的定位不触发换项，新会话允许切换且不误报自然完成', () async {
    final a = Object(), b = Object();
    await start(a);
    await player.appendPlaylist([AudioPlaylistItem(path: '/b.wav', tag: b)]);
    native.position = const Duration(milliseconds: 900);
    native.emit();
    progress.clear();
    native.currentIndex = 1;
    native.positions.add(native.position);
    expect(started, [a]);
    expect(ended, isEmpty);
    expect(progress, isEmpty);
    native.transition(1, natural: false, resetPosition: false);
    expect(started, [a]);
    expect(ended, isEmpty);
    expect(progress, isEmpty);
    await start(b);
    progress.clear();
    native.position = const Duration(milliseconds: 20);
    native.emit();
    expect(progress.single.$1.inMilliseconds, 20);
    expect(progress.single.$2, same(b));
  });

  for (final locked in [false, true]) {
    test('3→2→3不污染起播或完成，追加锁内=$locked', () async {
      final a = Object(), b = Object(), c = Object(), d = Object();
      await start(a);
      await player.appendPlaylist([
        AudioPlaylistItem(path: '/b.wav', tag: b),
        AudioPlaylistItem(path: '/c.wav', tag: c),
      ]);
      native.transition(1);
      native.transition(2);
      Future<void>? append;
      if (locked) {
        native.appendGate = Completer<void>();
        append = player.appendPlaylist([
          AudioPlaylistItem(path: '/d.wav', tag: d),
        ]);
        await flush();
      }
      native.transition(1);
      native.transition(2);
      if (locked) {
        native.appendGate!.complete();
        await append;
      }
      expect(started, [a, b, c]);
      expect(ended, [a, b]);
      expect(player.currentPlaylistTag, same(c));
      if (locked) native.transition(3);
      native.finish();
      expect(ended, locked ? [a, b, c, d] : [a, b, c]);
      expect(failures, isEmpty);
    });
  }

  test('追加锁内首次进入末项后回退恢复，不得提前结束末项', () async {
    final a = Object(), b = Object(), c = Object();
    await start(a);
    await player.appendPlaylist([AudioPlaylistItem(path: '/b.wav', tag: b)]);
    native.transition(1);
    native.appendGate = Completer<void>();
    final append = player.appendPlaylist([
      AudioPlaylistItem(path: '/c.wav', tag: c),
    ]);
    await flush();
    native.transition(2);
    native.transition(1);
    native.transition(2);
    native.appendGate!.complete();
    await append;
    expect(started, [a, b, c]);
    expect(ended, [a, b]);
    native.finish();
    expect(ended, [a, b, c]);
  });

  test('锁内真实连续推进保留顺序，回调看到的内部项目已提交', () async {
    final tags = List.generate(4, (_) => Object());
    final notifications = <String>[];
    await player.startPlaylist(
      AudioPlaylistItem(path: '/0.wav', tag: tags[0]),
      speed: 1,
      onStarted: (tag) {
        expect(player.currentPlaylistTag, same(tag));
        notifications.add('start${tags.indexOf(tag)}');
      },
      onCompleted: (tag) {
        expect(player.currentPlaylistTag, isNot(same(tag)));
        notifications.add('end${tags.indexOf(tag)}');
      },
      onProgress: (_, _, _) {},
      onError: failures.add,
    );
    await player.appendPlaylist([
      for (var i = 1; i < 3; i++)
        AudioPlaylistItem(path: '/$i.wav', tag: tags[i]),
    ]);
    native.appendGate = Completer<void>();
    final append = player.appendPlaylist([
      AudioPlaylistItem(path: '/3.wav', tag: tags[3]),
    ]);
    await flush();
    native.transition(1);
    native.transition(2);
    native.transition(3);
    expect(notifications, ['start0']);
    native.appendGate!.complete();
    await append;
    expect(notifications, [
      'start0',
      'end0',
      'start1',
      'end1',
      'start2',
      'end2',
      'start3',
    ]);
    expect(native.seeks, isEmpty);
  });

  test('列表快照不能宣布起播，非相邻跳跃不能补造完成', () async {
    final a = Object(), b = Object(), c = Object();
    await start(a);
    await player.appendPlaylist([
      AudioPlaylistItem(path: '/b.wav', tag: b),
      AudioPlaylistItem(path: '/c.wav', tag: c),
    ]);
    native.currentIndex = 1;
    native.emit();
    expect(started, [a]);
    expect(ended, isEmpty);
    native.currentIndex = 0;
    native.emit();
    native.transition(2);
    expect(started, [a]);
    expect(ended, isEmpty);
    expect(player.currentPlaylistTag, same(a));
  });

  test('暂停期间真实换段候选恢复后核对，停止后的迟到事件不生效', () async {
    final a = Object(), b = Object(), c = Object();
    await start(a);
    await player.appendPlaylist([
      AudioPlaylistItem(path: '/b.wav', tag: b),
      AudioPlaylistItem(path: '/c.wav', tag: c),
    ]);
    await player.pause();
    native.transition(1);
    expect(started, [a]);
    expect(ended, isEmpty);
    await player.resume();
    expect(started, [a, b]);
    expect(ended, [a]);
    await player.stop();
    native.currentIndex = null;
    native.emit();
    expect(started, [a, b]);
    expect(ended, [a]);
  });

  test('旧项完成回调停止后，不再发送新项起播', () async {
    final a = Object(), b = Object();
    Future<void>? stopping;
    await player.startPlaylist(
      AudioPlaylistItem(path: '/a.wav', tag: a),
      speed: 1,
      onStarted: started.add,
      onCompleted: (tag) {
        ended.add(tag);
        stopping = player.stop();
      },
      onProgress: (_, _, _) {},
      onError: failures.add,
    );
    await player.appendPlaylist([AudioPlaylistItem(path: '/b.wav', tag: b)]);
    native.transition(1);
    await stopping;
    expect(started, [a]);
    expect(ended, [a]);
    expect(player.currentPlaylistTag, isNull);
  });

  test('应用重播和返回上一段建立新会话，不被自然推进约束拦截', () async {
    final a = Object(), b = Object();
    await start(a);
    await player.appendPlaylist([AudioPlaylistItem(path: '/b.wav', tag: b)]);
    native.transition(1);
    await start(a);
    native.finish();
    expect(started, [a, b, a]);
    expect(ended, [a, a]);
  });

  test('完成事件先到而派生索引稍后收敛，快照只唤醒已有完成证据', () async {
    final a = Object(), b = Object();
    await start(a);
    await player.appendPlaylist([AudioPlaylistItem(path: '/b.wav', tag: b)]);
    native.transition(1);
    final complete = audio.PlaybackEvent(
      currentIndex: 1,
      processingState: audio.ProcessingState.completed,
      duration: native.duration,
      updatePosition: native.duration,
      updateTime: native.playbackEvent.updateTime.add(
        const Duration(milliseconds: 1),
      ),
    );
    native.currentIndex = 0;
    native.processingState = audio.ProcessingState.completed;
    native.playbackEvent = complete;
    native.events.add(complete);
    expect(ended, [a]);
    native.currentIndex = 1;
    native.sequences.add(native.sequenceState);
    await flush();
    expect(started, [a, b]);
    expect(ended, [a, b]);
  });

  test('旧完成回调换会话后不补发旧新项通知', () async {
    final a = Object(), b = Object(), next = Object();
    Future<void>? replacement;
    await player.startPlaylist(
      AudioPlaylistItem(path: '/a.wav', tag: a),
      speed: 1,
      onStarted: started.add,
      onCompleted: (tag) {
        ended.add(tag);
        replacement = start(next);
      },
      onProgress: (_, _, _) {},
      onError: failures.add,
    );
    await player.appendPlaylist([AudioPlaylistItem(path: '/b.wav', tag: b)]);
    native.transition(1);
    await replacement;
    expect(started, [a, next]);
    expect(ended, [a]);
    expect(player.currentPlaylistTag, same(next));
  });
  test('位置流按间隔合并发布，播放事件与换项仍即时上报', () async {
    final local = ReadAloudAudioPlayer(
      createPlayer: () => native,
      progressInterval: const Duration(milliseconds: 50),
    );
    addTearDown(local.dispose);
    final published = <Duration>[];
    await local.startPlaylist(
      AudioPlaylistItem(path: '/cache/a.wav', tag: Object()),
      speed: 1,
      onStarted: (_) {},
      onCompleted: (_) {},
      onProgress: (position, _, _) => published.add(position),
      onError: (_) {},
    );
    published.clear();
    // 播放事件先推进位置基点（换项后的第一份采样不参与节流）
    native.emit();
    published.clear();
    // 模拟 60 Hz 位置采样：节流窗口内只发布一次
    for (var i = 0; i < 20; i++) {
      native.positions.add(Duration(milliseconds: i * 16));
    }
    expect(published, hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    native.positions.add(const Duration(milliseconds: 400));
    expect(published, hasLength(2));
    // 播放事件不属于位置采样，始终即时上报
    native.emit();
    expect(published, hasLength(3));
  });

  test('追加等待中旧队尾才结束，恢复相邻项且按完成再起播通知', () async {
    final a = Object(), b = Object();
    final notifications = <String>[];
    await player.startPlaylist(
      AudioPlaylistItem(path: '/a.wav', tag: a),
      speed: 1,
      onStarted: (tag) =>
          notifications.add(identical(tag, a) ? 'startA' : 'startB'),
      onCompleted: (tag) {
        expect(player.currentPlaylistTag, same(b));
        notifications.add('endA');
      },
      onProgress: (_, _, _) {},
      onError: failures.add,
    );
    native.appendGate = Completer<void>();
    final append = player.appendPlaylist([
      AudioPlaylistItem(path: '/b.wav', tag: b),
    ]);
    await flush();
    native.finish();
    native.appendGate!.complete();
    await append;
    await flush();
    expect(player.currentPlaylistTag, same(b));
    expect(native.seeks, [(Duration.zero, 1)]);
    expect(notifications, ['startA', 'endA', 'startB']);
  });

  test('新项有效基点无需后续播放事件，定时位置采样持续发布', () async {
    final local = ReadAloudAudioPlayer(
      createPlayer: () => native,
      progressInterval: Duration.zero,
    );
    addTearDown(local.dispose);
    final published = <Duration>[];
    await local.startPlaylist(
      AudioPlaylistItem(path: '/a.wav', tag: Object()),
      speed: 1,
      onStarted: (_) {},
      onCompleted: (_) {},
      onProgress: (p, _, _) => published.add(p),
      onError: failures.add,
    );
    await local.appendPlaylist([
      AudioPlaylistItem(path: '/b.wav', tag: Object()),
    ]);
    native.transition(1);
    published.clear();
    for (final ms in [100, 300, 600, 900]) {
      native.position = Duration(milliseconds: ms);
      native.positions.add(native.position);
    }
    expect(published.map((p) => p.inMilliseconds), [100, 300, 600, 900]);
  });

  test('新索引沿用旧位置基点时仍隔离，更新基点后恢复发布', () async {
    final a = Object(), b = Object();
    await start(a);
    await player.appendPlaylist([AudioPlaylistItem(path: '/b.wav', tag: b)]);
    native.position = const Duration(milliseconds: 900);
    native.emit();
    final previous = native.playbackEvent;
    native.currentIndex = 1;
    native.playbackEvent = audio.PlaybackEvent(
      currentIndex: 1,
      processingState: audio.ProcessingState.ready,
      duration: native.duration,
      updatePosition: previous.updatePosition,
      updateTime: previous.updateTime,
    );
    native.discontinuities.add(
      audio.PositionDiscontinuity(
        audio.PositionDiscontinuityReason.autoAdvance,
        previous,
        native.playbackEvent,
      ),
    );
    progress.clear();
    native.positions.add(native.position);
    expect(progress, isEmpty);
    native.position = const Duration(milliseconds: 100);
    native.playbackEvent = audio.PlaybackEvent(
      currentIndex: 1,
      processingState: audio.ProcessingState.ready,
      duration: native.duration,
      updatePosition: native.position,
      updateTime: previous.updateTime,
    );
    native.events.add(native.playbackEvent);
    expect(progress.single.$1.inMilliseconds, 100);
    expect(progress.single.$2, same(b));
  });

  test('队列到尾后的迟到音频重新起播，暂停期间追加不自动播放', () async {
    final a = Object(), b = Object();
    await start(a);
    native.finish();
    await player.pause();
    final plays = native.plays;
    await player.appendPlaylist([
      AudioPlaylistItem(path: '/cache/b.wav', tag: b),
    ]);
    expect(native.plays, plays);
    expect(player.currentTag, same(a));
    await player.resume();
    expect(player.currentTag, same(b));
    expect(native.loads, 1);
    expect(native.plays, plays + 1);
  });
  test('追加确认前原生已进入下一片，不回退段首或重复调用播放', () async {
    final a = Object(), b = Object();
    await start(a);
    native.finish();
    final plays = native.plays;
    native.appendGate = Completer<void>();
    final append = player.appendPlaylist([
      AudioPlaylistItem(path: '/cache/b.wav', tag: b),
    ]);
    await flush();
    native.transition(1);
    native.position = const Duration(milliseconds: 350);
    native.appendGate!.complete();
    await append;
    expect(native.seeks, isEmpty);
    expect(native.plays, plays);
    expect(native.position, const Duration(milliseconds: 350));
    expect(player.currentTag, same(b));
    expect(started, [a, b]);
    expect(ended, [a]);
  });
  test('仍停在已结束的旧片时恢复相邻项，连续追加不跳过正文', () async {
    final a = Object(), b = Object(), c = Object();
    await start(a);
    native.finish();
    final plays = native.plays;
    final first = player.appendPlaylist([
      AudioPlaylistItem(path: '/cache/b.wav', tag: b),
    ]);
    final second = player.appendPlaylist([
      AudioPlaylistItem(path: '/cache/c.wav', tag: c),
    ]);
    await Future.wait([first, second]);
    expect(native.seeks, [(Duration.zero, 1)]);
    expect(native.plays, plays + 1);
    expect(player.currentTag, same(b));
    expect(started, [a, b]);
    native.transition(2);
    expect(started, [a, b, c]);
  });
  test('追加期间用户暂停，不定位或自动续播', () async {
    await start(Object());
    native.finish();
    final plays = native.plays;
    native.appendGate = Completer<void>();
    final append = player.appendPlaylist([
      AudioPlaylistItem(path: '/cache/b.wav', tag: Object()),
    ]);
    await flush();
    await player.pause();
    native.appendGate!.complete();
    await append;
    expect(native.seeks, isEmpty);
    expect(native.plays, plays);
    expect(native.playing, isFalse);
  });
  test('追加期间停止作废旧会话，不产生迟到定位或播放', () async {
    await start(Object());
    native.finish();
    final plays = native.plays;
    native.appendGate = Completer<void>();
    final append = player.appendPlaylist([
      AudioPlaylistItem(path: '/cache/b.wav', tag: Object()),
    ]);
    await flush();
    final stop = player.stop();
    native.appendGate!.complete();
    await Future.wait([append, stop]);
    expect(native.seeks, isEmpty);
    expect(native.plays, plays);
    expect(player.currentTag, isNull);
    native.appendGate = null;
    final next = Object();
    await start(next);
    expect(player.currentTag, same(next));
  });
  test('追加后的缓冲状态不当成音频结束，不强制定位', () async {
    final a = Object();
    await start(a);
    native.finish();
    final plays = native.plays;
    native.appendGate = Completer<void>();
    final append = player.appendPlaylist([
      AudioPlaylistItem(path: '/cache/b.wav', tag: Object()),
    ]);
    await flush();
    native.processingState = audio.ProcessingState.buffering;
    native.appendGate!.complete();
    await append;
    expect(native.seeks, isEmpty);
    expect(native.plays, plays);
    expect(player.currentTag, same(a));
  });
  test('追加期间已经进入新片且新片也播完，不依据旧身份重播新片', () async {
    final a = Object(), b = Object();
    await start(a);
    native.finish();
    final plays = native.plays;
    native.appendGate = Completer<void>();
    final append = player.appendPlaylist([
      AudioPlaylistItem(path: '/cache/b.wav', tag: b),
    ]);
    await flush();
    native.transition(1);
    native.finish();
    native.appendGate!.complete();
    await append;
    expect(native.seeks, isEmpty);
    expect(native.plays, plays);
    expect(started, [a, b]);
    expect(ended, [a, b]);
  });
  test('停止使旧事件失效，下一会话复用播放器对象并清空旧队列', () async {
    final a = Object(), b = Object();
    await start(a);
    await player.stop();
    native.finish();
    expect(ended, isEmpty);
    await start(b);
    native.finish();
    expect(started, [a, b]);
    expect(ended, [b]);
    expect(native.loads, 2);
  });
  test('装载期间停止不会迟到开播，后续会话可正常开始', () async {
    native.loadGate = Completer<void>();
    final old = start(Object());
    await flush();
    final error = expectLater(
      old,
      throwsA(isA<audio.PlayerInterruptedException>()),
    );
    await player.stop();
    await error;
    expect(native.plays, 0);
    native.loadGate = null;
    await start(Object());
    expect(native.plays, 1);
  });
  test('异步播放错误传递给当前队列，不自动跳过下一项', () async {
    await start(Object());
    final failure = audio.PlayerException(4, '解码失败', 0);
    native.errors.add(failure);
    expect(failures, [same(failure)]);
    expect(native.currentIndex, 0);
  });
  test('平台逐项完成不当作队尾，追加不能跳到新尾项而漏播已排正文', () async {
    final a = Object(), b = Object(), c = Object();
    await start(a);
    await player.appendPlaylist([AudioPlaylistItem(path: '/b.wav', tag: b)]);
    native.finish();
    expect(player.playlistFinished, isFalse);
    await player.appendPlaylist([AudioPlaylistItem(path: '/c.wav', tag: c)]);
    expect(player.currentTag, same(a));
    expect(ended, isEmpty);
    native.transition(1);
    expect(started, [a, b]);
  });
  test('网络音频和本地试听共用原生后端，切换清空旧源且保持同一对象', () async {
    final tag = Object();
    final completed = <Object?>[];
    player.onCompleted = completed.add;
    await player.playUrl(
      'https://fixture.test/book.mp3?part=1',
      speed: 1.3,
      tag: tag,
    );
    expect(player.currentTag, same(tag));
    expect(player.currentUrl, 'https://fixture.test/book.mp3?part=1');
    expect(native.speed, 1.3);
    expect(
      (native.sequence.single as audio.UriAudioSource).uri.scheme,
      'https',
    );
    native.finish();
    native.finish();
    expect(completed, [same(tag)]);
    final localPath = Directory.systemTemp.uri
        .resolve('tts/音色.wav')
        .toFilePath();
    await player.playLocalFile(localPath, tag: null);
    expect(player.currentTag, isNull);
    final localUri = (native.sequence.single as audio.UriAudioSource).uri;
    expect(localUri.scheme, 'file');
    expect(localUri.toFilePath(), localPath);
    expect(native.loads, 2);
  });

  test('单文件暂停原位换绑，只允许预期标签恢复并将回调归属于新会话', () async {
    final previous = Object(), next = Object();
    final completed = <Object?>[], progress = <Object?>[];
    player.onCompleted = completed.add;
    player.onProgress = (_, _, tag) => progress.add(tag);
    await player.playLocalFile('/voice.wav', tag: previous);
    await player.seek(const Duration(milliseconds: 900));
    await player.pause();
    expect(completed, isEmpty);
    final plays = native.plays;
    expect(
      await player.resumeWithTag(previousTag: Object(), tag: next),
      isFalse,
    );
    expect(native.plays, plays);
    progress.clear();
    expect(
      await player.resumeWithTag(previousTag: previous, tag: next),
      isTrue,
    );
    expect(player.position.inMilliseconds, 900);
    expect(native.loads, 1);
    expect(progress, isNotEmpty);
    expect(progress, everyElement(same(next)));
    native.finish();
    expect(completed, [same(next)]);
  });

  test('未知媒体时长或仅暂停不能误报完成，异步解码失败携带当前身份', () async {
    final tag = Object();
    final completed = <Object?>[];
    final errors = <(Object, Object?)>[];
    player.onCompleted = completed.add;
    player.onError = (error, tag) => errors.add((error, tag));
    await player.playUrl('https://fixture.test/live', tag: tag);
    native.duration = Duration.zero;
    native.finish();
    expect(completed, isEmpty);
    final error = audio.PlayerException(4, '音频解码失败', 0);
    native.errors.add(error);
    expect(errors.single.$1, same(error));
    expect(errors.single.$2, same(tag));
    expect(completed, isEmpty);
    await player.stop();
    native.errors.add(error);
    expect(errors, hasLength(1));
  });

  test('同后端在正文队列、网络音频书和本地试听之间切换，不残留旧回调', () async {
    final oldCue = Object(), book = Object();
    await start(oldCue);
    await player.playUrl('https://fixture.test/book.mp3', tag: book);
    native.finish();
    expect(ended, isEmpty);
    expect(player.currentTag, same(book));
    await player.playLocalFile('/preview.wav');
    await start(Object());
    expect(native.sequence, hasLength(1));
    expect(native.loads, 4);
  });
  test('试听独立实例不接管正文的播放器、标签或队列', () async {
    final previewNative = _Native();
    final preview = ReadAloudAudioPlayer(createPlayer: () => previewNative);
    addTearDown(preview.dispose);
    final bookTag = Object(), previewTag = Object();
    await start(bookTag);
    await preview.playLocalFile('/preview.wav', tag: previewTag);
    await preview.stop();
    expect(player.currentTag, same(bookTag));
    expect(native.playing, isTrue);
    expect(native.sequence, hasLength(1));
    expect(preview.currentTag, isNull);
  });
  test('网络装载失败清空原生引用，下一次本地播放可复用对象', () async {
    native.loadError = StateError('网络音频无效');
    await expectLater(
      player.playUrl('https://fixture.test/bad'),
      throwsStateError,
    );
    expect(player.isInitialized, isFalse);
    expect(player.currentTag, isNull);
    expect(native.sequence, isEmpty);
    native.loadError = null;
    await player.playLocalFile('/valid.wav');
    expect(native.loads, 2);
    expect(player.isPlaying, isTrue);
  });
  for (final local in [true, false]) {
    testWidgets('页面进入后台不暂停纯音频，前台返回不重复起播：local=$local', (tester) async {
      await tester.runAsync(() async {
        try {
          if (local) {
            await player.playLocalFile('/background.wav');
          } else {
            await player.playUrl('https://fixture.test/book.mp3');
          }
          final pauses = native.pauses, plays = native.plays;
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          expect(native.pauses, pauses);
          expect(native.plays, plays);
          expect(player.isPlaying, isTrue);
          await player.pause();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          expect(native.plays, plays);
          expect(player.isPlaying, isFalse);
        } finally {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
      });
    });
  }
}
