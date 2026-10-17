import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_settings_sheet.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late ProviderContainer container;

  Future<void> initialize(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'reader_font_size': 22.0,
      'reader_line_height': 1.8,
    });
    storage = HomeSettingsStorage()
      ..values.addAll({'reader_font_size': 22.0, 'reader_line_height': 1.8});
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
    const brightness = MethodChannel('github.com/aaassseee/screen_brightness');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(brightness, (_) async {
      throw PlatformException(code: 'unsupported');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(brightness, null));
    await container.read(readerSettingsRepositoryProvider).load();
  }

  Future<void> show(WidgetTester tester, {bool fullPage = false}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: fullPage
              ? const ReaderSettingsSheet(
                  fullPage: true,
                  category: ReaderSettingsCategory.typography,
                )
              : const Scaffold(
                  body: SingleChildScrollView(child: ReaderSettingsSheet()),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('字号保存失败提示并回退，重试写入原键', (tester) async {
    await initialize(tester);
    await show(tester);
    storage.writeFailure = true;
    final plus = find.byTooltip('增大字号');
    await tester.ensureVisible(plus);
    await tester.tap(plus);
    await tester.pumpAndSettle();
    expect(find.text('阅读排版保存失败，请重试'), findsOneWidget);
    expect(container.read(readerNotifierProvider).fontSize, 22);
    expect(
      tester.widget<SettingStepperRow>(find.byType(SettingStepperRow)).value,
      22,
    );
    expect(storage.values['reader_font_size'], 22);
    storage.writeFailure = false;
    await tester.tap(plus);
    await tester.pumpAndSettle();
    expect(container.read(readerNotifierProvider).fontSize, 23);
    expect(storage.values['reader_font_size'], 23);
    expect(storage.values['reader_line_height'], 1.8);
    expect(tester.takeException(), isNull);
  });

  Finder lineHeightSlider() => find.byWidgetPredicate(
    (widget) => widget is Slider && widget.min == 1 && widget.max == 3,
  );

  testWidgets('快捷与完整字体设置同步，字号和行距独立保存', (tester) async {
    await initialize(tester);
    await show(tester);
    final plus = find.byTooltip('增大字号');
    await tester.ensureVisible(plus);
    await tester.tap(plus);
    await tester.pumpAndSettle();
    await show(tester, fullPage: true);
    expect(container.read(readerNotifierProvider).fontSize, 23);
    expect(tester.widget<Slider>(lineHeightSlider()).value, 1.8);
    tester.widget<Slider>(lineHeightSlider()).onChanged!(2.15);
    await tester.pumpAndSettle();
    expect(storage.values['reader_line_height'], 2.15);
    expect(storage.values['reader_font_size'], 23);
    await show(tester);
    expect(
      tester.widget<SettingStepperRow>(find.byType(SettingStepperRow)).value,
      23,
    );
    expect(container.read(readerNotifierProvider).lineHeight, 2.15);
    expect(tester.takeException(), isNull);
  });

  testWidgets('行距失败回退且可重试，恢复重读刷新完整设置控件', (tester) async {
    await initialize(tester);
    await show(tester, fullPage: true);
    storage.writeFailure = true;
    tester.widget<Slider>(lineHeightSlider()).onChanged!(2.1);
    await tester.pumpAndSettle();
    expect(find.text('阅读排版保存失败，请重试'), findsOneWidget);
    expect(container.read(readerNotifierProvider).lineHeight, 1.8);
    expect(tester.widget<Slider>(lineHeightSlider()).value, 1.8);
    expect(storage.values['reader_line_height'], 1.8);
    storage.writeFailure = false;
    tester.widget<Slider>(lineHeightSlider()).onChanged!(2.1);
    await tester.pumpAndSettle();
    expect(storage.values['reader_line_height'], 2.1);
    storage.values.addAll({
      'reader_font_size': 26.0,
      'reader_line_height': 2.4,
    });
    await container.read(readerSettingsRepositoryProvider).reload();
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(lineHeightSlider()).value, 2.4);
    expect(container.read(readerNotifierProvider).fontSize, 26);
    expect(tester.takeException(), isNull);
  });
}
