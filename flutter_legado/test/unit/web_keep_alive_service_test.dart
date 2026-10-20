import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/platform/audio/app_audio_session.dart';
import 'package:flutter_legado/src/services/web_keep_alive_service.dart';

import '../fixtures/app_audio_session_backend.dart';

void main() {
  late TestAudioSessionBackend backend;
  late AppAudioSession session;
  late WebKeepAliveService service;
  late List<bool> calls;
  late bool platformResult;
  Completer<void>? startBarrier;
  Object? failure;
  setUp(() {
    backend = TestAudioSessionBackend();
    session = AppAudioSession(backend);
    calls = [];
    platformResult = true;
    startBarrier = null;
    failure = null;
    service = WebKeepAliveService(
      audioSession: session,
      isIOS: () => true,
      setEnabled: (enabled) async {
        calls.add(enabled);
        if (enabled) await startBarrier?.future;
        if (failure case final error?) throw error;
        return platformResult;
      },
    );
  });
  tearDown(() async {
    failure = null;
    await service.stop();
    await backend.source.close();
  });

  test('非 iOS 不获取共享会话也不调用保活通道', () async {
    service = WebKeepAliveService(audioSession: session, isIOS: () => false);
    expect(await service.start(), WebKeepAliveStatus.notApplicable);
    expect(await service.stop(), WebKeepAliveStatus.notApplicable);
    expect(backend.activations, isEmpty);
  });

  test('启动停止幂等，平台音轨停止后才释放使用凭据', () async {
    expect(await service.start(), WebKeepAliveStatus.active);
    await service.start();
    expect(calls, [true]);
    expect(backend.activations, [true]);
    expect(await service.stop(), WebKeepAliveStatus.idle);
    await service.stop();
    expect(calls, [true, false]);
    expect(backend.activations, [true, false]);
  });

  test('正文或试听持有期间让位；最后一个释放后恢复保活', () async {
    await service.start();
    final main = (await session.acquire())!;
    await pumpEventQueue();
    expect(service.status, WebKeepAliveStatus.deferredByRealAudio);
    expect(calls, [true, false]);
    expect(backend.activations, [true, true]);
    final preview = (await session.acquire())!;
    await main.release();
    await pumpEventQueue();
    expect(service.isActive, isFalse);
    await preview.release();
    await pumpEventQueue();
    expect(service.status, WebKeepAliveStatus.active);
    expect(calls, [true, false, true]);
  });

  test('中断期间不抢占会话，中断结束仅恢复保活', () async {
    await service.start();
    backend.source.add(AppAudioEvent.pause);
    await pumpEventQueue();
    expect(service.isActive, isFalse);
    expect(backend.activations, [true]);
    await service.start();
    expect(calls, [true, false]);
    backend.source.add(AppAudioEvent.resume);
    await pumpEventQueue();
    expect(service.isActive, isTrue);
    expect(calls, [true, false, true]);
  });

  test('异步启动期间停止，不留下迟到的保活音轨', () async {
    startBarrier = Completer<void>();
    final starting = service.start();
    await pumpEventQueue();
    final stopping = service.stop();
    startBarrier!.complete();
    await starting;
    expect(await stopping, WebKeepAliveStatus.idle);
    expect(service.isActive, isFalse);
    expect(calls, [true, false]);
    expect(backend.activations, [true, false]);
  });

  test('平台拒绝或激活失败都不残留使用凭据，可显式重试', () async {
    platformResult = false;
    expect(await service.start(), WebKeepAliveStatus.failed);
    expect(backend.activations, [true, false]);
    platformResult = true;
    backend.granted = false;
    expect(await service.start(), WebKeepAliveStatus.deferredByRealAudio);
    backend.granted = true;
    expect(await service.start(), WebKeepAliveStatus.active);
  });

  for (final error in [
    MissingPluginException(),
    PlatformException(code: '失败'),
  ]) {
    test('平台异常不阻断 Web 服务并释放共享会话：${error.runtimeType}', () async {
      failure = error;
      expect(await service.start(), WebKeepAliveStatus.failed);
      expect(service.isActive, isFalse);
      expect(backend.activations, [true, false]);
    });
  }
}
