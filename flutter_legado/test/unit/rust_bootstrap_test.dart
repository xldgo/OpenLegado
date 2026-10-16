import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/data/bridge/runtime_configuration.dart';
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';
import 'package:flutter_legado/src/providers/reader/reader_notifier.dart';
import 'package:flutter_legado/src/app/bootstrap/app_settings_factory.dart';
import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/data/repositories/app_appearance_settings_repository.dart';
import 'package:flutter_legado/src/features/appearance/appearance_settings_provider.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/theme/theme_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('主题注入串行执行，较早请求的模式不能在较新请求后回写', () async {
    final fixture = _Fixture();
    final barrier = Completer<void>();
    fixture.runtime.themeBarrier = barrier.future;
    final first = fixture.bootstrap.configurationSync.synchronizeThemeConfig();
    await Future<void>.delayed(Duration.zero);
    final second = fixture.bootstrap.configurationSync.synchronizeThemeConfig();
    await Future<void>.delayed(Duration.zero);
    expect(fixture.calls, ['read_theme', 'theme']);
    barrier.complete();
    await Future.wait([first, second]);
    expect(fixture.calls, [
      'read_theme',
      'theme',
      'read_mode',
      'mode',
      'read_theme',
      'theme',
      'read_mode',
      'mode',
    ]);
  });

  test('正式装配共享启动与 UI 偏好，主题切换不访问配置表或重开数据库', () async {
    SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
    final settings = createAppSettingsService(
      configRepository: () => throw StateError('不应访问 Rust 配置表'),
    );
    addTearDown(settings.dispose);
    final fixture = _Fixture();
    final bootstrap = RustBootstrap(
      runtime: fixture.runtime,
      environment: fixture.environment,
      configurationSource: SettingsRuntimeConfiguration(
        appearance: AppAppearanceSettingsRepository(settings),
      ),
    );
    final api = createTestApplication(useMock: false, bootstrap: bootstrap);
    await initializeTestApplication(api: api);
    expect(fixture.runtime.values['mode'], '2');
    final container = ProviderContainer(
      overrides: [
        appSettingsServiceProvider.overrideWithValue(settings),
        themeConfigSyncProvider.overrideWithValue(themeConfigSyncFor(api)),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(themeNotifierProvider.notifier);
    await notifier.load();
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.dark);
    await notifier.setThemeMode(ThemeMode.light);
    expect(fixture.runtime.values['mode'], '1');
    expect(
      (await SharedPreferences.getInstance()).getString('app_theme_mode'),
      'light',
    );
    expect(fixture.calls.where((c) => c == 'db').length, 1);
    expect(fixture.calls.where((c) => c == 'native').length, 1);
  });

  test('运行时主题同步显式报告失败，重试不受失败队列阻断', () async {
    final fixture = _Fixture();
    final error = StateError('同步失败');
    fixture.failures['theme'] = error;
    await expectLater(
      fixture.bootstrap.configurationSync.synchronizeThemeConfig(),
      throwsA(same(error)),
    );
    expect(fixture.calls, ['read_theme', 'theme']);
    fixture.failures.clear();
    await fixture.bootstrap.configurationSync.synchronizeThemeConfig();
    expect(fixture.calls, [
      'read_theme',
      'theme',
      'read_theme',
      'theme',
      'read_mode',
      'mode',
    ]);
  });

  test('完整启动保留原顺序，成功后再次初始化不重复执行', () async {
    final fixture = _Fixture();
    await fixture.bootstrap.initialize();
    expect(fixture.calls, [
      'native',
      'db_path',
      'db',
      'warm',
      'path_tts',
      'tts',
      'path_js',
      'js',
      'path_image',
      'image',
      'path_audio',
      'audio',
      'read_device',
      'device',
      'read_theme',
      'theme',
      'read_mode',
      'mode',
      'read_reading',
      'reading',
    ]);
    final count = fixture.calls.length;
    await fixture.bootstrap.initialize();
    expect(fixture.calls.length, count);
    expect(fixture.runtime.values['db'], '/sandbox/legado.db');
    expect(fixture.runtime.values['device'], 'fixture-device');
  });

  for (final step in ['native', 'db_path', 'db']) {
    test('$step 失败原样传播，不执行后续注入；不标记就绪', () async {
      final fixture = _Fixture();
      final error = StateError(step);
      fixture.failures[step] = error;
      await expectLater(fixture.bootstrap.initialize(), throwsA(same(error)));
      expect(fixture.calls, switch (step) {
        'native' => ['native'],
        'db_path' => ['native', 'db_path'],
        _ => ['native', 'db_path', 'db'],
      });
      fixture.failures.clear();
      await fixture.bootstrap.initialize();
      expect(fixture.calls.last, 'reading');
    });
  }

  for (final step in [
    'warm',
    'path_tts',
    'tts',
    'path_js',
    'js',
    'path_image',
    'image',
    'path_audio',
    'audio',
    'read_device',
    'device',
    'read_theme',
    'theme',
    'read_mode',
    'mode',
  ]) {
    test('$step 非关键失败仍继续到阅读注入，不重复启动', () async {
      final fixture = _Fixture();
      fixture.failures[step] = StateError(step);
      await fixture.bootstrap.initialize();
      expect(fixture.calls.last, 'reading');
      final count = fixture.calls.length;
      await fixture.bootstrap.initialize();
      expect(fixture.calls.length, count);
      if (step != 'warm') expect(fixture.logs, isNotEmpty);
      if (step == 'read_theme' || step == 'theme') {
        expect(fixture.calls, isNot(contains('read_mode')));
      }
      if (step == 'read_mode' || step == 'mode') {
        expect(fixture.runtime.values['theme'], {'themeName': '测试主题'});
      }
    });
  }

  for (final step in ['read_reading', 'reading']) {
    test('$step 失败不阻止启动，后续设置刷新可以重试', () async {
      final fixture = _Fixture();
      fixture.failures[step] = StateError(step);
      await fixture.bootstrap.initialize();
      expect(fixture.logs, isNotEmpty);
      expect(fixture.runtime.values, isNot(contains('reading')));
      fixture.failures.clear();
      await fixture.bootstrap.configurationSync.refreshReadBookConfig();
      expect(fixture.runtime.values['reading'], {'textSize': 20});
    });
  }

  test('TTS 返回 false 不阻止启动，设备 ID 空值不执行注入', () async {
    final fixture = _Fixture();
    fixture.runtime.ttsAccepted = false;
    fixture.environment.id = '';
    await fixture.bootstrap.initialize();
    expect(fixture.calls, isNot(contains('device')));
    expect(fixture.calls.last, 'reading');
    expect(fixture.logs.single, contains('ok=false'));
  });

  test('工厂和 Provider 共用生命周期与配置刷新，设置刷新不重新打开数据库', () async {
    final fixture = _Fixture();
    final api = createTestApplication(
      useMock: false,
      bootstrap: fixture.bootstrap,
    );
    final ready = await initializeTestApplication(api: api);
    final container = ProviderContainer(
      overrides: mergeTestOverrides([...ready.overrides]),
    );
    addTearDown(container.dispose);
    expect(
      container.read(bookshelfRepositoryProvider),
      same(api.bookshelfRepository),
    );
    final sync = container.read(readingConfigSyncProvider);
    expect(sync, same(api));
    final start = fixture.calls.length;
    fixture.source.fontSize = 26;
    await sync.refreshReadBookConfig();
    expect(fixture.calls.sublist(start), ['read_reading', 'reading']);
    expect(fixture.runtime.values['reading'], {'textSize': 26});
  });

  test('Mock 使用空操作，不访问提供的原生或配置依赖', () async {
    final fixture = _Fixture();
    final api = createTestApplication(
      useMock: true,
      bootstrap: fixture.bootstrap,
    );
    final container = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(container.dispose);
    final sync = container.read(readingConfigSyncProvider);
    expect(sync, isA<NoopReadingConfigSync>());
    await sync.refreshReadBookConfig();
    expect(fixture.calls, isEmpty);
  });

  test('阅读 Notifier 通过可替换配置接口刷新，无需真实 NativeTestApi', () async {
    SharedPreferences.setMockInitialValues({});
    final sync = _CountingSync();
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...createTestApplication(useMock: true).overrides,
        readingConfigSyncProvider.overrideWithValue(sync),
      ]),
    );
    addTearDown(container.dispose);
    final reader = container.read(readerNotifierProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await reader.updateFontSize(25);
    expect(sync.calls, 1);
    expect(container.read(readerNotifierProvider).fontSize, 25);
    await Future<void>.delayed(Duration.zero);
  });

  test('替换的配置接口异步失败时，阅读设置仍生效且不产生未捕获异常', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...createTestApplication(useMock: true).overrides,
        readingConfigSyncProvider.overrideWithValue(_FailingSync()),
      ]),
    );
    addTearDown(container.dispose);
    final reader = container.read(readerNotifierProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await reader.updateFontSize(24);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(readerNotifierProvider).fontSize, 24);
    expect(
      (await SharedPreferences.getInstance()).getDouble('reader_font_size'),
      24,
    );
  });
}

