import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/constants/pref_keys.dart';
import 'package:flutter_legado/src/providers/theme/app_theme_preferences_provider.dart';
import 'package:flutter_legado/src/providers/theme/theme_colors_notifier.dart';
import 'package:flutter_legado/src/providers/ui_settings/ui_settings_notifier.dart';
import 'package:flutter_legado/src/services/settings_service.dart';

Future<void> flushLoads() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

// 用可控延迟模拟读出的旧快照及平台写入顺序，不依赖设备或真实时间。
class DelayedSettings extends SettingsService {
  DelayedSettings(this.initial);

  final Map<String, Object> initial;
  final Map<String, Object> saved = {};
  final List<(String, Object?)> writes = [];
  Completer<void>? readGate;
  Completer<void>? writeGate;
  Completer<void>? batchGate;
  bool failBatch = false;

  Future<Object?> read(String key) async {
    final value = initial[key];
    await readGate?.future;
    return value;
  }

  @override
  Future<String> getStringPref(String key, {String defaultValue = ''}) async =>
      (await read(key)) as String? ?? defaultValue;

  @override
  Future<bool> getBoolPref(String key, {required bool defaultValue}) async =>
      (await read(key)) as bool? ?? defaultValue;

  @override
  Future<int> getIntPref(String key, {required int defaultValue}) async =>
      (await read(key)) as int? ?? defaultValue;

  @override
  Future<int?> getIntPrefOrNull(String key) async => (await read(key)) as int?;

  Future<void> save(String key, Object? value) async {
    writes.add((key, value));
    if (writes.length == 1) await writeGate?.future;
    if (value == null) {
      saved.remove(key);
    } else {
      saved[key] = value;
    }
  }

  @override
  Future<void> setStringPref(String key, String value) => save(key, value);

  @override
  Future<void> setBoolPref(String key, bool value) => save(key, value);

  @override
  Future<void> setIntPref(String key, int value) => save(key, value);

  @override
  Future<void> removePref(String key) => save(key, null);

