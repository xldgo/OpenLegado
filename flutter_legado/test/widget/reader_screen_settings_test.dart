import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_settings_sheet.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late ProviderContainer container;

  Future<void> initialize(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'keep_light': 300});
    const channel = MethodChannel('github.com/aaassseee/screen_brightness');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      _,
    ) async {
      throw PlatformException(code: 'unsupported');
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    storage = HomeSettingsStorage();
    storage.values['reader_keep_screen_on_seconds'] = 300;
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ReaderSettingsSheet(
            fullPage: true,
            category: ReaderSettingsCategory.screen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    storage.writes.clear();
  }

  Future<void> tap(WidgetTester tester, String title) async {
    final target = find.text(title).hitTestable();
    final finder = target.evaluate().isNotEmpty ? target : find.text(title);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester, String title) => tester
      .widget<Switch>(
        find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget is SettingSwitchRow && widget.title == title,
          ),
          matching: find.byType(Switch),
        ),
      )
      .value;

  testWidgets('屏幕方向、系统栏和刘海避让逐字段保存', (tester) async {
    await initialize(tester);
    final repository = container.read(readerSettingsRepositoryProvider);
    final before = repository.current.pageLayout;
    await tap(tester, '屏幕方向');
    await tap(tester, '横屏');
    await tap(tester, '隐藏状态栏');
    await tap(tester, '隐藏导航栏');
    expect(find.text('页眉页脚延伸至屏幕边缘'), findsNothing);
    await tap(tester, '刘海避让');
    expect(switchValue(tester, '页眉页脚延伸至屏幕边缘'), isFalse);
    await tap(tester, '页眉页脚延伸至屏幕边缘');
    await tap(tester, '刘海避让');
    expect(find.text('页眉页脚延伸至屏幕边缘'), findsNothing);
    expect(repository.current.screen.extendPageTips, isTrue);
    await tap(tester, '刘海避让');
    expect(switchValue(tester, '页眉页脚延伸至屏幕边缘'), isTrue);
    expect(repository.current.screen.orientation, 2);
    expect(repository.current.screen.hideStatusBar, isTrue);
    expect(repository.current.screen.hideNavigationBar, isTrue);
    expect(repository.current.screen.avoidDisplayCutouts, isTrue);
    expect(repository.current.pageLayout, before);
    expect(storage.values['reader_screen_orientation'], 2);
    expect(storage.writes.map((entry) => entry.$1).toSet(), {
      'reader_screen_orientation',
      'reader_hide_status_bar',
      'reader_hide_navigation_bar',
      'reader_avoid_display_cutouts',
      'reader_extend_page_tips',
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('屏幕设置保存失败控件回退，重试及外部恢复同源', (tester) async {
    await initialize(tester);
    storage.writeFailure = true;
    await tap(tester, '隐藏状态栏');
    expect(find.text('屏幕设置保存失败，请重试'), findsOneWidget);
    expect(switchValue(tester, '隐藏状态栏'), isFalse);
    storage.writeFailure = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(tester, '隐藏状态栏');
    expect(switchValue(tester, '隐藏状态栏'), isTrue);
    storage.values.addAll({
      'reader_hide_status_bar': false,
      'reader_screen_orientation': 4,
    });
    await container.read(readerSettingsRepositoryProvider).reload();
    await tester.pumpAndSettle();
    expect(switchValue(tester, '隐藏状态栏'), isFalse);
    final row = tester.widget<SettingMenuRow<int>>(
      find.byWidgetPredicate(
        (w) => w is SettingMenuRow<int> && w.title == '屏幕方向',
      ),
    );
    expect(row.value, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('屏幕设置不再提供独立阅读状态条，系统栏选项保留', (tester) async {
    await initialize(tester);
    expect(find.text('阅读状态条'), findsNothing);
    for (final title in ['显示电量', '显示时间', '显示进度', '显示章节名']) {
      expect(find.text(title), findsNothing);
    }
    expect(find.text('隐藏状态栏'), findsOneWidget);
    expect(find.text('隐藏导航栏'), findsOneWidget);
    expect(find.text('刘海避让'), findsOneWidget);
    expect(find.text('扩展到刘海'), findsNothing);
    expect(find.text('填充刘海区域'), findsNothing);
    expect(find.text('菜单工具栏'), findsOneWidget);
  });

  testWidgets('保持亮屏选择原地保存，默认选项解除防休眠', (tester) async {
    await initialize(tester);
    final row = tester.widget<SettingMenuRow<int>>(
      find.byWidgetPredicate(
        (w) => w is SettingMenuRow<int> && w.title == '保持亮屏',
      ),
    );
    expect(row.value, 300);
    expect(row.options.keys, [0, 60, 300, 600, -1]);
    expect(row.onChanged, isNotNull);
    await tap(tester, '保持亮屏');
    await tap(tester, '常亮');
    expect(
      container
          .read(readerSettingsRepositoryProvider)
          .current
          .screen
          .keepScreenOnSeconds,
      -1,
    );
    expect(storage.values['reader_keep_screen_on_seconds'], -1);
    await tap(tester, '保持亮屏');
    await tap(tester, '默认');
    expect(
      container
          .read(readerSettingsRepositoryProvider)
          .current
          .screen
          .keepScreenOnSeconds,
      0,
    );
    expect(storage.values['reader_keep_screen_on_seconds'], 0);
    expect((await SharedPreferences.getInstance()).getInt('keep_light'), 300);
    expect(tester.takeException(), isNull);
  });
}