class _Fixture {
  final calls = <String>[];
  final failures = <String, Object>{};
  final logs = <String>[];
  late final runtime = _Runtime(this);
  late final environment = _Environment(this);
  late final source = _Configuration(this);
  late final bootstrap = RustBootstrap(
    runtime: runtime,
    environment: environment,
    configurationSource: source,
    log: logs.add,
  );

  void step(String name) {
    calls.add(name);
    if (failures[name] case final error?) throw error;
  }
}

class _Runtime implements RustRuntime {
  _Runtime(this.fixture);
  final _Fixture fixture;
  final values = <String, Object?>{};
  bool ttsAccepted = true;
  Future<void>? themeBarrier;

  @override
  Future<void> initialize() async => fixture.step('native');
  @override
  Future<void> openDatabase(String path) async {
    fixture.step('db');
    values['db'] = path;
  }

  @override
  Future<bool> setTtsCacheDirectory(String path) async {
    fixture.step('tts');
    return ttsAccepted;
  }

  @override
  Future<void> setJsCacheDirectory(String path) async => fixture.step('js');
  @override
  Future<void> setImageCacheDirectory(String path) async =>
      fixture.step('image');
  @override
  Future<void> setAudioCacheDirectory(String path) async =>
      fixture.step('audio');
  @override
  Future<void> setDeviceId(String id) async {
    fixture.step('device');
    values['device'] = id;
  }

