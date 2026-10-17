import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_config_panel.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late ProviderContainer container;

  Future<void> mount(
    WidgetTester tester, {
    ReaderConfigSection section = ReaderConfigSection.menuTheme,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReaderConfigPanel(key: UniqueKey(), section: section),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> initialize(
    WidgetTester tester, {
    ReaderConfigSection section = ReaderConfigSection.menuTheme,
  }) async {
    SharedPreferences.setMockInitialValues({});
    storage = HomeSettingsStorage();
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        appSettingsServiceProvider.overrideWithValue(service),
      ]),
    );
    addTearDown(() {
      container.dispose();
      unawaited(service.dispose());
    });
    await container.read(readerSettingsRepositoryProvider).load();
    await mount(tester, section: section);
    storage.writes.clear();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String title, String option) async {
    await tap(
      tester,
      find.byWidgetPredicate((w) => w is SettingMenuRow && w.title == title),
    );
    await tap(tester, find.text(option).hitTestable().last);
  }

  Future<void> color(
    WidgetTester tester,
    String title,
    String hex, {
    bool useDefault = false,
  }) async {
    await tap(
      tester,
      find.byWidgetPredicate((w) => w is SettingTile && w.title == title),
    );
    final dialog = find.byType(AlertDialog);
    if (!useDefault) {
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        hex,
      );
    }
    final confirm = useDefault
        ? '默认'
        : MaterialLocalizations.of(tester.element(dialog)).okButtonLabel;
    await tap(
      tester,
      find.descendant(of: dialog, matching: find.text(confirm)),
    );
  }

  testWidgets('菜单来源、调色板和生成方式独立保存并响应外部恢复', (tester) async {
    await initialize(tester);
    final repo = container.read(readerSettingsRepositoryProvider);
    await choose(tester, '菜单配色', '跟随阅读背景');
    await choose(tester, '菜单配色风格', '鲜艳');
    expect(repo.current.menuTheme.mode, 1);
    expect(repo.current.menuTheme.paletteStyle, 'vibrant');
    await choose(tester, '菜单配色', '自定义');
    await choose(tester, '自定义方式', '分别指定颜色');
    expect(repo.current.menuTheme.colorMode, 1);
    expect(find.text('菜单背景'), findsOneWidget);
    expect(storage.writes.map((w) => w.$1).toSet(), {
      'reader_menu_theme_mode',
      'reader_menu_palette_style',
      'reader_menu_color_mode',
    });
    storage.values['reader_menu_theme_mode'] = 0;
    await repo.reload();
    await tester.pumpAndSettle();
    expect(find.text('菜单配色风格'), findsNothing);
    expect(find.text('菜单背景'), findsNothing);
    expect(find.text('顶栏文字颜色'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('八项日夜颜色分别编辑，编辑模式不落盘且重新打开跟随当前主题', (tester) async {
    await initialize(tester);
    final repo = container.read(readerSettingsRepositoryProvider);
    await repo.updateMenuTheme(mode: 2, colorMode: 1);
    await tester.pumpAndSettle();
    storage.writes.clear();
    for (final entry in {
      '菜单主色': '112233',
      '菜单背景': 'f0e0d0',
      '弹层背景': 'e0d0c0',
      '顶栏文字颜色': '010203',
    }.entries) {
      await color(tester, entry.key, entry.value);
    }
    final day = repo.current.menuTheme;
    storage.writes.clear();
    await choose(tester, '编辑配色', '深色模式');
    expect(storage.writes, isEmpty);
    for (final entry in {
      '菜单主色': 'abcdef',
      '菜单背景': '121212',
      '弹层背景': '242424',
      '顶栏文字颜色': 'fafbfc',
    }.entries) {
      await color(tester, entry.key, entry.value);
    }
    final both = repo.current.menuTheme;
    expect(both.accentColor, day.accentColor);
    expect(both.backgroundColor, day.backgroundColor);
    expect(both.containerColor, day.containerColor);
    expect(both.textColor, day.textColor);
    expect(both.accentColorNight, 0xffabcdef);
    expect(both.backgroundColorNight, 0xff121212);
    expect(both.containerColorNight, 0xff242424);
    expect(both.textColorNight, 0xfffafbfc);
    expect(storage.writes.map((w) => w.$1).toSet(), {
      'reader_menu_accent_color_night',
      'reader_menu_background_color_night',
      'reader_menu_container_color_night',
      'reader_menu_text_color_night',
    });
    await mount(tester);
    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('#FF010203'), findsOneWidget);
    await color(tester, '顶栏文字颜色', '', useDefault: true);
    expect(repo.current.menuTheme.textColor, 0);
    expect(repo.current.menuTheme.textColorNight, 0xfffafbfc);
    expect(tester.takeException(), isNull);
  });

  testWidgets('配色选择和颜色保存失败回退，可重试且不覆盖其他字段', (tester) async {
    await initialize(tester);
    final repo = container.read(readerSettingsRepositoryProvider);
    storage.writeFailure = true;
    await choose(tester, '菜单配色', '自定义');
    expect(find.text('菜单设置保存失败，请重试'), findsOneWidget);
    expect(repo.current.menuTheme.mode, 0);
    expect(find.text('自定义方式'), findsNothing);
    storage.writeFailure = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await choose(tester, '菜单配色', '自定义');
    await repo.updateMenuTheme(textColorNight: 0xffabcdef);
    storage.writeFailure = true;
    await color(tester, '顶栏文字颜色', '123456');
    expect(find.text('菜单设置保存失败，请重试'), findsOneWidget);
    expect(repo.current.menuTheme.textColor, 0);
    storage.writeFailure = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await color(tester, '顶栏文字颜色', '123456');
    expect(repo.current.menuTheme.textColor, 0xff123456);
    expect(repo.current.menuTheme.textColorNight, 0xffabcdef);
    expect(repo.current.menuTheme.mode, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('亮度控件四个选项同源，关闭和横向保留侧栏位置，失败可重试', (tester) async {
    await initialize(tester, section: ReaderConfigSection.toolbar);
    final repo = container.read(readerSettingsRepositoryProvider);
    await choose(tester, '亮度控件', '纵向·左侧');
    expect(repo.current.brightnessControl.mode, 2);
    expect(repo.current.brightnessControl.onLeft, isTrue);
    await choose(tester, '亮度控件', '关闭');
    expect(repo.current.brightnessControl.mode, 0);
    expect(repo.current.brightnessControl.onLeft, isTrue);
    await choose(tester, '亮度控件', '横向');
    expect(repo.current.brightnessControl.mode, 1);
    expect(repo.current.brightnessControl.onLeft, isTrue);
    storage.writeFailure = true;
    await choose(tester, '亮度控件', '纵向·右侧');
    expect(find.text('菜单设置保存失败，请重试'), findsOneWidget);
    expect(repo.current.brightnessControl.mode, 1);
    expect(repo.current.brightnessControl.onLeft, isTrue);
    storage.writeFailure = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await choose(tester, '亮度控件', '纵向·右侧');
    expect(repo.current.brightnessControl.mode, 2);
    expect(repo.current.brightnessControl.onLeft, isFalse);
    expect(storage.writes.map((w) => w.$1).toSet(), {
      'reader_brightness_control_mode',
      'reader_brightness_control_on_left',
    });
    expect(tester.takeException(), isNull);
  });
}
