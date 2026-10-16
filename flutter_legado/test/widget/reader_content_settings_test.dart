import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/reader/reader_settings_provider.dart';
import 'package:flutter_legado/src/screens/reader_config_panel.dart';
import 'package:flutter_legado/src/widgets/reader/reader_settings_sheet.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late ProviderContainer container;
  Future<void> initialize(WidgetTester tester) async {
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ReaderSettingsSheet(
            fullPage: true,
            category: ReaderSettingsCategory.content,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    storage.writes.clear();
  }

  testWidgets('自动换源开关保存失败回退，重试和外部重读同源', (tester) async {
    await initialize(tester);
    final repo = container.read(readerSettingsRepositoryProvider);
    Future<void> toggle() async {
      await tester.tap(find.text('自动换源'));
      await tester.pumpAndSettle();
    }

    await toggle();
    expect(repo.current.autoChangeSource, isFalse);
    expect(storage.writes, [('reader_auto_change_source', false)]);
    storage.writeFailure = true;
    await toggle();
    expect(find.text('自动换源设置保存失败，请重试'), findsOneWidget);
    expect(repo.current.autoChangeSource, isFalse);
    final row = find.byWidgetPredicate(
      (w) => w is SettingSwitchRow && w.title == '自动换源',
    );
    expect(
      tester
          .widget<Switch>(
            find.descendant(of: row, matching: find.byType(Switch)),
          )
          .value,
      isFalse,
    );
    storage.writeFailure = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await toggle();
    expect(repo.current.autoChangeSource, isTrue);
    storage.values['reader_auto_change_source'] = false;
    await repo.reload();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Switch>(
            find.descendant(of: row, matching: find.byType(Switch)),
          )
          .value,
      isFalse,
    );
    expect(storage.values.containsKey('autoChangeSource'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('标题附加区显示共享保存值及待实现说明，控件保持禁用', (tester) async {
    await initialize(tester);
    final repo = container.read(readerSettingsRepositoryProvider);
    await repo.update(showTitleAddition: false);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ReaderConfigPanel(section: ReaderConfigSection.toolbar),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byWidgetPredicate(
      (w) => w is SettingSwitchRow && w.title == '显示标题附加区',
    );
    final setting = tester.widget<SettingSwitchRow>(row);
    expect(setting.value, isFalse);
    expect(setting.onChanged, isNull);
    expect(setting.subtitle, '书名后追加章节名（待实现）');
    storage.writes.clear();
    await tester.tap(find.text('显示标题附加区'));
    await tester.pumpAndSettle();
    expect(storage.writes, isEmpty);
    storage.values['reader_show_title_addition'] = true;
    await repo.reload();
    await tester.pumpAndSettle();
    expect(tester.widget<SettingSwitchRow>(row).value, isTrue);
    expect(tester.takeException(), isNull);
  });
}
