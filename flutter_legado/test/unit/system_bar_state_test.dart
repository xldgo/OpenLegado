import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/constants/pref_keys.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/theme/system_bar_notifier.dart';
import 'package:flutter_legado/src/services/settings_service.dart';

class DelayedSystemBarSettings extends SettingsService {
  DelayedSystemBarSettings([Map<String, bool> initial = const {}])
    : saved = {...initial};

  final Map<String, bool> saved;
  final List<(String, bool)> writes = [];
  Completer<void>? readGate;
  Completer<void>? writeGate;
  int reads = 0;
  bool failNextWrite = false;

  @override
  Future<bool> getBoolPref(String key, {required bool defaultValue}) async {
    reads++;
    final snapshot = saved[key] ?? defaultValue;
    await readGate?.future;
    return snapshot;
  }

  @override
  Future<void> setBoolPref(String key, bool value) async {
    writes.add((key, value));
    if (writes.length == 1) await writeGate?.future;
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('模拟系统栏保存失败');
    }
    saved[key] = value;
  }
}

Future<void> flushOperations() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

ProviderContainer createContainer(DelayedSystemBarSettings settings) =>
    ProviderContainer(
      overrides: [settingsProvider.overrideWithValue(settings)],
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

  test('较新的重新加载发起后，旧加载不能发布中间状态', () async {
    final settings = DelayedSystemBarSettings({
      PrefKeys.transparentStatusBar: false,
      PrefKeys.immNavigationBar: false,
    })..readGate = Completer<void>();
    final container = createContainer(settings);
    addTearDown(container.dispose);
    final loadedStates = <SystemBarState>[];
    container.listen(systemBarProvider, (_, next) {
      if (next.loaded) loadedStates.add(next);
    });
    await flushOperations();
    final oldGate = settings.readGate!;
    settings.saved[PrefKeys.transparentStatusBar] = true;
    settings.saved[PrefKeys.immNavigationBar] = true;
    settings.readGate = Completer<void>();
    final reload = container.read(systemBarProvider.notifier).reload();
    oldGate.complete();
    await flushOperations();
    final statesBeforeNewLoad = [...loadedStates];
    settings.readGate!.complete();
    await reload;
    expect(statesBeforeNewLoad, isEmpty);
    expect(loadedStates, hasLength(1));
    expect(loadedStates.single.transparentStatusBar, isTrue);
    expect(loadedStates.single.immNavigationBar, isTrue);
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
      settingsProvider.overrideWithValue(newSettings),
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

  test('保存抛错后保留最新界面状态，后续保存仍可继续', () async {
    final settings = DelayedSystemBarSettings();
    final container = createContainer(settings);
    addTearDown(container.dispose);
    final notifier = container.read(systemBarProvider.notifier);
    await flushOperations();
    settings.failNextWrite = true;
    await expectLater(notifier.setImmNavigationBar(false), throwsStateError);
    expect(container.read(systemBarProvider).immNavigationBar, isFalse);
    await notifier.setImmNavigationBar(true);
    expect(container.read(systemBarProvider).immNavigationBar, isTrue);
    expect(settings.saved[PrefKeys.immNavigationBar], isTrue);
  });
}
