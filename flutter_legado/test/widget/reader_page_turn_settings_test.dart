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
import 'package:flutter_legado/src/providers/reader/reader_notifier.dart';
import 'package:flutter_legado/src/providers/reader/reader_settings_provider.dart';
import 'package:flutter_legado/src/screens/reader_config_panel.dart';
import 'package:flutter_legado/src/widgets/reader/reader_settings_sheet.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late ProviderContainer container;

  void initialize() {
    SharedPreferences.setMockInitialValues({});
    storage = HomeSettingsStorage();
    storage.values.addAll({
      'reader_flip_mode_name': 'cover',
      'reader_flip_mode': 1,
      'flip_mode': 0,
    });
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        appSettingsServiceProvider.overrideWithValue(service),
      ]),
    );
    const channel = MethodChannel('github.com/aaassseee/screen_brightness');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unsupported');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  tearDown(() {
    container.dispose();
    unawaited(service.dispose());
  });

  Finder quickSelector() => find.byType(SettingMenuRow<PageTurnMode>);
  Finder advancedSelector() => find.byType(SegmentedButton<PageTurnMode>);

  Future<void> showQuick(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ReaderSettingsSheet()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> showAdvanced(WidgetTester tester) async {
    await container.read(readerSettingsRepositoryProvider).load();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: const ReaderConfigPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectQuick(WidgetTester tester, String label) async {
    await tester.ensureVisible(quickSelector());
    await tester.tap(
      find.descendant(of: quickSelector(), matching: find.text('翻页动画')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('快捷与高级入口互相同步，正文采用同一模式，保留原有效选择', (tester) async {
    initialize();
    await showQuick(tester);
    storage.writes.clear();
    expect(
      tester.widget<SettingMenuRow<PageTurnMode>>(quickSelector()).value,
      PageTurnMode.cover,
    );
    await selectQuick(tester, '仿真');
    expect(
      container.read(readerNotifierProvider).pageTurnMode,
      PageTurnMode.simulate,
    );
    await showAdvanced(tester);
    expect(
      tester.widget<SegmentedButton<PageTurnMode>>(advancedSelector()).selected,
      {PageTurnMode.simulate},
    );
    await tester.tap(
      find.descendant(of: advancedSelector(), matching: find.text('滚动')),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(readerNotifierProvider).pageTurnMode,
      PageTurnMode.scroll,
    );
    await showQuick(tester);
    expect(
      tester.widget<SettingMenuRow<PageTurnMode>>(quickSelector()).value,
      PageTurnMode.scroll,
    );
    expect(storage.values['reader_flip_mode_name'], 'scroll');
    expect(storage.values['reader_flip_mode'], 1);
    expect(storage.values['flip_mode'], 0);
    expect(storage.writes.map((entry) => entry.$1).toSet(), {
      'reader_flip_mode_name',
    });
  });

  testWidgets('快捷入口保存失败提示并回退，重试及恢复重读影响实际正文模式', (tester) async {
    initialize();
    await showQuick(tester);
    storage.writeFailure = true;
    await selectQuick(tester, '滑动');
    expect(find.text('翻页模式保存失败，请重试'), findsOneWidget);
    expect(
      container.read(readerNotifierProvider).pageTurnMode,
      PageTurnMode.cover,
    );
    expect(
      tester.widget<SettingMenuRow<PageTurnMode>>(quickSelector()).value,
      PageTurnMode.cover,
    );
    storage.writeFailure = false;
    await selectQuick(tester, '滑动');
    expect(
      container.read(readerNotifierProvider).pageTurnMode,
      PageTurnMode.slide,
    );
    storage.values['reader_flip_mode_name'] = 'none';
    await container.read(readerSettingsRepositoryProvider).reload();
    await tester.pumpAndSettle();
    expect(
      container.read(readerNotifierProvider).pageTurnMode,
      PageTurnMode.none,
    );
    expect(
      tester.widget<SettingMenuRow<PageTurnMode>>(quickSelector()).value,
      PageTurnMode.none,
    );
  });

  testWidgets('高级入口失败回退，可选全部五种模式；其他配置保存不恢复旧模式', (tester) async {
    initialize();
    await showAdvanced(tester);
    storage.writeFailure = true;
    await tester.tap(
      find.descendant(of: advancedSelector(), matching: find.text('滑动')),
    );
    await tester.pumpAndSettle();
    expect(find.text('翻页模式保存失败，请重试'), findsOneWidget);
    expect(
      tester.widget<SegmentedButton<PageTurnMode>>(advancedSelector()).selected,
      {PageTurnMode.cover},
    );
    storage.writeFailure = false;
    for (final mode in const [
      PageTurnMode.scroll,
      PageTurnMode.none,
      PageTurnMode.simulate,
      PageTurnMode.slide,
      PageTurnMode.cover,
    ]) {
      await tester.tap(
        find.descendant(
          of: advancedSelector(),
          matching: find.text(mode.displayName),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(readerNotifierProvider).pageTurnMode, mode);
      expect(storage.values['reader_flip_mode_name'], mode.name);
    }
    await tester.tap(find.text('启用自动翻页'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(readerSettingsRepositoryProvider)
          .current
          .autoPageTurn
          .enabled,
      isTrue,
    );
    expect(
      container.read(readerNotifierProvider).pageTurnMode,
      PageTurnMode.cover,
    );
    expect(
      (await SharedPreferences.getInstance()).containsKey('flip_mode'),
      isFalse,
    );
  });
}
