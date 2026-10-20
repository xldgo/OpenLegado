import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_home_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/home_settings.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/home_settings_provider.dart';
import 'package:flutter_legado/src/features/home/application/main_prefs_notifier.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late AppHomeSettingsRepository repository;

  setUp(() {
    storage = HomeSettingsStorage();
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    repository = AppHomeSettingsRepository(service);
  });
  tearDown(() => service.dispose());

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [appSettingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('缺失偏好使用原默认值，初始化只读且并发复用', () async {
    final first = repository.load();
    expect(identical(first, repository.load()), isTrue);
    expect(await first, const HomeSettings());
    await repository.load();
    expect(storage.reads.toSet(), {
      'showDiscovery',
      'showRss',
      'defaultHomePage',
    });
    expect(storage.reads.length, 3);
    expect(storage.writes, isEmpty);
  });

  for (final page in ['home', 'bookshelf', 'explore', 'rss', 'my']) {
    test('默认页 $page 与开关保留原键、原类型并可恢复', () async {
      await repository.update(
        showDiscovery: false,
        showRss: false,
        defaultHomePage: page,
      );
      expect(storage.values, {
        'showDiscovery': false,
        'showRss': false,
        'defaultHomePage': page,
      });
      final restoredService = AppSettingsService(
        storages: {SettingsStorageKind.preferences: storage},
      );
      addTearDown(restoredService.dispose);
      expect(
        await AppHomeSettingsRepository(restoredService).load(),
        HomeSettings(
          showDiscovery: false,
          showRss: false,
          defaultHomePage: page,
        ),
      );
    });
  }

  test('错误类型使用默认展示，未知首页原值保留且不自动改写', () async {
    storage.values.addAll({
      'showDiscovery': 'false',
      'showRss': 0,
      'defaultHomePage': 'unknown',
    });
    expect(
      await repository.load(),
      const HomeSettings(defaultHomePage: 'unknown'),
    );
    expect(storage.writes, isEmpty);
  });

  test('首次选择默认值立即生效，且只保存明确选择的字段', () async {
    storage.values.addAll({
      'showDiscovery': false,
      'showRss': false,
      'defaultHomePage': 'my',
    });
    final saving = repository.update(showDiscovery: true);
    expect(repository.current.showDiscovery, isTrue);
    await saving;
    expect(
      await repository.load(),
      const HomeSettings(showRss: false, defaultHomePage: 'my'),
    );
    expect(storage.writes, [('showDiscovery', true)]);
  });

  test('初次读取晚到不能覆盖加载期间的用户修改', () async {
    storage.values.addAll({
      'showDiscovery': false,
      'showRss': false,
      'defaultHomePage': 'my',
    });
    final barrier = Completer<void>();
    storage.readBarrier = barrier;
    final loading = repository.load();
    await Future<void>.delayed(Duration.zero);
    final saving = repository.update(defaultHomePage: 'home');
    expect(repository.current.defaultHomePage, 'home');
    barrier.complete();
    await loading;
    await saving;
    expect(
      repository.current,
      const HomeSettings(
        showDiscovery: false,
        showRss: false,
        defaultHomePage: 'home',
      ),
    );
  });

  test('无关设置更新不通知主界面订阅，空差量不写入', () async {
    await repository.load();
    final events = <HomeSettings>[];
    final subscription = repository.watch().listen(events.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);
    await service.update({
      (storage: SettingsStorageKind.preferences, key: 'other'): 1,
    });
    await repository.update();
    await Future<void>.delayed(Duration.zero);
    expect(events, [const HomeSettings()]);
    expect(storage.writes, [('other', 1)]);
  });

  test('保存失败回退所有读侧并抛错，随后允许重试', () async {
    final container = createContainer();
    final notifier = container.read(mainPrefsProvider.notifier);
    await notifier.load();
    storage.writeFailure = true;
    final saving = notifier.setShowDiscovery(false);
    expect(container.read(mainPrefsProvider).showDiscovery, isFalse);
    await expectLater(saving, throwsStateError);
    expect(container.read(mainPrefsProvider).showDiscovery, isTrue);
    expect(
      container.read(homeSettingsRepositoryProvider).current.showDiscovery,
      isTrue,
    );
    storage.writeFailure = false;
    await notifier.setShowDiscovery(false);
    expect(storage.values['showDiscovery'], isFalse);
  });

  test('较早保存失败不覆盖后来选择，连续操作按顺序落盘', () async {
    final container = createContainer();
    final notifier = container.read(mainPrefsProvider.notifier);
    await notifier.load();
    final barrier = Completer<void>();
    storage.beforeWrite = (_, value) async {
      if (value == false) {
        await barrier.future;
        throw StateError('较早保存失败');
      }
    };
    final failed = expectLater(notifier.setShowRss(false), throwsStateError);
    final second = notifier.setShowRss(true);
    expect(container.read(mainPrefsProvider).showRss, isTrue);
    barrier.complete();
    await failed;
    await second;
    expect(storage.writes, [('showRss', false), ('showRss', true)]);
    expect(storage.values['showRss'], isTrue);
  });

  test('多键部分失败保留已经成功落盘的事实', () async {
    await repository.load();
    storage.beforeWrite = (key, _) async {
      if (key == 'showRss') throw StateError('第二项失败');
    };
    await expectLater(
      repository.update(
        showDiscovery: false,
        showRss: false,
        defaultHomePage: 'home',
      ),
      throwsStateError,
    );
    expect(repository.current, const HomeSettings(showDiscovery: false));
    expect(storage.values, {'showDiscovery': false});
  });

  test('读取失败不假装加载成功，重试后清除错误', () async {
    final container = createContainer();
    final notifier = container.read(mainPrefsProvider.notifier);
    storage.readFailure = true;
    await expectLater(notifier.load(), throwsStateError);
    expect(container.read(mainPrefsProvider).loaded, isFalse);
    expect(container.read(mainPrefsProvider).loadError, isA<StateError>());
    storage.readFailure = false;
    storage.values['defaultHomePage'] = 'my';
    await notifier.load();
    expect(container.read(mainPrefsProvider).loaded, isTrue);
    expect(container.read(mainPrefsProvider).loadError, isNull);
    expect(container.read(mainPrefsProvider).defaultHomePage, 'my');
  });

  test('备份恢复后显式重读已加载仓储与界面快照', () async {
    final container = createContainer();
    final notifier = container.read(mainPrefsProvider.notifier);
    await notifier.load();
    storage.values.addAll({
      'showDiscovery': false,
      'showRss': false,
      'defaultHomePage': 'home',
    });
    expect(container.read(mainPrefsProvider).showDiscovery, isTrue);
    await notifier.reload();
    expect(
      container.read(mainPrefsProvider).settings,
      const HomeSettings(
        showDiscovery: false,
        showRss: false,
        defaultHomePage: 'home',
      ),
    );
  });

  test('设置根替换后旧读取完成不能污染新快照', () async {
    final barrier = Completer<void>();
    storage.readBarrier = barrier;
    storage.values['defaultHomePage'] = 'my';
    final container = createContainer();
    final old = container.read(mainPrefsProvider.notifier).load();
    await Future<void>.delayed(Duration.zero);
    final nextStorage = HomeSettingsStorage()
      ..values['defaultHomePage'] = 'home';
    final nextService = AppSettingsService(
      storages: {SettingsStorageKind.preferences: nextStorage},
    );
    addTearDown(nextService.dispose);
    container.updateOverrides([
      appSettingsServiceProvider.overrideWithValue(nextService),
    ]);
    await container.read(mainPrefsProvider.notifier).load();
    barrier.complete();
    await old;
    expect(container.read(mainPrefsProvider).defaultHomePage, 'home');
    expect(container.read(mainPrefsProvider).loaded, isTrue);
  });

  test('释放 Provider 后迟到读取安全结束', () async {
    final barrier = Completer<void>();
    storage.readBarrier = barrier;
    final container = ProviderContainer(
      overrides: [appSettingsServiceProvider.overrideWithValue(service)],
    );
    final loading = container.read(mainPrefsProvider.notifier).load();
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    barrier.complete();
    await loading;
  });

  test('SharedPreferences 返回 false 和抛错都报告失败且回退', () async {
    final prefs = _Preferences();
    when(() => prefs.get(any())).thenReturn(null);
    when(() => prefs.setBool(any(), any())).thenAnswer((_) async => false);
    final checkedService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(
          preferences: () async => prefs,
        ),
      },
    );
    addTearDown(checkedService.dispose);
    final checked = AppHomeSettingsRepository(checkedService);
    await expectLater(checked.update(showDiscovery: false), throwsStateError);
    expect(checked.current.showDiscovery, isTrue);
    when(() => prefs.setBool(any(), any())).thenThrow(StateError('插件失败'));
    await expectLater(checked.update(showDiscovery: false), throwsStateError);
    expect(checked.current.showDiscovery, isTrue);
  });
}

class _Preferences extends Mock implements SharedPreferences {}
