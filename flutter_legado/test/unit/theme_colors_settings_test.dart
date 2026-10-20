import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/constants/pref_keys.dart';
import 'package:flutter_legado/src/data/repositories/app_theme_colors_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/theme_colors_settings.dart';
import 'package:flutter_legado/src/features/appearance/theme_actions.dart';
import 'package:flutter_legado/src/models/theme_document.dart';
import 'package:flutter_legado/src/models/theme_preset.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/theme/theme_colors_notifier.dart';
import 'package:flutter_legado/src/providers/theme/theme_notifier.dart';

import '../fixtures/theme_settings_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AppSettingsService serviceFor(ThemeSettingsStorage storage) {
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    addTearDown(service.dispose);
    return service;
  }

  ProviderContainer containerFor(AppSettingsService service) {
    final container = ProviderContainer(
      overrides: [appSettingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('默认值不写入，纯模型按日夜返回背景路径', () async {
    final storage = ThemeSettingsStorage();
    final repository = AppThemeColorsSettingsRepository(serviceFor(storage));
    expect(await repository.load(), const ThemeColorsSettings());
    expect(storage.writes, isEmpty);
    const settings = ThemeColorsSettings(bgImage: '日', bgImageNight: '夜');
    expect(settings.bgImageFor(isNight: false), '日');
    expect(settings.bgImageFor(isNight: true), '夜');
  });

  test('八个槽位写入原键，整型颜色和背景路径可从真实偏好恢复', () async {
    final service = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(service.dispose);
    final repository = AppThemeColorsSettingsRepository(service);
    await repository.setColors({
      for (final role in ThemeColorRole.values)
        role: role.index == 0 ? -1 : role.index,
    });
    await repository.setBgImage(day: '日间.jpg', night: '夜间.jpg');
    final prefs = await SharedPreferences.getInstance();
    expect(
      {for (final key in prefs.getKeys()) key: prefs.get(key)},
      {
        'colorPrimary': -1,
        'colorAccent': 1,
        'colorBackground': 2,
        'colorBottomBackground': 3,
        'colorPrimaryNight': 4,
        'colorAccentNight': 5,
        'colorBackgroundNight': 6,
        'colorBottomBackgroundNight': 7,
        'backgroundImage': '日间.jpg',
        'backgroundImageNight': '夜间.jpg',
      },
    );
    final restored = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(restored.dispose);
    expect(
      await AppThemeColorsSettingsRepository(restored).load(),
      repository.current,
    );
  });

  test('清除颜色与空背景删除原键，不影响另一侧及未传字段', () async {
    final storage = ThemeSettingsStorage({
      PrefKeys.cPrimary: 11,
      PrefKeys.cNPrimary: 22,
      PrefKeys.bgImage: '日',
      PrefKeys.bgImageN: '夜',
    });
    final repository = AppThemeColorsSettingsRepository(serviceFor(storage));
    await repository.load();
    await repository.setColors({ThemeColorRole.primary: null});
    await repository.setBgImage(day: '');
    expect(storage.values, {PrefKeys.cNPrimary: 22, PrefKeys.bgImageN: '夜'});
    expect(repository.current.primary, isNull);
    expect(repository.current.primaryNight, 22);
    expect(repository.current.bgImage, '');
    expect(repository.current.bgImageNight, '夜');
  });

  test('错误类型回退默认，读取不修写已有值', () async {
    final storage = ThemeSettingsStorage({
      PrefKeys.cPrimary: '坏值',
      PrefKeys.bgImage: 12,
    });
    final repository = AppThemeColorsSettingsRepository(serviceFor(storage));
    expect(await repository.load(), const ThemeColorsSettings());
    expect(storage.values, {PrefKeys.cPrimary: '坏值', PrefKeys.bgImage: 12});
    expect(storage.writes, isEmpty);
  });

  test('外部恢复后显式重读同步颜色及背景，删除的键回默认', () async {
    final storage = ThemeSettingsStorage({
      PrefKeys.cPrimary: 11,
      PrefKeys.bgImageN: '旧',
    });
    final container = containerFor(serviceFor(storage));
    final notifier = container.read(themeColorsProvider.notifier);
    await notifier.load();
    storage.values.remove(PrefKeys.cPrimary);
    storage.values[PrefKeys.cNAccent] = 33;
    storage.values[PrefKeys.bgImageN] = '新';
    await notifier.reload();
    final settings = container.read(themeColorsProvider);
    expect(settings.primary, isNull);
    expect(settings.accentNight, 33);
    expect(settings.bgImageNight, '新');
    expect(storage.writes, isEmpty);
  });

  test('多键部分失败保留已保存字段，回退失败字段且继续允许重试', () async {
    final storage = ThemeSettingsStorage({
      PrefKeys.cPrimary: 1,
      PrefKeys.cAccent: 2,
    });
    final container = containerFor(serviceFor(storage));
    final notifier = container.read(themeColorsProvider.notifier);
    await notifier.load();
    storage.failKey = PrefKeys.cAccent;
    await expectLater(
      notifier.applyColors({
        ThemeColorRole.primary: 11,
        ThemeColorRole.accent: 22,
      }),
      throwsStateError,
    );
    expect(container.read(themeColorsProvider).primary, 11);
    expect(container.read(themeColorsProvider).accent, 2);
    expect(storage.values, {PrefKeys.cPrimary: 11, PrefKeys.cAccent: 2});
    storage.failKey = null;
    await notifier.setColor(ThemeColorRole.accent, 22);
    expect(container.read(themeColorsProvider).accent, 22);
  });

  test('背景保存失败回退并向上抛出，删除失败保留原路径', () async {
    final storage = ThemeSettingsStorage({PrefKeys.bgImage: '原图'});
    final container = containerFor(serviceFor(storage));
    final notifier = container.read(themeColorsProvider.notifier);
    await notifier.load();
    storage.failKey = PrefKeys.bgImage;
    await expectLater(notifier.setBgImage(day: '新图'), throwsStateError);
    expect(container.read(themeColorsProvider).bgImage, '原图');
    await expectLater(notifier.setBgImage(day: ''), throwsStateError);
    expect(container.read(themeColorsProvider).bgImage, '原图');
  });

  test('应用预设失败传递错误，不改变另一侧和背景', () async {
    final storage = ThemeSettingsStorage({
      PrefKeys.cPrimary: 11,
      PrefKeys.bgImage: '原图',
    });
    final container = containerFor(serviceFor(storage));
    await container.read(themeColorsProvider.notifier).load();
    storage.failNext = true;
    await expectLater(
      container
          .read(themeActionsProvider)
          .applyPreset(ThemePreset(name: '失败主题', isNight: false, primary: 22)),
      throwsStateError,
    );
    expect(container.read(themeColorsProvider).primary, 11);
    expect(container.read(themeColorsProvider).bgImage, '原图');
  });

  test('文件导入颜色失败不再继续修改主题模式和色板', () async {
    final storage = ThemeSettingsStorage({PrefKeys.cPrimary: 11});
    final container = containerFor(serviceFor(storage));
    await container.read(themeColorsProvider.notifier).load();
    final original = container.read(themeNotifierProvider);
    storage.failNext = true;
    await expectLater(
      container
          .read(themeActionsProvider)
          .applyDocument(
            const ThemeDocument(
              paletteId: 'koharu',
              themeMode: 'dark',
              day: ThemeDocumentColors(primary: 22),
              night: ThemeDocumentColors(),
            ),
          ),
      throwsStateError,
    );
    expect(container.read(themeColorsProvider).primary, 11);
    expect(container.read(themeNotifierProvider).themeMode, original.themeMode);
    expect(container.read(themeNotifierProvider).paletteId, original.paletteId);
  });
}
