import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/data/bridge/runtime_configuration.dart';
import 'package:flutter_legado/src/data/repositories/app_appearance_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/contracts/settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/appearance_settings.dart';
import 'package:flutter_legado/src/features/appearance/appearance_settings_provider.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/theme/theme_notifier.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late AppSettingsService service;
  late AppAppearanceSettingsRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = _Storage();
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    repository = AppAppearanceSettingsRepository(service);
  });
  tearDown(() => service.dispose());

  ProviderContainer createContainer({_Sync? sync}) {
    final container = ProviderContainer(
      overrides: [
        appSettingsServiceProvider.overrideWithValue(service),
        if (sync != null) themeConfigSyncProvider.overrideWithValue(sync),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('默认值、编码与重新读取保留三个原键及类型', () async {
    expect(await repository.load(), const AppearanceSettings());
    await repository.update(
      (s) => s.copyWith(
        themeMode: AppThemeMode.dark,
        fontScaleRaw: 12,
        paletteId: 'koharu',
      ),
    );
    expect(storage.values, {
      'app_theme_mode': 'dark',
      'app_font_scale': 12,
      'app_palette_id': 'koharu',
    });
    storage.values['app_font_scale'] = 0;
    expect(repository.current.fontScaleRaw, 12);
    await repository.reload();
    expect(repository.current.fontScaleRaw, 0);
  });

  for (final mode in AppThemeMode.values) {
    test('主题 ${mode.name} 可保存并在新仓储恢复', () async {
      storage.values['app_theme_mode'] = 'unknown';
      await repository.load();
      expect(repository.current.themeMode, AppThemeMode.system);
      // 默认值也验证显式选择，旧 dark 不能被初始化默认值掩盖。
      storage.values['app_theme_mode'] = 'dark';
      await repository.reload();
      await repository.update((s) => s.copyWith(themeMode: mode));
      final restoredService = AppSettingsService(
        storages: {SettingsStorageKind.preferences: storage},
      );
      addTearDown(restoredService.dispose);
      final restored = AppAppearanceSettingsRepository(restoredService);
      expect((await restored.load()).themeMode, mode);
    });
  }

  test('首次选择默认模式先读旧值，不能丢失操作或覆盖其他字段', () async {
    storage.values.addAll({
      'app_theme_mode': 'dark',
      'app_font_scale': 14,
      'app_palette_id': 'koharu',
    });
    await repository.update((s) => s.copyWith(themeMode: AppThemeMode.system));
    expect(storage.values, {
      'app_theme_mode': 'system',
      'app_font_scale': 14,
      'app_palette_id': 'koharu',
    });
    expect(storage.writes, ['app_theme_mode']);
  });

  test('字体超出范围及未知调色板沿用原存储值，不擅自规范化', () async {
    await repository.load();
    for (final raw in [7, 8, 16, 17, 0]) {
      await repository.update((s) => s.copyWith(fontScaleRaw: raw));
      expect(repository.current.fontScaleRaw, raw);
      expect(storage.values['app_font_scale'], raw);
    }
    await repository.update((s) => s.copyWith(paletteId: 'unknown'));
    expect(repository.current.paletteId, 'unknown');
  });

  test('错误偏好类型沿用默认展示，不能自动改写原键', () async {
    storage.values.addAll({'app_font_scale': '12', 'app_palette_id': 42});
    expect(await repository.load(), const AppearanceSettings());
    expect(storage.values, {'app_font_scale': '12', 'app_palette_id': 42});
    expect(storage.writes, isEmpty);
  });

  test('连续调色板修改与其他字段的保存互不覆盖', () async {
    await repository.load();
    await repository.update((s) => s.copyWith(paletteId: 'sora'));
    await repository.update((s) => s.copyWith(paletteId: 'gr'));
    await repository.update((s) => s.copyWith(fontScaleRaw: 12));
    expect(repository.current.paletteId, 'gr');
    expect(storage.values['app_palette_id'], 'gr');
  });

  test('读取失败可重试，初始化迟到不丢失用户选择', () async {
    storage.readFailure = true;
    await expectLater(repository.load(), throwsStateError);
    storage.readFailure = false;
    storage.values['app_theme_mode'] = 'light';
    final pending = Completer<void>();
    storage.readBarrier = pending;
    final loading = repository.load();
    final saving = repository.update(
      (s) => s.copyWith(themeMode: AppThemeMode.dark),
    );
    pending.complete();
    await loading;
    await saving;
    expect(repository.current.themeMode, AppThemeMode.dark);
  });

  test('写入失败回退所有订阅侧，重试后保存成功', () async {
    final container = createContainer();
    final notifier = container.read(themeNotifierProvider.notifier);
    await notifier.load();
    storage.writeFailure = true;
    final saving = notifier.setThemeMode(ThemeMode.dark);
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.dark);
    await expectLater(saving, throwsStateError);
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.system);
    expect(repository.current.themeMode, AppThemeMode.system);
    storage.writeFailure = false;
    await notifier.setThemeMode(ThemeMode.dark);
    expect(storage.values['app_theme_mode'], 'dark');
  });

  test('较早写入失败不撤销后来选择，写入仍按调用顺序执行', () async {
    final container = createContainer();
    final notifier = container.read(themeNotifierProvider.notifier);
    await notifier.load();
    final barrier = Completer<void>();
    storage.beforeWrite = (key, value) async {
      if (value == 'dark') {
        await barrier.future;
        throw StateError('较早保存失败');
      }
    };
    final first = notifier.setThemeMode(ThemeMode.dark);
    final failed = expectLater(first, throwsStateError);
    final second = notifier.setThemeMode(ThemeMode.light);
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.light);
    barrier.complete();
    await failed;
    await second;
    expect(storage.values['app_theme_mode'], 'light');
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.light);
  });

  test('SharedPreferences 返回 false 视为失败，不假报保存成功', () async {
    final prefs = _Preferences();
    when(() => prefs.get(any())).thenReturn(null);
    when(() => prefs.setString('app_theme_mode', 'dark'))
        .thenAnswer((_) async => false);
    final localService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(
          preferences: () async => prefs,
        ),
      },
    );
    addTearDown(localService.dispose);
    final localRepository = AppAppearanceSettingsRepository(localService);
    await localRepository.load();
    await expectLater(
      localRepository.update((s) => s.copyWith(themeMode: AppThemeMode.dark)),
      throwsStateError,
    );
    expect(localRepository.current.themeMode, AppThemeMode.system);
  });

  test('原生同步失败保留已保存偏好，重试只同步、不重复写存储', () async {
    final sync = _Sync()..fail = true;
    final container = createContainer(sync: sync);
    final notifier = container.read(themeNotifierProvider.notifier);
    await notifier.load();
    await expectLater(
      notifier.setThemeMode(ThemeMode.dark),
      throwsA(isA<AppearanceSyncException>()),
    );
    expect(storage.values['app_theme_mode'], 'dark');
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.dark);
    sync.fail = false;
    await notifier.synchronizeRuntime();
    expect(sync.calls, 2);
    expect(storage.writes, ['app_theme_mode']);
  });

  test('存储失败不注入原生主题，字体缩放不会触发无关注入', () async {
    final sync = _Sync();
    final container = createContainer(sync: sync);
    final notifier = container.read(themeNotifierProvider.notifier);
    await notifier.load();
    storage.writeFailure = true;
    await expectLater(notifier.setThemeMode(ThemeMode.dark), throwsStateError);
    expect(sync.calls, 0);
    storage.writeFailure = false;
    await notifier.setFontScale(12);
    expect(sync.calls, 0);
  });

  test('阅读器跟随共享主题预览与失败回退，不残留失败主题的背景', () async {
    storage.values['app_theme_mode'] = 'light';
    final container = createContainer();
    final notifier = container.read(themeNotifierProvider.notifier);
    await notifier.load();
    container.read(readerNotifierProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final original = container.read(readerNotifierProvider).backgroundColor;
    final barrier = Completer<void>();
    storage.beforeWrite = (_, _) async {
      await barrier.future;
      throw StateError('保存失败');
    };
    final saving = notifier.setThemeMode(ThemeMode.dark);
    final failed = expectLater(saving, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(readerNotifierProvider).backgroundColor,
      isNot(original),
    );
    barrier.complete();
    await failed;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(readerNotifierProvider).backgroundColor, original);
  });

  test('联合应用先保存模式与调色板，原生失败不阻断剩余偏好写入', () async {
    final sync = _Sync()..fail = true;
    final container = createContainer(sync: sync);
    final notifier = container.read(themeNotifierProvider.notifier);
    await notifier.load();
    await expectLater(
      notifier.applyAppearance(themeMode: ThemeMode.dark, paletteId: 'koharu'),
      throwsA(isA<AppearanceSyncException>()),
    );
    expect(storage.values, {
      'app_theme_mode': 'dark',
      'app_palette_id': 'koharu',
    });
    expect(sync.calls, 1);
  });

  test('外部恢复后重读，启动来源与界面使用同一快照', () async {
    final container = createContainer();
    final notifier = container.read(themeNotifierProvider.notifier);
    final source = SettingsRuntimeConfiguration(appearance: repository);
    await notifier.load();
    storage.values.addAll({
      'app_theme_mode': 'dark',
      'app_font_scale': 14,
      'app_palette_id': 'koharu',
    });
    await notifier.reload();
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.dark);
    expect(container.read(themeNotifierProvider).fontScaleRaw, 14);
    expect(await source.readThemeMode(), '2');
    final snapshot = await source.readThemeConfig();
    expect(snapshot.fields['isNightTheme'], false);
    expect(snapshot.fields['themeName'], isNotEmpty);
    expect(repository.current.paletteId, 'koharu');
  });

  test('根设置实例替换后，旧写入的迟到完成不能改写新主题或启动同步', () async {
    final sync = _Sync();
    final container = createContainer(sync: sync);
    final notifier = container.read(themeNotifierProvider.notifier);
    await notifier.load();
    final barrier = Completer<void>();
    storage.beforeWrite = (_, _) => barrier.future;
    final saving = notifier.setThemeMode(ThemeMode.dark);
    final replacementStorage = _Storage()..values['app_theme_mode'] = 'light';
    final replacement = AppSettingsService(
      storages: {SettingsStorageKind.preferences: replacementStorage},
    );
    addTearDown(replacement.dispose);
    container.updateOverrides([
      appSettingsServiceProvider.overrideWithValue(replacement),
      themeConfigSyncProvider.overrideWithValue(sync),
    ]);
    await container.read(themeNotifierProvider.notifier).load();
    barrier.complete();
    await saving;
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.light);
    expect(sync.calls, 0);
  });
}

class _Preferences extends Mock implements SharedPreferences {}

class _Sync implements ThemeConfigSync {
  bool fail = false;
  int calls = 0;
  @override
  Future<void> synchronizeThemeConfig() async {
    calls++;
    if (fail) throw StateError('原生同步失败');
  }
}

class _Storage implements SettingsStorage {
  final values = <String, Object?>{};
  final writes = <String>[];
  bool readFailure = false;
  bool writeFailure = false;
  Completer<void>? readBarrier;
  Future<void> Function(String, Object?)? beforeWrite;

  @override
  Future<Object?> read(String key) async {
    if (readFailure) throw StateError('读取失败');
    await readBarrier?.future;
    return values[key];
  }

  @override
  Future<void> write(String key, Object? value) async {
    writes.add(key);
    await beforeWrite?.call(key, value);
    if (writeFailure) throw StateError('保存失败');
    values[key] = value;
  }
}