  @override
  Future<void> setColorPrefs(Map<String, int?> colors) async {
    await batchGate?.future;
    if (failBatch) throw StateError('模拟保存失败');
    for (final entry in colors.entries) {
      await save(entry.key, entry.value);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('UI 启动恢复保留新操作，同时恢复未修改的字段', () async {
    final settings = DelayedSettings({
      PrefKeys.topBarButtonStyle: 'liquidGlass',
      PrefKeys.enableBlur: true,
    })..readGate = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        uiSettingsProvider.overrideWith(
          () => UiSettingsNotifier(settings: settings),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(uiSettingsProvider.notifier);
    await flushLoads();
    await notifier.setTopBarButtonStyle(TopBarButtonStyle.plain);
    settings.readGate!.complete();
    await flushLoads();
    final state = container.read(uiSettingsProvider);
    expect(state.topBarButtonStyle, TopBarButtonStyle.plain);
    expect(state.enableBlur, isTrue);
  });

  test('启动时显式选择默认值也应覆盖旧偏好', () async {
    final settings = DelayedSettings({PrefKeys.topBarButtonStyle: 'plain'})
      ..readGate = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        uiSettingsProvider.overrideWith(
          () => UiSettingsNotifier(settings: settings),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(uiSettingsProvider.notifier);
    await flushLoads();
    await notifier.setTopBarButtonStyle(TopBarButtonStyle.tonal);
    settings.readGate!.complete();
    await flushLoads();
    expect(
      container.read(uiSettingsProvider).topBarButtonStyle,
      TopBarButtonStyle.tonal,
    );
    expect(settings.saved[PrefKeys.topBarButtonStyle], 'tonal');
  });

  test('颜色恢复保留新颜色及未修改的夜间颜色', () async {
    final settings = DelayedSettings({
      PrefKeys.cPrimary: 11,
      PrefKeys.cNPrimary: 22,
    })..readGate = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        themeColorsProvider.overrideWith(
          () => ThemeColorsNotifier(settings: settings),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(themeColorsProvider.notifier);
    await flushLoads();
    await notifier.setColor(PrefKeys.cPrimary, 33);
    settings.readGate!.complete();
    await flushLoads();
    final state = container.read(themeColorsProvider);
    expect(state.primary, 33);
    expect(state.primaryNight, 22);
  });

  test('主题预设保存完成不覆盖期间的新颜色和背景图', () async {
    final settings = DelayedSettings({});
    final container = ProviderContainer(
      overrides: [
        themeColorsProvider.overrideWith(
          () => ThemeColorsNotifier(settings: settings),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(themeColorsProvider.notifier);
    await flushLoads();
    settings.batchGate = Completer<void>();
    final preset = notifier.applyColors({
      PrefKeys.cPrimary: 11,
      PrefKeys.cAccent: 22,
    });
    final change = notifier.setColor(PrefKeys.cPrimary, 33);
    final background = notifier.setBgImage(day: 'new-cover.jpg');
    await flushLoads();
    settings.batchGate!.complete();
    await Future.wait([preset, change, background]);
    final state = container.read(themeColorsProvider);
    expect(state.primary, 33);
    expect(state.accent, 22);
    expect(state.bgImage, 'new-cover.jpg');
    expect(settings.saved[PrefKeys.cPrimary], 33);
  });

  test('连续调色按操作顺序保存，最终持久化与页面一致', () async {
    final settings = DelayedSettings({});
    final container = ProviderContainer(
      overrides: [
        themeColorsProvider.overrideWith(
          () => ThemeColorsNotifier(settings: settings),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(themeColorsProvider.notifier);
    await flushLoads();
    settings.writeGate = Completer<void>();
    final first = notifier.setColor(PrefKeys.cPrimary, 11);
    final second = notifier.setColor(PrefKeys.cPrimary, 22);
    await flushLoads();
    settings.writeGate!.complete();
    await Future.wait([first, second]);
    expect(container.read(themeColorsProvider).primary, 22);
    expect(settings.saved[PrefKeys.cPrimary], 22);
  });

  test('加载完成前释放作用域，不再回写已销毁的状态', () async {
    final settings = DelayedSettings({PrefKeys.cPrimary: 11})
      ..readGate = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        themeColorsProvider.overrideWith(
          () => ThemeColorsNotifier(settings: settings),
        ),
        uiSettingsProvider.overrideWith(
          () => UiSettingsNotifier(settings: settings),
        ),
      ],
    );
    container.read(themeColorsProvider);
    container.read(uiSettingsProvider);
    await flushLoads();
    container.dispose();
    settings.readGate!.complete();
    await flushLoads();
  });

  test('主题预设保存失败保留当前配色，后续调色仍能保存', () async {
    final settings = DelayedSettings({PrefKeys.cPrimary: 11});
    final container = ProviderContainer(
      overrides: [
        themeColorsProvider.overrideWith(
          () => ThemeColorsNotifier(settings: settings),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(themeColorsProvider.notifier);
    await flushLoads();
    settings.failBatch = true;
    await notifier.applyColors({PrefKeys.cPrimary: 22});
    expect(container.read(themeColorsProvider).primary, 11);
    await notifier.setColor(PrefKeys.cPrimary, 33);
    expect(container.read(themeColorsProvider).primary, 33);
    expect(settings.saved[PrefKeys.cPrimary], 33);
  });

  test('外观输入只跟随配色字段，布局和背景路径不重建该输入', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = DelayedSettings({});
    final container = ProviderContainer(
      overrides: [
        themeColorsProvider.overrideWith(
          () => ThemeColorsNotifier(settings: settings),
        ),
        uiSettingsProvider.overrideWith(
          () => UiSettingsNotifier(settings: settings),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(appThemePreferencesProvider);
    await flushLoads();
    final before = container.read(appThemePreferencesProvider);
    await container.read(uiSettingsProvider.notifier).setRailExtended(true);
    await container
        .read(themeColorsProvider.notifier)
        .setBgImage(day: 'background.jpg');
    expect(
      identical(container.read(appThemePreferencesProvider), before),
      isTrue,
    );
    await container.read(uiSettingsProvider.notifier).setThemeAmoled(true);
    expect(container.read(appThemePreferencesProvider).amoledDark, isTrue);
    await container
        .read(themeColorsProvider.notifier)
        .setColor(PrefKeys.cNPrimary, 0xFF112233);
    expect(
      container
          .read(appThemePreferencesProvider)
          .darkColors
          .primary
          ?.toARGB32(),
      0xFF112233,
    );
  });
}
