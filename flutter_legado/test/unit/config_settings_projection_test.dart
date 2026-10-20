import 'package:flutter_legado/src/data/repositories/app_request_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_cache_download_settings_repository.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/app/bootstrap/app_settings_factory.dart';
import 'package:flutter_legado/src/data/repositories/mock_config_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_audio_playback_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_manga_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_change_source_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_service_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_search_settings_repository.dart';
import 'package:flutter_legado/src/domain/models/manga_settings.dart';
import 'package:flutter_legado/src/domain/models/change_source_settings.dart';

import '../fixtures/config_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Web自动启动默认关闭，仅保存启动意图并能跨装配读取', () async {
    SharedPreferences.setMockInitialValues({});
    final config = MockConfigRepository();
    final service = createAppSettingsService(configRepository: () => config);
    addTearDown(service.dispose);
    final repository = AppServiceSettingsRepository(service);
    expect((await repository.load()).webAutoStart, isFalse);
    await repository.update((s) => s.copyWith(webAutoStart: true));
    expect(await config.getConfig('webServiceAutoStart'), 'true');
    final rebuilt = createAppSettingsService(configRepository: () => config);
    addTearDown(rebuilt.dispose);
    expect(
      (await AppServiceSettingsRepository(rebuilt).load()).webAutoStart,
      isTrue,
    );
  });

  test('Web自动启动保存失败回退，不伪装保存成功', () async {
    SharedPreferences.setMockInitialValues({});
    final config = TestConfigRepository(
      read: (_) async => null,
      write: (_, _) async => throw StateError('无法保存'),
    );
    final service = createAppSettingsService(configRepository: () => config);
    addTearDown(service.dispose);
    final repository = AppServiceSettingsRepository(service);
    await repository.load();
    await expectLater(
      repository.update((s) => s.copyWith(webAutoStart: true)),
      throwsStateError,
    );
    expect(repository.current.webAutoStart, isFalse);
  });

  test('离线下载并发独立存Rust配置并在重新装配后读取，范围与Rust一致', () async {
    SharedPreferences.setMockInitialValues({
      'preDownloadNum': 12,
      'cacheBookThreadCount': 99,
    });
    final config = MockConfigRepository(
      values: {'threadCount': '23', 'cacheBookThreadCount': '2'},
    );
    final service = createAppSettingsService(configRepository: () => config);
    addTearDown(service.dispose);
    final repository = AppCacheDownloadSettingsRepository(service);
    expect((await repository.load()).threadCount, 2);
    await repository.update((s) => s.copyWith(threadCount: 1));
    expect(await config.getConfig('cacheBookThreadCount'), '1');
    await repository.update((s) => s.copyWith(threadCount: 8));
    expect(await config.getConfig('threadCount'), '23');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('preDownloadNum'), 12);
    expect(prefs.getInt('cacheBookThreadCount'), 99);
    final rebuilt = createAppSettingsService(configRepository: () => config);
    addTearDown(rebuilt.dispose);
    expect(
      (await AppCacheDownloadSettingsRepository(rebuilt).load()).threadCount,
      8,
    );
    for (final count in [0, 9]) {
      await expectLater(
        repository.update((s) => s.copyWith(threadCount: count)),
        throwsRangeError,
      );
    }
    for (final value in ['0', '-1', '9', '16', 'bad', '0x2', '']) {
      await config.setConfig('cacheBookThreadCount', value);
      await repository.reload();
      expect(repository.current.threadCount, 8);
    }
  });
  test('并发只存Rust配置，忽略未接线的SP旧值并拒绝越界写入', () async {
    SharedPreferences.setMockInitialValues({'threadCount': 99});
    final config = MockConfigRepository(values: {'threadCount': '3'});
    final service = createAppSettingsService(configRepository: () => config);
    addTearDown(service.dispose);
    final repository = AppRequestSettingsRepository(service);
    expect((await repository.load()).threadCount, 3);
    await repository.update((s) => s.copyWith(threadCount: 7));
    expect(await config.getConfig('threadCount'), '7');
    expect((await SharedPreferences.getInstance()).getInt('threadCount'), 99);
    await expectLater(
      repository.update((s) => s.copyWith(threadCount: 257)),
      throwsRangeError,
    );
    expect(await config.getConfig('threadCount'), '7');
    final restored = createAppSettingsService(configRepository: () => config);
    addTearDown(restored.dispose);
    expect(
      (await AppRequestSettingsRepository(restored).load()).threadCount,
      7,
    );
    for (final value in ['0', '-1', '257', 'bad', '0x20', '']) {
      await config.setConfig('threadCount', value);
      await repository.reload();
      expect(repository.current.threadCount, 16);
    }
  });
  test('并发写入失败回退，重试可保存；读取失败不能伪装默认值', () async {
    var failRead = false, failWrite = true;
    var stored = '2';
    final config = TestConfigRepository(
      read: (key) async {
        if (failRead) throw StateError('读取失败');
        return stored;
      },
      write: (key, value) async {
        if (failWrite) throw StateError('写入失败');
        stored = value;
      },
    );
    final service = createAppSettingsService(configRepository: () => config);
    addTearDown(service.dispose);
    final repository = AppRequestSettingsRepository(service);
    await repository.load();
    await expectLater(
      repository.update((s) => s.copyWith(threadCount: 8)),
      throwsStateError,
    );
    expect(repository.current.threadCount, 2);
    failWrite = false;
    await repository.update((s) => s.copyWith(threadCount: 8));
    expect(stored, '8');
    failRead = true;
    await expectLater(repository.reload(), throwsStateError);
    expect(repository.current.threadCount, 8);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('同一设置服务同步播放仓储，重新装配仍读取持久化结果', () async {
    final config = MockConfigRepository();
    final service = createAppSettingsService(configRepository: () => config);
    addTearDown(service.dispose);
    final first = AppAudioPlaybackSettingsRepository(service),
        second = AppAudioPlaybackSettingsRepository(service);
    expect((await first.load()).wakeLock, isFalse);
    final stream = StreamIterator(second.watch());
    addTearDown(stream.cancel);
    await stream.moveNext();
    final saved = first.update(
      (s) => s.copyWith(wakeLock: true, openCredits: 15, closeCredits: 8),
    );
    await saved;
    expect(second.current.openCredits, 15);
    expect(second.current.wakeLock, isTrue);
    await stream.moveNext();
    expect(stream.current.wakeLock, isTrue);
    final nextService = createAppSettingsService(
      configRepository: () => config,
    );
    addTearDown(nextService.dispose);
    final restored = await AppAudioPlaybackSettingsRepository(nextService)
        .load();
    expect(restored.openCredits, 15);
    expect(restored.closeCredits, 8);
  });
  test('设置写入失败撤销待保存值，保留已成功键并继续后续写入', () async {
    final map = <String, String>{'audioSkipOpenCredits': '3'};
    var fail = true;
    final config = TestConfigRepository(
      read: (key) async => map[key],
      write: (key, value) async {
        if (key == 'audioSkipCloseCredits' && fail) throw StateError('无法保存');
        map[key] = value;
      },
    );
    final service = createAppSettingsService(configRepository: () => config);
    addTearDown(service.dispose);
    final repository = AppAudioPlaybackSettingsRepository(service);
    await repository.load();
    await expectLater(
      repository.update((s) => s.copyWith(openCredits: 10, closeCredits: 5)),
      throwsStateError,
    );
    expect(repository.current.openCredits, 10);
    expect(repository.current.closeCredits, 0);
    fail = false;
    await repository.update((s) => s.copyWith(closeCredits: 7));
    expect(repository.current.closeCredits, 7);
  });
  test('漫画缺省、翻页范围及行为开关只影响所属配置', () async {
    final config = MockConfigRepository(
      values: {
        'mangaScrollMode': '99',
        'mangaSidePadding': '100',
        'mangaAutoReadSpeed': '0',
      },
    );
    final service = createAppSettingsService(configRepository: () => config);
    addTearDown(service.dispose);
    final repository = AppMangaSettingsRepository(service);
    final value = await repository.load();
    expect(value.scrollMode, 4);
    expect(value.sidePadding, 45);
    expect(value.autoReadSpeed, 1);
    expect(value.disableMangaScale, isTrue);
    expect(value.volumeKeyPage, isTrue);
    expect(value.longClickSaveImage, isTrue);
    await repository.update(
      (s) => s
          .withToggle(MangaToggle.volumeKeyPage, false)
          .copyWith(sidePadding: 8),
    );
    expect(repository.current.volumeKeyPage, isFalse);
    expect(repository.current.sidePadding, 8);
    expect(await config.getConfig('volumeKeyPage'), 'false');
    expect(await config.getConfig('mangaSidePadding'), '8');
    expect(await config.getConfig('audioPlayWakeLock'), isNull);
  });
  test('换源选项和搜索分组各有唯一投影；引擎外部写入后显式刷新', () async {
    final config = MockConfigRepository();
    final service = createAppSettingsService(configRepository: () => config);
    addTearDown(service.dispose);
    final change = AppChangeSourceSettingsRepository(service),
        server = AppServiceSettingsRepository(service);
    await change.update((s) => s.withOption(ChangeSourceOption.loadToc, true));
    expect(change.current.loadToc, isTrue);
    expect(change.current.checkAuthor, isFalse);
    final search = AppSearchSettingsRepository(service);
    await search.load();
    await search.update((s) => s.copyWith(searchGroup: '小说'));
    expect(search.current.searchGroup, '小说');
    await server.load();
    await config.setConfig('mcpPort', '1236');
    expect(server.current.mcpPort, 0);
    await server.reload();
    expect(server.current.mcpPort, 1236);
    await server.update((s) => s.copyWith(autoTaskEnabled: true));
    expect(await config.getConfig('autoTaskService'), 'true');
  });
}
