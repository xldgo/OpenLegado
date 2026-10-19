import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/constants/pref_keys.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/contracts/settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/theme/system_bar_notifier.dart';

class DelayedSystemBarSettings implements SettingsStorage {
  DelayedSystemBarSettings([Map<String, bool> initial = const {}])
    : saved = {...initial};

  final Map<String, bool> saved;
  final List<(String, bool)> writes = [];
  Completer<void>? readGate;
  Completer<void>? writeGate;
  int reads = 0;
  bool failNextWrite = false;

  @override
  Future<Object?> read(String key) async {
    reads++;
    final snapshot = saved[key];
    await readGate?.future;
    return snapshot;
  }

  @override
  Future<void> write(String key, Object? value) async {
    final boolValue = value as bool;
    writes.add((key, boolValue));
    if (writes.length == 1) await writeGate?.future;
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('模拟系统栏保存失败');
    }
    saved[key] = boolValue;
  }
}

Future<void> flushOperations() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

AppSettingsService createService(DelayedSystemBarSettings settings) {
  final service = AppSettingsService(
    storages: {SettingsStorageKind.preferences: settings},
  );
  addTearDown(service.dispose);
  return service;
}

ProviderContainer createContainer(DelayedSystemBarSettings settings) =>
    ProviderContainer(
      overrides: [
        appSettingsServiceProvider.overrideWithValue(createService(settings)),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('默认值及已有偏好继续通过共享设置服务恢复', () async {
    final settings = DelayedSystemBarSettings({
      PrefKeys.transparentStatusBar: false,
    });
    final container = createContainer(settings);
    addTearDown(container.dispose);
    expect(container.read(systemBarProvider).loaded, isFalse);
    await flushOperations();
    final state = container.read(systemBarProvider);
    expect(state.loaded, isTrue);
    expect(state.transparentStatusBar, isFalse);
    expect(state.immNavigationBar, isTrue);
  });

  test('启动恢复保留显式选择的默认值，同时恢复未修改字段', () async {
    final settings = DelayedSystemBarSettings({
      PrefKeys.transparentStatusBar: false,
      PrefKeys.immNavigationBar: false,
    })..readGate = Completer<void>();
    final container = createContainer(settings);
    addTearDown(container.dispose);
    final notifier = container.read(systemBarProvider.notifier);
    await flushOperations();
    final save = notifier.setTransparentStatusBar(true);
    settings.readGate!.complete();
    await save;
    await flushOperations();
    final state = container.read(systemBarProvider);
    expect(state.loaded, isTrue);
    expect(state.transparentStatusBar, isTrue);
    expect(state.immNavigationBar, isFalse);
    expect(settings.saved[PrefKeys.transparentStatusBar], isTrue);
  });

  test('连续切换立即更新界面，慢写入不会覆盖最后一次操作', () async {
    final settings = DelayedSystemBarSettings();
    final container = createContainer(settings);
    addTearDown(container.dispose);
    final notifier = container.read(systemBarProvider.notifier);
    await flushOperations();
    settings.writeGate = Completer<void>();
    final first = notifier.setImmNavigationBar(false);
    final firstVisible = container.read(systemBarProvider).immNavigationBar;
    await flushOperations();
    final second = notifier.setImmNavigationBar(true);
    await flushOperations();
    final pendingWrites = [...settings.writes];
    final lastVisible = container.read(systemBarProvider).immNavigationBar;
    settings.writeGate!.complete();
    await Future.wait([first, second]);
    expect(firstVisible, isFalse);
    expect(lastVisible, isTrue);
    expect(pendingWrites, [(PrefKeys.immNavigationBar, false)]);
    expect(container.read(systemBarProvider).immNavigationBar, isTrue);
    expect(settings.saved[PrefKeys.immNavigationBar], isTrue);
  });

  test('重新加载等待已提交写入，避免读回旧偏好', () async {
    final settings = DelayedSystemBarSettings({
      PrefKeys.transparentStatusBar: false,
    });
    final container = createContainer(settings);
    addTearDown(container.dispose);
    final notifier = container.read(systemBarProvider.notifier);
    await flushOperations();
    final readsBeforeSave = settings.reads;
    settings.writeGate = Completer<void>();
    final save = notifier.setTransparentStatusBar(true);
    await flushOperations();
    final reload = notifier.reload();
    await flushOperations();
    final pendingReads = settings.reads;
    final pendingVisible = container
        .read(systemBarProvider)
        .transparentStatusBar;
    settings.writeGate!.complete();
    await Future.wait([save, reload]);
    expect(pendingReads, readsBeforeSave);
    expect(pendingVisible, isTrue);
    expect(container.read(systemBarProvider).transparentStatusBar, isTrue);
  });

  test('销毁作用域后完成加载不会更新已释放状态', () async {
    final settings = DelayedSystemBarSettings()..readGate = Completer<void>();
    final container = createContainer(settings);
    final notifier = container.read(systemBarProvider.notifier);
    await flushOperations();
    final reload = notifier.reload();
    container.dispose();
    settings.readGate!.complete();
    await reload;
    await flushOperations();
  });

  test('恢复沉浸开关后重读，共享快照与页面投影一致', () async {
    final settings = DelayedSystemBarSettings({
      PrefKeys.transparentStatusBar: false,
      PrefKeys.immNavigationBar: false,
    });
    final container = createContainer(settings);
    addTearDown(container.dispose);
    container.read(systemBarProvider);
    await flushOperations();
    settings.saved[PrefKeys.transparentStatusBar] = true;
    settings.saved[PrefKeys.immNavigationBar] = true;
    await container.read(systemBarProvider.notifier).reload();
    final state = container.read(systemBarProvider);
    expect(state.loaded, isTrue);
    expect(state.transparentStatusBar, isTrue);
    expect(state.immNavigationBar, isTrue);
  });

  test('替换共享设置服务后旧加载不会短暂发布过期状态', () async {
    final oldSettings = DelayedSystemBarSettings({
      PrefKeys.transparentStatusBar: false,
      PrefKeys.immNavigationBar: false,
    })..readGate = Completer<void>();
    final newSettings = DelayedSystemBarSettings();
    final container = createContainer(oldSettings);
    addTearDown(container.dispose);
    final loadedStates = <SystemBarState>[];
    container.listen(systemBarProvider, (_, next) {
      if (next.loaded) loadedStates.add(next);
    });
    await flushOperations();
    container.updateOverrides([
      appSettingsServiceProvider.overrideWithValue(createService(newSettings)),
    ]);
    container.read(systemBarProvider);
    await flushOperations();
    oldSettings.readGate!.complete();
    await flushOperations();
    expect(loadedStates, isNotEmpty);
    expect(
      loadedStates.every((s) => s.transparentStatusBar && s.immNavigationBar),
      isTrue,
    );
  });

  test('保存抛错后回退已保存值，重试仍可继续', () async {
    final settings = DelayedSystemBarSettings();
    final container = createContainer(settings);
    addTearDown(container.dispose);
    final notifier = container.read(systemBarProvider.notifier);
    await flushOperations();
    settings.failNextWrite = true;
    await expectLater(notifier.setImmNavigationBar(false), throwsStateError);
    expect(container.read(systemBarProvider).immNavigationBar, isTrue);
    await notifier.setImmNavigationBar(false);
    expect(container.read(systemBarProvider).immNavigationBar, isFalse);
    expect(settings.saved[PrefKeys.immNavigationBar], isFalse);
  });
}
