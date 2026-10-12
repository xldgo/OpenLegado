import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/providers/audio/read_aloud_preferences.dart';
import 'package:flutter_legado/src/providers/providers.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockRustApi api;
  late ProviderContainer container;
  late Map<String, String> saved;
  ReadAloudPreferencesNotifier notifier() =>
      container.read(readAloudPreferencesProvider.notifier);
  ReadAloudPreferences state() => container.read(readAloudPreferencesProvider);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    saved = {};
    api = MockRustApi();
    when(() => api.getConfig(any()))
        .thenAnswer((call) async => saved[call.positionalArguments.first]);
    when(() => api.setConfig(any(), any())).thenAnswer((call) async {
      saved[call.positionalArguments[0] as String] =
          call.positionalArguments[1] as String;
    });
    container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
  });

  test('跟随模式切换保留手动语速，重建容器恢复偏好', () async {
    saved.addAll({
      'ttsFollowSys': 'false',
      'ttsSpeechRate': '10',
      'ttsParagraphInterval': '300',
    });
    await notifier().load();
    expect(state().effectiveSpeed, 1.5);
    await notifier().setFollowSystem(true);
    expect(state().effectiveSpeed, 1);
    await notifier().setManualSpeed(1.8);
    expect(state().effectiveSpeed, 1);
    await notifier().setFollowSystem(false);
    expect(state().effectiveSpeed, 1.8);
    final restored = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(restored.dispose);
    await restored.read(readAloudPreferencesProvider.notifier).load();
    expect(restored.read(readAloudPreferencesProvider).effectiveSpeed, 1.8);
    expect(
      restored.read(readAloudPreferencesProvider).paragraphIntervalMs,
      300,
    );
  });

  test('保存失败保留旧值，重试成功后才更新状态', () async {
    await notifier().load();
    when(() => api.setConfig('ttsParagraphInterval', '500'))
        .thenThrow(StateError('保存失败'));
    await expectLater(notifier().setParagraphInterval(500), throwsStateError);
    expect(state().paragraphIntervalMs, 0);
    when(() => api.setConfig('ttsParagraphInterval', '500'))
        .thenAnswer((_) async {});
    await notifier().setParagraphInterval(500);
    expect(state().paragraphIntervalMs, 500);
  });

  test('连续设置串行保存，慢写入不会覆盖后一个选择', () async {
    await notifier().load();
    final pending = Completer<void>();
    when(() => api.setConfig('ttsSpeechRate', '10'))
        .thenAnswer((_) => pending.future);
    final first = notifier().setManualSpeed(1.5);
    final second = notifier().setManualSpeed(2);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => api.setConfig('ttsSpeechRate', '15'));
    pending.complete();
    await Future.wait([first, second]);
    expect(state().manualSpeed, 2);
    verify(() => api.setConfig('ttsSpeechRate', '15')).called(1);
  });

  test('旧跟随偏好迁移，重复打开不重复写配置', () async {
    SharedPreferences.setMockInitialValues({
      'read_aloud_follow_system_speed': false,
    });
    await notifier().load();
    expect(state().followSystem, false);
    expect(saved['ttsFollowSys'], 'false');
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        'read_aloud_follow_system_speed',
      ),
      false,
    );
    await notifier().load();
    verify(() => api.setConfig('ttsFollowSys', 'false')).called(1);
  });
}