  @override
  Future<void> setThemeConfig(RuntimeConfigSnapshot snapshot) async {
    fixture.step('theme');
    await themeBarrier;
    values['theme'] = snapshot.fields;
  }

  @override
  Future<void> setThemeMode(String mode) async {
    fixture.step('mode');
    values['mode'] = mode;
  }

  @override
  Future<void> setReadBookConfig(RuntimeConfigSnapshot snapshot) async {
    fixture.step('reading');
    values['reading'] = snapshot.fields;
  }
}

class _Environment implements AppEnvironment {
  _Environment(this.fixture);
  final _Fixture fixture;
  String? id = 'fixture-device';

  @override
  Future<String> databasePath() async {
    fixture.step('db_path');
    return '/sandbox/legado.db';
  }

  @override
  Future<void> warmLocalBookStore() async => fixture.step('warm');
  @override
  Future<String> cacheDirectory(RuntimeCache cache) async {
    fixture.step('path_${cache.name}');
    return '/sandbox/${cache.name}_cache';
  }

  @override
  Future<String?> deviceId() async {
    fixture.step('read_device');
    return id;
  }
}

class _Configuration implements RuntimeConfigurationSource {
  _Configuration(this.fixture);
  final _Fixture fixture;
  int fontSize = 20;

  @override
  Future<RuntimeConfigSnapshot> readThemeConfig() async {
    fixture.step('read_theme');
    return RuntimeConfigSnapshot({'themeName': '测试主题'});
  }

  @override
  Future<String> readThemeMode() async {
    fixture.step('read_mode');
    return '0';
  }

  @override
  Future<RuntimeConfigSnapshot> readReadBookConfig() async {
    fixture.step('read_reading');
    return RuntimeConfigSnapshot({'textSize': fontSize});
  }
}

class _CountingSync implements ReadingConfigSync {
  int calls = 0;
  @override
  Future<void> refreshReadBookConfig() async => calls++;
}

class _FailingSync implements ReadingConfigSync {
  @override
  Future<void> refreshReadBookConfig() async => throw StateError('配置注入失败');
}
