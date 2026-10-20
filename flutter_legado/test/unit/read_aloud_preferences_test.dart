import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/domain/models/read_aloud_content.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/features/audio/application/read_aloud_preferences.dart';

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
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((call) async => saved[call.positionalArguments.first]);
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((call) async {
          saved[call.positionalArguments[0] as String] =
              call.positionalArguments[1] as String;
        });
    container = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(container.dispose);
  });

  test('预下载默认3章，偏好持久化后重建恢复', () async {
    expect(state().audioPreDownloadNum, 3);
    await notifier().load();
    expect(state().audioPreDownloadNum, 3);
    expect(state().ttsPreSynthesisConcurrency, 3);
    expect(state().audioCacheCleanTime, 10);
    await notifier().setAudioPreDownloadNum(0);
    await notifier().setTtsPreSynthesisConcurrency(8);
    await notifier().setAudioCacheCleanTime(0);
    final restored = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(restored.dispose);
    await restored.read(readAloudPreferencesProvider.notifier).load();
    final value = restored.read(readAloudPreferencesProvider);
    expect(value.audioPreDownloadNum, 0);
    expect(value.ttsPreSynthesisConcurrency, 8);
    expect(value.audioCacheCleanTime, 0);
  });

  test('朗读脱离提醒默认启用，关闭后可从持久化配置恢复', () async {
    await notifier().load();
    expect(state().detachReminder, true);
    await notifier().setDetachReminder(false);
    expect(saved['readAloudDetachReminderEnabled'], 'false');
    final restored = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(restored.dispose);
    await restored.read(readAloudPreferencesProvider.notifier).load();
    expect(restored.read(readAloudPreferencesProvider).detachReminder, false);
  });

  test('媒体按钮默认切章，切段保存和失败回退均来自同一设置仓库', () async {
    await notifier().load();
    expect(state().mediaButtonPerNext, isTrue);
    await notifier().setMediaButtonPerNext(false);
    expect(saved['mediaButtonPerNext'], 'false');
    final restored = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(restored.dispose);
    await restored.read(readAloudPreferencesProvider.notifier).load();
    expect(
      restored.read(readAloudPreferencesProvider).mediaButtonPerNext,
      isFalse,
    );
    when(() => api.configRepository.setConfig('mediaButtonPerNext', 'true'))
        .thenThrow(StateError('保存失败'));
    await expectLater(notifier().setMediaButtonPerNext(true), throwsStateError);
    expect(state().mediaButtonPerNext, isFalse);
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
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(restored.dispose);
    await restored.read(readAloudPreferencesProvider.notifier).load();
    expect(restored.read(readAloudPreferencesProvider).effectiveSpeed, 1.8);
    expect(
      restored.read(readAloudPreferencesProvider).paragraphIntervalMs,
      300,
    );
  });

  test('读取已保存值时统一应用朗读偏好范围', () async {
    saved.addAll({
      'ttsSpeechRate': '99',
      'ttsParagraphInterval': '-10',
      'audioPreDownloadNum': '999',
      'ttsPreSynthesisConcurrency': '0',
      'audioCacheCleanTime': '9999',
    });
    await notifier().load();
    expect(state().manualSpeed, 3);
    expect(state().paragraphIntervalMs, 0);
    expect(state().audioPreDownloadNum, 100);
    expect(state().ttsPreSynthesisConcurrency, 1);
    expect(state().audioCacheCleanTime, 1440);
  });

  test('首次保存标准手动语速也要落盘，重建后不能误判为尚未设置', () async {
    await notifier().load();
    expect(state().manualSpeed, 1);
    expect(state().hasStoredManualSpeed, false);

    await notifier().setManualSpeed(1);
    expect(saved['ttsSpeechRate'], '5');
    expect(state().hasStoredManualSpeed, true);

    final restored = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(restored.dispose);
    await restored.read(readAloudPreferencesProvider.notifier).load();
    expect(restored.read(readAloudPreferencesProvider).manualSpeed, 1);
    expect(
      restored.read(readAloudPreferencesProvider).hasStoredManualSpeed,
      true,
    );
  });

  test('保存失败保留旧值，重试成功后才更新状态', () async {
    await notifier().load();
    when(() => api.configRepository.setConfig('ttsParagraphInterval', '500'))
        .thenThrow(StateError('保存失败'));
    await expectLater(notifier().setParagraphInterval(500), throwsStateError);
    expect(state().paragraphIntervalMs, 0);
    when(() => api.configRepository.setConfig('ttsParagraphInterval', '500'))
        .thenAnswer((_) async {});
    await notifier().setParagraphInterval(500);
    expect(state().paragraphIntervalMs, 500);
  });

  test('连续设置串行保存，慢写入不会覆盖后一个选择', () async {
    await notifier().load();
    final pending = Completer<void>();
    when(() => api.configRepository.setConfig('ttsSpeechRate', '10'))
        .thenAnswer((_) => pending.future);
    final first = notifier().setManualSpeed(1.5);
    final second = notifier().setManualSpeed(2);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => api.configRepository.setConfig('ttsSpeechRate', '15'));
    pending.complete();
    await Future.wait([first, second]);
    expect(state().manualSpeed, 2);
    verify(() => api.configRepository.setConfig('ttsSpeechRate', '15'))
        .called(1);
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
    verify(() => api.configRepository.setConfig('ttsFollowSys', 'false'))
        .called(1);
  });

  test('旧跟随偏好迁移失败后可重试，不能提前删除旧键', () async {
    SharedPreferences.setMockInitialValues({
      'read_aloud_follow_system_speed': false,
    });
    var failed = true;
    when(() => api.configRepository.setConfig('ttsFollowSys', 'false'))
        .thenAnswer((_) async {
          if (failed) {
            failed = false;
            throw StateError('迁移写入失败');
          }
          saved['ttsFollowSys'] = 'false';
        });

    await expectLater(notifier().load(), throwsStateError);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'read_aloud_follow_system_speed',
      ),
      false,
    );
    await notifier().load();
    expect(state().followSystem, false);
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        'read_aloud_follow_system_speed',
      ),
      false,
    );
  });
  test('划分策略存储与重读同源，保存失败保持旧快照并能重试', () async {
    await notifier().load();
    await notifier().setContentSplit(ReadAloudSplitMode.symbols, '。？！');
    expect(saved['contentSplitMode'], 'symbols');
    expect(state().splitMode, ReadAloudSplitMode.symbols);
    expect(state().splitSymbols.split(''), unorderedEquals('。？！'.split('')));
    when(() => api.configRepository.setConfig('contentSplitMode', 'page'))
        .thenThrow(StateError('划分保存失败'));
    await expectLater(
      notifier().setContentSplit(ReadAloudSplitMode.page, '。？！'),
      throwsStateError,
    );
    expect(state().splitMode, ReadAloudSplitMode.symbols);
    when(() => api.configRepository.setConfig('contentSplitMode', 'page'))
        .thenAnswer((_) async {
          saved['contentSplitMode'] = 'page';
        });
    await notifier().setContentSplit(ReadAloudSplitMode.page, '。？！');
    container.dispose();
    container = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    await notifier().load();
    expect(state().splitMode, ReadAloudSplitMode.page);
  });
}
