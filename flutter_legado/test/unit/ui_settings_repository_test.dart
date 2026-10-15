import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_ui_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/ui_settings/ui_settings_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppSettingsService service;
  late AppUiSettingsRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    repository = AppUiSettingsRepository(service);
  });
  tearDown(() => service.dispose());

  ProviderContainer containerFor(AppSettingsService settings) {
    final container = ProviderContainer(
      overrides: [appSettingsServiceProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('默认值沿用原口径，打开设置不写入存储', () async {
    expect(await repository.load(), const UiSettings());
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('通用UI设置不再读取或写回无消费者的旧阅读亮度字段', () async {
    SharedPreferences.setMockInitialValues({
      'readMenuBrightnessVertical': true,
      'readMenuBrightnessVwPos': 'left',
    });
    expect(await repository.load(), const UiSettings());
    expect(
      service.current.values.keys.map((address) => address.key),
      isNot(contains('readMenuBrightnessVertical')),
    );
    expect(
      service.current.values.keys.map((address) => address.key),
      isNot(contains('readMenuBrightnessVwPos')),
    );
    await repository.update(enableBlur: true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('readMenuBrightnessVertical'), isTrue);
    expect(prefs.getString('readMenuBrightnessVwPos'), 'left');
  });

  test('十项布局保留原键和类型，可从新仓储恢复', () async {
    await repository.update(
      topBarButtonStyle: TopBarButtonStyle.plain,
      mergeTopBarActions: true,
      useFlexibleTopAppBar: false,
      topBarOpacity: 75,
      labelVisibilityMode: BottomBarLabelMode.labeled,
      bottomBarOpacity: 80,
      useFloatingBottomBar: true,
      showBottomView: false,
      tabletInterface: TabletInterfaceMode.always,
      railExtended: true,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      {for (final key in prefs.getKeys()) key: prefs.get(key)},
      {
        'topBarButtonStyle': 'plain',
        'mergeTopBarActions': true,
        'useFlexibleTopAppBar': false,
        'topBarOpacity': 75,
        'labelVisibilityMode': 'labeled',
        'bottomBarOpacity': 80,
        'useFloatingBottomBar': true,
        'showBottomView': false,
        'tabletInterface': 'always',
        'railExtended': true,
      },
    );
    final restoredService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(restoredService.dispose);
    expect(
      await AppUiSettingsRepository(restoredService).load(),
      repository.current,
    );
  });

  test('其余十五项完整保存原键及类型，并从共享仓储恢复', () async {
    await repository.update(
      bookInfoFollowCoverColor: false,
      bookInfoNetworkCoverBackground: 'off',
      bookInfoDefaultCoverBackground: 'off_for_default',
      overrideBaseCardCornerRadius: true,
      baseCardCornerRadius: 22,
      enableBlur: true,
      topBarBlurRadius: 32,
      topBarBlurAlpha: 120,
      bottomBarBlurRadius: 12,
      bottomBarBlurAlpha: 90,
      wallpaperColorFollow: true,
      enableItemDivider: true,
      themeStyle: 'fruitSalad',
      themeContrastLevel: '0.5',
      themeAmoled: true,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      {for (final key in prefs.getKeys()) key: prefs.get(key)},
      {
        'bookInfoFollowCoverColor': false,
        'bookInfoNetworkCoverBackground': 'off',
        'bookInfoDefaultCoverBackground': 'off_for_default',
        'overrideBaseCardCornerRadius': true,
        'baseCardCornerRadius': 22,
        'enableBlur': true,
        'topBarBlurRadius': 32,
        'topBarBlurAlpha': 120,
        'bottomBarBlurRadius': 12,
        'bottomBarBlurAlpha': 90,
        'wallpaperColorFollow': true,
        'enableItemDivider': true,
        'themeStyle': 'fruitSalad',
        'themeContrastLevel': '0.5',
        'themeAmoled': true,
      },
    );
    final restoredService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(restoredService.dispose);
    expect(
      await AppUiSettingsRepository(restoredService).load(),
      repository.current,
    );
  });

  test('圆角、模糊半径与透明度保存限值沿用原规则', () async {
    final container = containerFor(service);
    final notifier = container.read(uiSettingsProvider.notifier);
    await notifier.load();
    await notifier.setBaseCardCornerRadius(-1);
    expect(container.read(uiSettingsProvider).baseCardCornerRadius, 4);
    await notifier.setBaseCardCornerRadius(100);
    await notifier.setTopBarBlur(radius: 90, alpha: -3);
    await notifier.setBottomBarBlur(radius: -2, alpha: 500);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('baseCardCornerRadius'), 28);
    expect(prefs.getInt('topBarBlurRadius'), 48);
    expect(prefs.getInt('topBarBlurAlpha'), 0);
    expect(prefs.getInt('bottomBarBlurRadius'), 0);
    expect(prefs.getInt('bottomBarBlurAlpha'), 255);
  });

  test('按钮、底栏标签和大屏模式的全部选项保持原编码', () async {
    final prefs = await SharedPreferences.getInstance();
    for (final style in TopBarButtonStyle.values) {
      await repository.update(topBarButtonStyle: style);
      expect(repository.current.topBarButtonStyle, style);
      expect(prefs.getString('topBarButtonStyle'), style.name);
    }
    for (final mode in BottomBarLabelMode.values) {
      await repository.update(labelVisibilityMode: mode);
      expect(repository.current.labelVisibilityMode, mode);
      expect(prefs.getString('labelVisibilityMode'), mode.name);
    }
    for (final mode in TabletInterfaceMode.values) {
      await repository.update(tabletInterface: mode);
      expect(repository.current.tabletInterface, mode);
      expect(prefs.getString('tabletInterface'), mode.name);
    }
  });

  test('透明度读取与保存均保留 0–100 范围规则', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('topBarOpacity', -10);
    await prefs.setInt('bottomBarOpacity', 120);
    await repository.load();
    expect(repository.current.topBarOpacity, 0);
    expect(repository.current.bottomBarOpacity, 100);
    expect(prefs.getInt('topBarOpacity'), -10);
    await repository.update(topBarOpacity: 130, bottomBarOpacity: -20);
    expect(prefs.getInt('topBarOpacity'), 100);
    expect(prefs.getInt('bottomBarOpacity'), 0);
  });

  test('未知枚举只回退展示，修改其他字段不重写它', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('topBarButtonStyle', 'unknown');
    await repository.load();
    expect(repository.current.topBarButtonStyle, TopBarButtonStyle.tonal);
    await repository.update(railExtended: true);
    expect(prefs.getString('topBarButtonStyle'), 'unknown');
  });

  test('Notifier 统一投影布局与主题，共享全部界面偏好', () async {
    final container = containerFor(service);
    final notifier = container.read(uiSettingsProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await notifier.setTopBarButtonStyle(TopBarButtonStyle.plain);
    await notifier.setBottomBarOpacity(85);
    await notifier.setTabletInterface(TabletInterfaceMode.always);
    await notifier.setRailExtended(true);
    await notifier.setThemeAmoled(true);
    final state = container.read(uiSettingsProvider);
    expect(state.topBarButtonStyle, TopBarButtonStyle.plain);
    expect(state.bottomBarOpacity, 85);
    expect(state.tabletInterface, TabletInterfaceMode.always);
    expect(state.railExtended, isTrue);
    expect(state.themeAmoled, isTrue);
    expect(repository.current.bottomBarOpacity, 85);
    expect(repository.current.themeAmoled, isTrue);
  });

  test('保存返回 false 传递错误并回退，重试可以成功', () async {
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
    final container = containerFor(checkedService);
    final notifier = container.read(uiSettingsProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final saving = notifier.setShowBottomView(false);
    expect(container.read(uiSettingsProvider).showBottomView, isFalse);
    await expectLater(saving, throwsStateError);
    expect(container.read(uiSettingsProvider).showBottomView, isTrue);
    when(() => prefs.setBool(any(), any())).thenAnswer((_) async => true);
    await notifier.setShowBottomView(false);
    expect(container.read(uiSettingsProvider).showBottomView, isFalse);
  });

  test('恢复后显式重读，更新当前布局快照', () async {
    final container = containerFor(service);
    final notifier = container.read(uiSettingsProvider.notifier);
    await repository.load();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useFloatingBottomBar', true);
    await prefs.setInt('bottomBarOpacity', 60);
    await prefs.setBool('enableBlur', true);
    await prefs.setString('themeStyle', 'expressive');
    await notifier.reload();
    expect(container.read(uiSettingsProvider).useFloatingBottomBar, isTrue);
    expect(container.read(uiSettingsProvider).bottomBarOpacity, 60);
    expect(container.read(uiSettingsProvider).enableBlur, isTrue);
    expect(container.read(uiSettingsProvider).themeStyle, 'expressive');
  });
}

class _Preferences extends Mock implements SharedPreferences {}
