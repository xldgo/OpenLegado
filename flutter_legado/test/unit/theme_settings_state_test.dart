import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/constants/pref_keys.dart';
import 'package:flutter_legado/src/providers/theme/app_theme_preferences_provider.dart';
import 'package:flutter_legado/src/providers/theme/theme_colors_notifier.dart';
import 'package:flutter_legado/src/providers/ui_settings/ui_settings_notifier.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/theme_colors_settings.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';

import '../fixtures/theme_settings_storage.dart';

Future<void> flushLoads() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

ProviderContainer containerFor(ThemeSettingsStorage storage) {
  final service = AppSettingsService(
    storages: {SettingsStorageKind.preferences: storage},
  );
  addTearDown(service.dispose);
  return ProviderContainer(
    overrides: [appSettingsServiceProvider.overrideWithValue(service)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('完整界面偏好由共享来源恢复，修改单项不影响其他设置', () async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.topBarButtonStyle: 'liquidGlass',
      PrefKeys.enableBlur: true,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(uiSettingsProvider.notifier);
    await notifier.load();
    await notifier.setTopBarButtonStyle(TopBarButtonStyle.plain);
    final state = container.read(uiSettingsProvider);
    expect(state.topBarButtonStyle, TopBarButtonStyle.plain);
    expect(state.enableBlur, isTrue);
  });

  test('显式选择默认布局值覆盖旧偏好', () async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.topBarButtonStyle: 'plain',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(uiSettingsProvider.notifier);
    await notifier.load();
    await notifier.setTopBarButtonStyle(TopBarButtonStyle.tonal);
    expect(
      container.read(uiSettingsProvider).topBarButtonStyle,
      TopBarButtonStyle.tonal,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        PrefKeys.topBarButtonStyle,
      ),
      'tonal',
    );
  });

  test('颜色恢复保留新颜色及未修改的夜间颜色', () async {
    final settings = ThemeSettingsStorage({
      PrefKeys.cPrimary: 11,
      PrefKeys.cNPrimary: 22,
    })..readGate = Completer<void>();
    final container = containerFor(settings);
    addTearDown(container.dispose);
    final notifier = container.read(themeColorsProvider.notifier);
    await flushLoads();
    final saving = notifier.setColor(ThemeColorRole.primary, 33);
    settings.readGate!.complete();
    await saving;
    await notifier.load();
    final state = container.read(themeColorsProvider);
    expect(state.primary, 33);
    expect(state.primaryNight, 22);
  });

  test('主题预设保存完成不覆盖期间的新颜色和背景图', () async {
    final settings = ThemeSettingsStorage({});
    final container = containerFor(settings);
    addTearDown(container.dispose);
    final notifier = container.read(themeColorsProvider.notifier);
    await flushLoads();
    settings.writeGate = Completer<void>();
    final preset = notifier.applyColors({
      ThemeColorRole.primary: 11,
      ThemeColorRole.accent: 22,
    });
    final change = notifier.setColor(ThemeColorRole.primary, 33);
    final background = notifier.setBgImage(day: 'new-cover.jpg');
    await flushLoads();
    settings.writeGate!.complete();
    await Future.wait([preset, change, background]);
    final state = container.read(themeColorsProvider);
    expect(state.primary, 33);
    expect(state.accent, 22);
    expect(state.bgImage, 'new-cover.jpg');
    expect(settings.values[PrefKeys.cPrimary], 33);
  });

  test('连续调色按操作顺序保存，最终持久化与页面一致', () async {
    final settings = ThemeSettingsStorage({});
    final container = containerFor(settings);
    addTearDown(container.dispose);
    final notifier = container.read(themeColorsProvider.notifier);
    await flushLoads();
    settings.writeGate = Completer<void>();
    final first = notifier.setColor(ThemeColorRole.primary, 11);
    final second = notifier.setColor(ThemeColorRole.primary, 22);
    await flushLoads();
    settings.writeGate!.complete();
    await Future.wait([first, second]);
    expect(container.read(themeColorsProvider).primary, 22);
    expect(settings.values[PrefKeys.cPrimary], 22);
  });

  test('加载完成前释放作用域，不再回写已销毁的状态', () async {
    final settings = ThemeSettingsStorage({PrefKeys.cPrimary: 11})
      ..readGate = Completer<void>();
    final container = containerFor(settings);
    container.read(themeColorsProvider);
    container.read(uiSettingsProvider);
    await flushLoads();
    container.dispose();
    settings.readGate!.complete();
    await flushLoads();
  });

  test('主题预设保存失败保留当前配色，后续调色仍能保存', () async {
    final settings = ThemeSettingsStorage({PrefKeys.cPrimary: 11});
    final container = containerFor(settings);
    addTearDown(container.dispose);
    final notifier = container.read(themeColorsProvider.notifier);
    await flushLoads();
    settings.failNext = true;
    await expectLater(
      notifier.applyColors({ThemeColorRole.primary: 22}),
      throwsStateError,
    );
    expect(container.read(themeColorsProvider).primary, 11);
    await notifier.setColor(ThemeColorRole.primary, 33);
    expect(container.read(themeColorsProvider).primary, 33);
    expect(settings.values[PrefKeys.cPrimary], 33);
  });

  test('外观输入只跟随配色字段，布局和背景路径不重建该输入', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = ThemeSettingsStorage({});
    final container = containerFor(settings);
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
        .setColor(ThemeColorRole.primaryNight, 0xFF112233);
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
