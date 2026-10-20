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
      AppAudioEvent.stop,
    );
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

  test('永久失焦不让保活抢占，但允许用户明确重新播放', () async {
    final lease = (await session.acquire())!;
    backend.source.add(AppAudioEvent.loss);
    await lease.release();
    expect(await session.acquire(audible: false), isNull);
    await (await session.acquire())!.release();
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
    final web = (await session.acquire(audible: false))!;
    final main = (await session.acquire())!;
    await web.release();
    expect(backend.activations, [true, true]);
    expect(await session.acquire(audible: false), isNull);
    await main.release();
    final webAgain = (await session.acquire(audible: false))!;
    await webAgain.release();
    expect(backend.activations, [true, true, false, true, false]);
  });

  test('停止期间迟到的主播放申请被释放，不保留伪激活', () async {
    final audio = AudioService.forTesting(session);
    backend.activationBarrier = Completer<void>();
    final requesting = audio.requestAudioFocus();
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
