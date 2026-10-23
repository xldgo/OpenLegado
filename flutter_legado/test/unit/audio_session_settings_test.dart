import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/app/bootstrap/audio_session_settings.dart';
import 'package:flutter_legado/src/constants/pref_keys.dart';
import 'package:flutter_legado/src/data/repositories/app_read_aloud_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/platform/audio/app_audio_session.dart';

import '../fixtures/app_audio_session_backend.dart';
import '../fixtures/home_settings_storage.dart';

void main() {
  late HomeSettingsStorage preferences;
  late AppSettingsService service;
  late AppReadAloudSettingsRepository settings;
  late TestAudioSessionBackend backend;
  late AppAudioSession session;
  late AudioSessionSettingsController controller;
  setUp(() {
    preferences = HomeSettingsStorage();
    final config = HomeSettingsStorage()..values['ttsFollowSys'] = 'true';
    service = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: preferences,
        SettingsStorageKind.rustConfig: config,
      },
    );
    settings = AppReadAloudSettingsRepository(service);
    backend = TestAudioSessionBackend();
    session = AppAudioSession(backend);
    controller = AudioSessionSettingsController(settings, session);
  });
  tearDown(() async {
    await backend.source.close();
    await service.dispose();
  });

  test('启动加载不激活音频，设置保存及恢复后应用同一个偏好', () async {
    preferences.values[PrefKeys.ignoreAudioFocus] = true;
    await controller.initialize();
    expect(backend.activations, isEmpty);
    expect(settings.current.ignoreAudioFocus, isTrue);
    final lease = (await session.acquire())!;
    expect(backend.policies, [true]);
    await controller.setIgnoreAudioFocus(false);
    expect(preferences.values[PrefKeys.ignoreAudioFocus], false);
    preferences.values[PrefKeys.ignoreAudioFocus] = true;
    await controller.reload();
    expect(settings.current.ignoreAudioFocus, isTrue);
    expect(backend.policies, [true, false, true]);
    await lease.release();
  });

  test('写入失败回退设置，不应用平台策略', () async {
    await controller.initialize();
    final lease = (await session.acquire())!;
    preferences.writeFailure = true;
    await expectLater(controller.setIgnoreAudioFocus(true), throwsStateError);
    expect(settings.current.ignoreAudioFocus, isFalse);
    expect(backend.policies, [false]);
    await lease.release();
  });

  test('关闭忽略时焦点被拒绝会暂停，保存选择不回退并允许显式重试', () async {
    await controller.setIgnoreAudioFocus(true);
    final events = <AppAudioEvent>[];
    final sub = session.events.listen(events.add);
    final lease = (await session.acquire())!;
    backend.granted = false;
    await expectLater(
      controller.setIgnoreAudioFocus(false),
      throwsA(isA<AudioSessionPolicyException>()),
    );
    await pumpEventQueue();
    expect(settings.current.ignoreAudioFocus, isFalse);
    expect(events, [AppAudioEvent.stop]);
    await lease.release();
    backend.granted = true;
    final retry = (await session.acquire(userInitiated: true))!;
    expect(backend.policies.last, isFalse);
    await retry.release();
    await sub.cancel();
  });

  test('平台失败保留已保存设置并停止使用者，显式重播能按新策略重试', () async {
    await controller.initialize();
    final events = <AppAudioEvent>[];
    final sub = session.events.listen(events.add);
    final lease = (await session.acquire())!;
    backend.configurationError = StateError('平台配置被拒绝');
    await expectLater(
      controller.setIgnoreAudioFocus(true),
      throwsA(isA<AudioSessionPolicyException>()),
    );
    await pumpEventQueue();
    expect(settings.current.ignoreAudioFocus, isTrue);
    expect(events, [AppAudioEvent.stop]);
    await lease.release();
    backend.configurationError = null;
    final retry = (await session.acquire(userInitiated: true))!;
    expect(backend.policies.last, true);
    await retry.release();
    await sub.cancel();
  });
}
