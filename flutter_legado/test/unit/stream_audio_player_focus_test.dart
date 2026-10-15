// D1 真机缺陷回归：底层 media3 播放器不得与 MediaSessionBridge 抢音频焦点。
//
// 背景（QA 证据 .tmp/tts_qa/logcat_focus_conflict.txt）：
//   MediaSessionBridge 先 requestAudioFocus(CONTENT_TYPE_MUSIC)，
//   video_player 的 media3 ExoPlayer 播放本地文件时再次 requestAudioFocus
//   (CONTENT_TYPE_MOVIE) → 同应用两个焦点客户端互抢 → 桥收到
//   onAudioFocusChange(-1)[LOSS] → Dart 误判外部抢占 pause()，播放 20ms 即停。
//
// 修复契约：StreamAudioPlayer 为每个控制器传
// `VideoPlayerOptions(mixWithOthers: true)`；video_player Android 实现将其
// 映射为 `ExoPlayer.setAudioAttributes(attrs, handleAudioFocus=false)`
// （见 video_player_android VideoPlayer.setAudioAttributes）。
// 本测试用 Fake VideoPlayerPlatform 截获真实的 setMixWithOthers 平台调用，
// 钉住「网络流 + 本地文件两条路径都不会让底层播放器接管焦点」。
//
// 注：直接 import platform_interface 仅用于测试 Fake（transitive 依赖，
// 非 pubspec 直接声明，按惯例 ignore lint）。
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:flutter_legado/src/screens/video_screen.dart';
import 'package:flutter_legado/src/services/stream_audio_player.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/cloud_read_aloud_engine.dart';
import 'package:flutter_legado/src/features/read_aloud/playback/read_aloud_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeVideoPlayerPlatform fakePlatform;

  setUp(() {
    fakePlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
  });

  test('playbackOptions 关闭底层播放器焦点处理（mixWithOthers=true）', () {
    expect(StreamAudioPlayer.playbackOptions.mixWithOthers, isTrue);
  });

  test('视频页显式恢复底层播放器焦点处理（mixWithOthers=false）', () {
    // video_player 的 mixWithOthers 是插件级 sharedOptions（全局），
    // 听书/TTS 置 true 后，视频页必须显式置 false 才能保持默认焦点语义。
    expect(videoPlaybackOptions.mixWithOthers, isFalse);
    expect(videoPlaybackOptions.allowBackgroundPlayback, isFalse);
  });

  test('playLocalFile：底层播放器收到 mixWithOthers=true（不抢焦点）', () async {
    final player = StreamAudioPlayer();
    await player.playLocalFile('/tmp/tts/para_1.wav');
    await player.dispose();

    expect(fakePlatform.mixWithOthersCalls, [true]);
    expect(fakePlatform.createdCount, 1);
  });

  test('playUrl（听书流模式同链路）：底层播放器收到 mixWithOthers=true', () async {
    final player = StreamAudioPlayer();
    await player.playUrl('https://cdn.example.com/ch1.mp3');
    await player.dispose();

    expect(fakePlatform.mixWithOthersCalls, [true]);
    expect(fakePlatform.createdCount, 1);
  });

  for (final local in [true, false]) {
    testWidgets('音频切到后台继续播放，返回前台不重复启动：本地=$local', (tester) async {
      final player = StreamAudioPlayer();
      await tester.runAsync(() async {
        try {
          if (local) {
            await player.playLocalFile('/tmp/cloud-tts/paragraph.wav');
          } else {
            await player.playUrl('https://cdn.example.com/book.mp3');
          }
          final pauses = fakePlatform.pauses.length;
          final plays = fakePlatform.plays.length;
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await Future<void>.delayed(Duration.zero);
          expect(player.isPlaying, isTrue);
          expect(fakePlatform.pauses.length, pauses);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await Future<void>.delayed(Duration.zero);
          expect(fakePlatform.plays.length, plays);
        } finally {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await player.dispose();
        }
      });
    });
  }

  testWidgets('后台手动暂停后，返回前台不会擅自续播', (tester) async {
    final player = StreamAudioPlayer();
    await tester.runAsync(() async {
      try {
        await player.playLocalFile('/tmp/cloud-tts/paragraph.wav');
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);
        await player.pause();
        final plays = fakePlatform.plays.length;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await Future<void>.delayed(Duration.zero);
        expect(player.isPlaying, isFalse);
        expect(fakePlatform.plays.length, plays);
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await player.dispose();
      }
    });
  });

  testWidgets('云端分片在后台完成后装载下一片，停止后前台恢复不重播', (tester) async {
    final player = StreamAudioPlayer();
    final synthesizer = _CloudSynthesizer();
    final engine = CloudReadAloudEngine(
      synthesizer: () => synthesizer,
      player: player,
      cache: () => throw StateError('本夹具不登记缓存'),
    );
    player.onCompleted = engine.handleCompleted;
    var completed = 0;
    final session = ReadAloudSession(
      isCurrent: () => true,
      onProgress: (_) {},
      onError: (error) => fail('$error'),
      onCompleted: () => completed++,
    );
    await tester.runAsync(() async {
      try {
        await engine.speak(
          ReadAloudRequest(engineUrl: 'cloud://test', text: '甲' * 4001),
          session,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);
        expect(player.isPlaying, isTrue);
        fakePlatform.emit(1, VideoEvent(eventType: VideoEventType.completed));
        for (var i = 0; i < 15; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(synthesizer.texts, hasLength(2));
        expect(synthesizer.texts.join(), '甲' * 4001);
        expect(player.isPlaying, isTrue);
        expect(completed, 0);
        fakePlatform.emit(2, VideoEvent(eventType: VideoEventType.completed));
        await Future<void>.delayed(Duration.zero);
        expect(completed, 1);
        await engine.stop();
        final plays = fakePlatform.plays.length;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await Future<void>.delayed(Duration.zero);
        expect(player.isPlaying, isFalse);
        expect(fakePlatform.plays.length, plays);
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await engine.stop();
        await player.dispose();
      }
    });
  });
  test('原位续播保留位置和控制器，回调仅绑定新会话并且只完成一次', () async {
    final player = StreamAudioPlayer();
    addTearDown(player.dispose);
    final oldTag = Object(), tag = Object();
    final completions = <Object?>[];
    final progress = <Object?>[];
    player.onCompleted = completions.add;
    player.onProgress = (_, _, tag) => progress.add(tag);
    await player.playLocalFile('/tmp/tts/para.wav', tag: oldTag);
    await player.seek(const Duration(milliseconds: 900));
    await player.pause();
    // 离末尾不足 200ms 的暂停不能被误判为自然完成。
    expect(completions, isEmpty);
    progress.clear();
    expect(await player.resumeWithTag(previousTag: oldTag, tag: tag), isTrue);
    expect(player.position, const Duration(milliseconds: 900));
    expect(fakePlatform.createdCount, 1);
    expect(progress, isNotEmpty);
    expect(progress, everyElement(same(tag)));
    fakePlatform.emit(1, VideoEvent(eventType: VideoEventType.completed));
    await Future<void>.delayed(Duration.zero);
    expect(completions, [same(tag)]);
    fakePlatform.emit(1, VideoEvent(eventType: VideoEventType.completed));
    await Future<void>.delayed(Duration.zero);
    expect(completions, hasLength(1));
  });

  test('预期标签不匹配不能恢复共享播放器；普通音频书续播保留原标签', () async {
    final player = StreamAudioPlayer();
    addTearDown(player.dispose);
    final tag = Object();
    await player.playUrl('https://cdn.example.com/book.mp3', tag: tag);
    await player.pause();
    final plays = fakePlatform.plays.length;
    expect(
      await player.resumeWithTag(previousTag: Object(), tag: Object()),
      isFalse,
    );
    expect(fakePlatform.plays.length, plays);
    await player.resume();
    expect(player.currentTag, same(tag));
    expect(fakePlatform.createdCount, 1);
  });

  test('初始化期间停止，不会在迟到的初始化完成后重新播放', () async {
    fakePlatform.autoInitialize = false;
    final player = StreamAudioPlayer();
    final load = player.playLocalFile('/tmp/tts/late.wav', tag: Object());
    await Future<void>.delayed(Duration.zero);
    expect(fakePlatform.createdCount, 1);
    final stop = player.stop();
    fakePlatform.initialize(1);
    await load;
    await stop;
    expect(fakePlatform.plays, isEmpty);
    expect(player.isInitialized, isFalse);
  });

  test('替换音频仍在释放旧控制器时停止，不创建新控制器', () async {
    final player = StreamAudioPlayer();
    await player.playLocalFile('/tmp/tts/first.wav');
    fakePlatform.pauseBarrier = Completer<void>();
    final replacement = player.playLocalFile('/tmp/tts/second.wav');
    await Future<void>.delayed(Duration.zero);
    await player.stop();
    fakePlatform.pauseBarrier!.complete();
    await replacement;
    expect(fakePlatform.createdCount, 1);
    expect(fakePlatform.plays, [1]);
    expect(player.currentUrl, isNull);
  });
}

