import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as audio;
import 'package:flutter_legado/src/services/audio_playlist_player.dart';
import 'package:flutter_legado/src/services/read_aloud_audio_player.dart';

class _Native extends Fake implements audio.AudioPlayer {
  final events = StreamController<audio.PlaybackEvent>.broadcast(sync: true);
  final positions = StreamController<Duration>.broadcast(sync: true);
  final errors = StreamController<audio.PlayerException>.broadcast(sync: true);
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
  int loads = 0, plays = 0, stops = 0, clears = 0, pauses = 0;
  @override
  double speed = 1;
  Completer<void>? loadGate;
  Completer<void>? appendGate;
  final seeks = <(Duration?, int?)>[];
  Object? loadError;
  bool reportRemovalIndex = true;
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
  void emit() => events.add(
    audio.PlaybackEvent(
      currentIndex: currentIndex,
      processingState: processingState,
      duration: duration,
    ),
  );
  void transition(int index) {
    currentIndex = index;
    position = Duration.zero;
    processingState = audio.ProcessingState.ready;
    emit();
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
  Future<void> addAudioSource(audio.AudioSource source) async {
    sequence.addAll(source.sequence);
    emit();
    await appendGate?.future;
  }

  @override
  Future<void> removeAudioSourceRange(int start, int end) async {
    // 模拟真实插件：Dart来源列表先改，原生索引稍后到达。
    sequence.removeRange(start, end);
    emit();
    await Future<void>.delayed(Duration.zero);
    if (reportRemovalIndex) {
      currentIndex = (currentIndex ?? 0) - (end - start);
      emit();
    }
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
  setUp(() {
    native = _Native();
    player = ReadAloudAudioPlayer(createPlayer: () => native);
    started = [];
    ended = [];
    failures = [];
  });
  tearDown(() => player.dispose());
  Future<void> start(Object tag) => player.startPlaylist(
    AudioPlaylistItem(path: '/cache/a.wav', tag: tag),
    speed: 1.5,
    onStarted: started.add,
    onCompleted: ended.add,
    onProgress: (_, _, _) {},
    onError: failures.add,
  );
  test('追加文件不重建或重新装载播放器，换项通知与最终完成均只消费一次', () async {
    final a = Object(), b = Object();
    await start(a);
    await player.appendPlaylist(
      AudioPlaylistItem(path: '/cache/b.wav', tag: b),
    );
    expect(native.loads, 1);
    expect(native.plays, 1);
    expect(native.sequence.length, 2);
    expect(native.speed, 1.5);
    native.transition(1);
    native.emit();
    expect(started, [a, b]);
    expect(ended, [a]);
    await player.discardPlayedItems();
    expect(native.sequence.length, 1);
    expect(player.currentTag, same(b));
    native.finish();
    native.finish();
    expect(ended, [a, b]);
    expect(failures, isEmpty);
  });
  test('队列到尾后的迟到音频重新起播，暂停期间追加不自动播放', () async {
    final a = Object(), b = Object();
    await start(a);
    native.finish();
    await player.pause();
    final plays = native.plays;
    await player.appendPlaylist(
      AudioPlaylistItem(path: '/cache/b.wav', tag: b),
    );
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
    final append = player.appendPlaylist(
      AudioPlaylistItem(path: '/cache/b.wav', tag: b),
    );
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
    final first = player.appendPlaylist(
      AudioPlaylistItem(path: '/cache/b.wav', tag: b),
    );
    final second = player.appendPlaylist(
      AudioPlaylistItem(path: '/cache/c.wav', tag: c),
    );
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
    final append = player.appendPlaylist(
      AudioPlaylistItem(path: '/cache/b.wav', tag: Object()),
    );
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
    final append = player.appendPlaylist(
      AudioPlaylistItem(path: '/cache/b.wav', tag: Object()),
    );
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
    final append = player.appendPlaylist(
      AudioPlaylistItem(path: '/cache/b.wav', tag: Object()),
    );
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
    final append = player.appendPlaylist(
      AudioPlaylistItem(path: '/cache/b.wav', tag: b),
    );
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
  test('裁去已播文件时忽略来源列表和原生索引不同步的中间态', () async {
    final a = Object(), b = Object(), c = Object();
    await start(a);
    await player.appendPlaylist(AudioPlaylistItem(path: '/b.wav', tag: b));
    await player.appendPlaylist(AudioPlaylistItem(path: '/c.wav', tag: c));
    native.transition(1);
    await player.discardPlayedItems();
    expect(started, [a, b]);
    expect(player.currentTag, same(b));
    native.transition(1);
    expect(started, [a, b, c]);
    native.finish();
    expect(ended, [a, b, c]);
  });
  test('平台逐项完成不当作队尾，追加不能跳到新尾项而漏播已排正文', () async {
    final a = Object(), b = Object(), c = Object();
    await start(a);
    await player.appendPlaylist(AudioPlaylistItem(path: '/b.wav', tag: b));
    native.finish();
    expect(player.playlistFinished, isFalse);
    await player.appendPlaylist(AudioPlaylistItem(path: '/c.wav', tag: c));
    expect(player.currentTag, same(a));
    expect(ended, isEmpty);
    native.transition(1);
    expect(started, [a, b]);
  });
  test('WinRT删前项不回传新索引，显式保存当前位置并校正，不能跳过当前片', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    native.reportRemovalIndex = false;
    final a = Object(), b = Object(), c = Object();
    await start(a);
    await player.appendPlaylist(AudioPlaylistItem(path: '/b.wav', tag: b));
    await player.appendPlaylist(AudioPlaylistItem(path: '/c.wav', tag: c));
    native.transition(1);
    native.position = const Duration(milliseconds: 100);
    await player.discardPlayedItems();
    expect(started, [a, b]);
    expect(player.currentTag, same(b));
    expect(native.currentIndex, 0);
    expect(native.position.inMilliseconds, 100);
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
    await player.playLocalFile('C:/tts/音色.wav', tag: null);
    expect(player.currentTag, isNull);
    expect((native.sequence.single as audio.UriAudioSource).uri.scheme, 'file');
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
