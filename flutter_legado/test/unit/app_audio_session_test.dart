import 'package:flutter/foundation.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_legado/src/platform/audio/app_audio_session.dart';
import 'package:flutter_legado/src/services/audio_service.dart';

import '../fixtures/app_audio_session_backend.dart';

void main() {
  late TestAudioSessionBackend backend;
  late AppAudioSession session;
  setUp(() {
    backend = TestAudioSessionBackend();
    session = AppAudioSession(backend);
  });
  tearDown(() => backend.source.close());

  test('iOS unknown 开始保留中断恢复意图，Android 永久丢失不保留', () {
    final begin = AudioInterruptionEvent(true, AudioInterruptionType.unknown);
    expect(mapAudioInterruption(begin, isAndroid: false), AppAudioEvent.pause);
    expect(mapAudioInterruption(begin, isAndroid: true), AppAudioEvent.loss);
    expect(
      mapAudioInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
        isAndroid: false,
      ),
      AppAudioEvent.resume,
    );
    expect(
      mapAudioInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.unknown),
        isAndroid: false,
      ),
      AppAudioEvent.interruptionEnded,
    );
  });

  test('Android忽略模式不申请焦点，关闭后恢复申请，耳机事件仍停止', () async {
    final plugin = _PluginSession();
    final session = AppAudioSession(
      PluginAudioSessionBackend(
        session: () async => plugin,
        platform: TargetPlatform.android,
      ),
    );
    final events = <AppAudioEvent>[];
    final sub = session.events.listen(events.add);
    final lease = (await session.acquire())!;
    await session.setIgnoreAudioFocus(true);
    expect(plugin.activations, [true, false]);
    expect(session.blocksKeepAlive, isTrue);
    plugin.interruptions.add(
      AudioInterruptionEvent(true, AudioInterruptionType.pause),
    );
    plugin.interruptions.add(
      AudioInterruptionEvent(false, AudioInterruptionType.pause),
    );
    await pumpEventQueue();
    expect(events, isEmpty);
    await session.setIgnoreAudioFocus(false);
    expect(plugin.activations, [true, false, true]);
    plugin.noisy.add(null);
    await pumpEventQueue();
    expect(events, [AppAudioEvent.stop]);
    await lease.release();
    await sub.cancel();
    await plugin.close();
  });

  test('iOS混音保留语音类别，系统中断仍暂停且不自动重新激活', () async {
    final plugin = _PluginSession();
    final session = AppAudioSession(
      PluginAudioSessionBackend(
        session: () async => plugin,
        platform: TargetPlatform.iOS,
      ),
    );
    await session.setIgnoreAudioFocus(true);
    expect(plugin.activations, isEmpty);
    final events = <AppAudioEvent>[];
    final sub = session.events.listen(events.add);
    final lease = (await session.acquire())!;
    expect(
      plugin.configuration!.avAudioSessionCategory,
      AVAudioSessionCategory.playback,
    );
    expect(
      plugin.configuration!.avAudioSessionMode,
      AVAudioSessionMode.spokenAudio,
    );
    expect(
      plugin.configuration!.avAudioSessionCategoryOptions,
      AVAudioSessionCategoryOptions.mixWithOthers,
    );
    plugin.interruptions.add(
      AudioInterruptionEvent(true, AudioInterruptionType.unknown),
    );
    await pumpEventQueue();
    await session.setIgnoreAudioFocus(false);
    expect(events, [AppAudioEvent.pause]);
    expect(plugin.activations, [true]);
    expect(
      plugin.configuration!.avAudioSessionCategoryOptions,
      AVAudioSessionCategoryOptions.none,
    );
    await lease.release();
    await sub.cancel();
    await plugin.close();
  });

  test('暂停持有者切换策略只配置，不重新激活；恢复使用仍正常申请', () async {
    var playing = false;
    final lease = (await session.acquire(isPlaying: () => playing))!;
    await session.setIgnoreAudioFocus(true);
    await session.setIgnoreAudioFocus(false);
    expect(backend.policies, [false, true, false]);
    expect(backend.activations, [true]);
    playing = true;
    await session.setIgnoreAudioFocus(true);
    expect(backend.activations, [true, true]);
    await lease.release();
  });

  test('正文与试听独立持有；释放旧使用凭据不使另一方失活', () async {
    final main = (await session.acquire())!;
    final preview = (await session.acquire())!;
    expect(backend.configurations, 2);
    await main.release();
    await main.release();
    expect(backend.activations, [true, true]);
    expect(session.blocksKeepAlive, isTrue);
    await preview.release();
    expect(backend.activations, [true, true, false]);
    expect(session.blocksKeepAlive, isFalse);
  });

  test('平台拒绝时不授予使用凭据，不阻止下一次显式重试', () async {
    backend.granted = false;
    expect(await session.acquire(), isNull);
    expect(session.blocksKeepAlive, isFalse);
    backend.granted = true;
    final lease = (await session.acquire())!;
    await lease.release();
    expect(backend.activations, [true, true, false]);
  });

  test('配置错误保留错误原因，后续操作仍可执行', () async {
    backend.configurationError = StateError('配置失败');
    await expectLater(session.acquire(), throwsStateError);
    expect(backend.activations, isEmpty);
    backend.configurationError = null;
    await (await session.acquire())!.release();
  });

  test('外部临时中断期间正文和保活均不能重新激活', () async {
    final lease = (await session.acquire())!;
    backend.source.add(AppAudioEvent.pause);
    await lease.release();
    expect(await session.acquire(), isNull);
    expect(await session.acquire(audible: false), isNull);
    expect(backend.activations, [true]);
    backend.source.add(AppAudioEvent.resume);
    await (await session.acquire())!.release();
    expect(backend.activations, [true, true, false]);
  });

  test('iOS缺中断结束事件时，手动继续实际重新激活并消费旧中断', () async {
    final audio = AudioService.forTesting(session);
    final events = <AppAudioEvent>[];
    final sub = session.events.listen(events.add);
    expect(await audio.requestAudioFocus(), isTrue);
    backend.source.add(
      mapAudioInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.unknown),
        isAndroid: false,
      ),
    );
    expect(await audio.requestAudioFocus(), isFalse);
    expect(await audio.requestAudioFocus(userInitiated: true), isTrue);
    expect(backend.activations, [true, true]);
    backend.source.add(AppAudioEvent.interruptionEnded);
    backend.source.add(AppAudioEvent.resume);
    expect(events, [AppAudioEvent.pause]);
    expect(await session.acquire(audible: false), isNull);
    await audio.dispose();
    expect(session.blocksKeepAlive, isFalse);
    await sub.cancel();
  });

  test('手动申请被平台拒绝或抛错后，不解锁自动恢复和保活，可再次手动申请', () async {
    final old = (await session.acquire())!;
    backend.source.add(AppAudioEvent.pause);
    await old.release();
    backend.granted = false;
    expect(await session.acquire(userInitiated: true), isNull);
    expect(backend.activations, [true, true]);
    expect(await session.acquire(), isNull);
    expect(await session.acquire(audible: false, userInitiated: true), isNull);
    expect(session.blocksKeepAlive, isTrue);
    backend.configurationError = StateError('配置失败');
    await expectLater(session.acquire(userInitiated: true), throwsStateError);
    backend.configurationError = null;
    backend.activationError = StateError('系统激活失败');
    await expectLater(session.acquire(userInitiated: true), throwsStateError);
    backend.activationError = null;
    backend.granted = true;
    final retry = (await session.acquire(userInitiated: true))!;
    await retry.release();
    expect(session.blocksKeepAlive, isFalse);
  });

  test('手动激活期间发生新中断使申请失效，迟到结束不被误认为旧中断', () async {
    final old = (await session.acquire())!;
    backend.source.add(AppAudioEvent.pause);
    await old.release();
    backend.activationBarrier = Completer<void>();
    final request = session.acquire(userInitiated: true);
    await pumpEventQueue();
    expect(backend.activations, [true, true]);
    backend.source.add(AppAudioEvent.pause);
    backend.activationBarrier!.complete();
    expect(await request, isNull);
    expect(await session.acquire(), isNull);
    backend.source.add(AppAudioEvent.interruptionEnded);
    final retry = (await session.acquire(userInitiated: true))!;
    await retry.release();
  });

  test('结束但不建议自动恢复与耳机拔出分开传递，旧结束不会再停止新播放', () async {
    final events = <AppAudioEvent>[];
    final sub = session.events.listen(events.add);
    final old = (await session.acquire())!;
    backend.source.add(AppAudioEvent.pause);
    backend.source.add(AppAudioEvent.interruptionEnded);
    await old.release();
    final current = (await session.acquire(userInitiated: true))!;
    backend.source.add(AppAudioEvent.interruptionEnded);
    backend.source.add(AppAudioEvent.resume);
    backend.source.add(AppAudioEvent.stop);
    expect(events, [
      AppAudioEvent.pause,
      AppAudioEvent.interruptionEnded,
      AppAudioEvent.stop,
    ]);
    await current.release();
    await sub.cancel();
  });

  test('串行排队的手动请求也受新中断代次隔离，不在出队时误用旧意图', () async {
    backend.activationBarrier = Completer<void>();
    final first = session.acquire(userInitiated: true);
    await pumpEventQueue();
    final queued = session.acquire(userInitiated: true);
    backend.source.add(AppAudioEvent.pause);
    backend.activationBarrier!.complete();
    expect(await first, isNull);
    expect(await queued, isNull);
    expect(backend.activations, [true, false]);
    final current = (await session.acquire(userInitiated: true))!;
    await current.release();
  });

  test('永久失焦不让保活抢占，但允许用户明确重新播放', () async {
    final lease = (await session.acquire())!;
    backend.source.add(AppAudioEvent.loss);
    await lease.release();
    expect(await session.acquire(audible: false), isNull);
    expect(await session.acquire(), isNull);
    await (await session.acquire(userInitiated: true))!.release();
    expect(session.blocksKeepAlive, isFalse);
  });

  test('申请期间发生中断不能授予过期使用凭据', () async {
    backend.activationBarrier = Completer<void>();
    final result = session.acquire();
    await pumpEventQueue();
    backend.source.add(AppAudioEvent.pause);
    backend.activationBarrier!.complete();
    expect(await result, isNull);
    expect(await session.acquire(audible: false), isNull);
  });

  test('保活与真实播放交接不释放仍被使用的共享会话', () async {
    await session.setIgnoreAudioFocus(true);
    final web = (await session.acquire(audible: false))!;
    final main = (await session.acquire())!;
    await web.release();
    expect(backend.activations, [true, true]);
    expect(await session.acquire(audible: false), isNull);
    await main.release();
    final webAgain = (await session.acquire(audible: false))!;
    await webAgain.release();
    expect(backend.activations, [true, true, false, true, false]);
    expect(backend.policies, [false, true, false]);
  });

  test('停止期间迟到的主播放申请被释放，不保留伪激活', () async {
    final audio = AudioService.forTesting(session);
    backend.activationBarrier = Completer<void>();
    final requesting = audio.requestAudioFocus(userInitiated: true);
    await pumpEventQueue();
    await audio.abandonAudioFocus();
    backend.activationBarrier!.complete();
    expect(await requesting, isFalse);
    expect(backend.activations, [true, false]);
    expect(session.blocksKeepAlive, isFalse);
    await audio.dispose();
  });

  test('主播放与试听共存，销毁主媒体桥接不关闭试听会话', () async {
    final audio = AudioService.forTesting(session);
    expect(await audio.requestAudioFocus(), isTrue);
    final preview = (await session.acquire())!;
    await audio.dispose();
    expect(backend.activations, [true, true]);
    await preview.release();
    expect(backend.activations.last, isFalse);
  });
}

/// 插件端口替身记录真实配置和申请，不创建原生音频会话。— Codex + UI
class _PluginSession extends Fake implements AudioSession {
  final interruptions = StreamController<AudioInterruptionEvent>.broadcast(
    sync: true,
  );
  final noisy = StreamController<void>.broadcast(sync: true);
  final activations = <bool>[];
  @override
  AudioSessionConfiguration? configuration;
  @override
  Stream<AudioInterruptionEvent> get interruptionEventStream =>
      interruptions.stream;
  @override
  Stream<void> get becomingNoisyEventStream => noisy.stream;
  @override
  Future<void> configure(AudioSessionConfiguration value) async =>
      configuration = value;
  @override
  Future<bool> setActive(
    bool active, {
    AVAudioSessionSetActiveOptions? avAudioSessionSetActiveOptions,
    AndroidAudioFocusGainType? androidAudioFocusGainType,
    AndroidAudioAttributes? androidAudioAttributes,
    bool? androidWillPauseWhenDucked,
    AudioSessionConfiguration fallbackConfiguration =
        const AudioSessionConfiguration.music(),
  }) async {
    activations.add(active);
    return true;
  }

  Future<void> close() async {
    await interruptions.close();
    await noisy.close();
  }
}
