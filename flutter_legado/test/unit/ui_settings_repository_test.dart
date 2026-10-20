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

  test('默认使用浮点材质参数，打开设置不写入存储', () async {
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

  test('布局参数按明确类型保存并从新仓储恢复', () async {
    await repository.update(
      topBarButtonStyle: TopBarButtonStyle.plain,
      mergeTopBarActions: true,
      useFlexibleTopAppBar: false,
      topBarBackgroundOpacity: 0.75,
      labelVisibilityMode: BottomBarLabelMode.labeled,
      bottomBarBackgroundOpacity: 0.8,
      useFloatingBottomBar: true,
      useFloatingBottomBarLiquidGlass: true,
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
        'topBarBackgroundOpacity': 0.75,
        'labelVisibilityMode': 'labeled',
        'bottomBarBackgroundOpacity': 0.8,
        'useFloatingBottomBar': true,
        'useFloatingBottomBarLiquidGlass': true,
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

  test('其他参数完整保存，模糊使用浮点比例和 sigma', () async {
    await repository.update(
      bookInfoFollowCoverColor: false,
      bookInfoNetworkCoverBackground: 'off',
      bookInfoDefaultCoverBackground: 'off_for_default',
      overrideBaseCardCornerRadius: true,
      baseCardCornerRadius: 22,
      enableBlur: true,
      topBarBlurSigma: 32,
      topBarBlurTintOpacity: 0.6,
      bottomBarBlurSigma: 12,
      bottomBarBlurTintOpacity: 0.35,
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
        'topBarBlurSigma': 32,
        'topBarBlurTintOpacity': 0.6,
        'bottomBarBlurSigma': 12,
        'bottomBarBlurTintOpacity': 0.35,
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

  test('圆角、模糊 sigma 与不透明度保存时规范范围', () async {
    final container = containerFor(service);
    final notifier = container.read(uiSettingsProvider.notifier);
    await notifier.load();
    await notifier.setBaseCardCornerRadius(-1);
    expect(container.read(uiSettingsProvider).baseCardCornerRadius, 4);
    await notifier.setBaseCardCornerRadius(100);
    await notifier.setTopBarBlur(sigma: 90, tintOpacity: -3);
    await notifier.setBottomBarBlur(sigma: -2, tintOpacity: 5);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('baseCardCornerRadius'), 28);
    expect(prefs.getDouble('topBarBlurSigma'), 48);
    expect(prefs.getDouble('topBarBlurTintOpacity'), 0);
    expect(prefs.getDouble('bottomBarBlurSigma'), 0);
    expect(prefs.getDouble('bottomBarBlurTintOpacity'), 1.0);
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

  test('背景不透明度读取与保存均限制在 0–1', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('topBarBackgroundOpacity', -10);
    await prefs.setDouble('bottomBarBackgroundOpacity', 120);
    await repository.load();
    expect(repository.current.topBarBackgroundOpacity, 0);
    expect(repository.current.bottomBarBackgroundOpacity, 1.0);
    expect(prefs.getDouble('topBarBackgroundOpacity'), -10);
    await repository.update(
      topBarBackgroundOpacity: 130,
      bottomBarBackgroundOpacity: -20,
    );
    expect(prefs.getDouble('topBarBackgroundOpacity'), 1.0);
    expect(prefs.getDouble('bottomBarBackgroundOpacity'), 0);
  });

  test('读取越界和非有限材质参数使用与保存一致的规范', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('topBarBlurSigma', -4);
    await prefs.setDouble('bottomBarBlurSigma', double.infinity);
    await prefs.setDouble('topBarBlurTintOpacity', 2);
    await prefs.setDouble('bottomBarBlurTintOpacity', double.nan);
    await prefs.setInt('baseCardCornerRadius', 200);
    final loaded = await repository.load();
    expect(loaded.topBarBlurSigma, 0);
    expect(loaded.bottomBarBlurSigma, 8);
    expect(loaded.topBarBlurTintOpacity, 1);
    expect(loaded.bottomBarBlurTintOpacity, 0.4);
    expect(loaded.baseCardCornerRadius, 28);
    await repository.update(
      topBarBackgroundOpacity: double.nan,
      bottomBarBackgroundOpacity: double.infinity,
      topBarBlurSigma: double.nan,
      bottomBarBlurSigma: -4,
      topBarBlurTintOpacity: double.infinity,
      bottomBarBlurTintOpacity: -1,
    );
    expect(prefs.getDouble('topBarBackgroundOpacity'), 1);
    expect(prefs.getDouble('bottomBarBackgroundOpacity'), 1);
    expect(prefs.getDouble('topBarBlurSigma'), 24);
    expect(prefs.getDouble('bottomBarBlurSigma'), 0);
    expect(prefs.getDouble('topBarBlurTintOpacity'), 0.73);
    expect(prefs.getDouble('bottomBarBlurTintOpacity'), 0);
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
    await notifier.setUseFloatingBottomBarLiquidGlass(true);
    await notifier.setBottomBarBackgroundOpacity(0.85);
    await notifier.setTabletInterface(TabletInterfaceMode.always);
    await notifier.setRailExtended(true);
    await notifier.setThemeAmoled(true);
    final state = container.read(uiSettingsProvider);
    expect(state.topBarButtonStyle, TopBarButtonStyle.plain);
    expect(state.useFloatingBottomBarLiquidGlass, isTrue);
    expect(state.enableBlur, isFalse);
    expect(
      state.copyWith(useFloatingBottomBarLiquidGlass: false),
      isNot(state),
    );
    expect(state.bottomBarBackgroundOpacity, 0.85);
    expect(state.tabletInterface, TabletInterfaceMode.always);
    expect(state.railExtended, isTrue);
    expect(state.themeAmoled, isTrue);
    expect(repository.current.bottomBarBackgroundOpacity, 0.85);
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
    await prefs.setDouble('bottomBarBackgroundOpacity', 0.6);
    await prefs.setBool('enableBlur', true);
    await prefs.setString('themeStyle', 'expressive');
    await notifier.reload();
    expect(container.read(uiSettingsProvider).useFloatingBottomBar, isTrue);
    expect(container.read(uiSettingsProvider).bottomBarBackgroundOpacity, 0.6);
    expect(container.read(uiSettingsProvider).enableBlur, isTrue);
    expect(container.read(uiSettingsProvider).themeStyle, 'expressive');
  });
}

class _Preferences extends Mock implements SharedPreferences {}