class _CloudSynthesizer implements CloudTtsSynthesizer {
  final texts = <String>[];

  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required String engineId,
    required String text,
    String? voiceId,
    Map<String, dynamic>? voiceOptions,
    HttpTtsCancellation? cancellation,
  }) async {
    texts.add(text);
    return HttpTtsAudio(
      audioPath: '/tmp/cloud-tts/part-${texts.length}.wav',
      fromCache: true,
      contentType: 'audio/wav',
    );
  }
}

/// 记录 setMixWithOthers / createWithOptions 的最小 Fake 平台实现。
///
/// initialize() 需要 initialized 事件才能完成，这里在创建时向单订阅
/// controller 预写一个 initialized 事件（listen 时缓冲投递）。
class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final List<bool> mixWithOthersCalls = [];
  final Map<int, StreamController<VideoEvent>> _events = {};
  int createdCount = 0;
  int _nextId = 1;
  bool autoInitialize = true;
  Completer<void>? pauseBarrier;
  final plays = <int>[];
  final pauses = <int>[];
  final positions = <int, Duration>{};

  void emit(int id, VideoEvent event) => _events[id]!.add(event);
  void initialize(int id) => emit(
    id,
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 1),
      size: const Size(16, 16),
    ),
  );

  @override
  Future<void> init() async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {
    mixWithOthersCalls.add(mixWithOthers);
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    createdCount++;
    final id = _nextId++;
    final controller = StreamController<VideoEvent>();
    _events[id] = controller;
    if (autoInitialize) initialize(id);
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _events[playerId]?.stream ?? const Stream<VideoEvent>.empty();

  @override
  Future<void> dispose(int playerId) async {
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async => plays.add(playerId);

  @override
  Future<void> pause(int playerId) async {
    pauses.add(playerId);
    await pauseBarrier?.future;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    positions[playerId] = position;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async =>
      positions[playerId] ?? Duration.zero;
}
