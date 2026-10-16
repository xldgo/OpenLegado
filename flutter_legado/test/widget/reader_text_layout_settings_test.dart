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

import '../fixtures/home_settings_storage.dart';

void main() {
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late ProviderContainer container;

  Future<void> initialize(WidgetTester tester, {bool fullPage = true}) async {
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: fullPage
                ? const ReaderSettingsSheet(
                    fullPage: true,
                    category: ReaderSettingsCategory.typography,
                  )
                : SingleChildScrollView(
                    child: ReaderConfigPanel(
                      section: ReaderConfigSection.typography,
                    ),
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 启动已完成的样式初始化不属于本次控件保存。
    storage.writes.clear();
  }

  Finder slider(double min, double max) => find.byWidgetPredicate(
    (widget) => widget is Slider && widget.min == min && widget.max == max,
  );

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('字体与中文排版控件保存八项，并保持彼此值', (tester) async {
    await initialize(tester);
    expect(tester.widget<Slider>(slider(-0.5, 1)).value, 0);
    tester.widget<Slider>(slider(-0.5, 1)).onChanged!(0.24);
    await tester.pumpAndSettle();
    tester.widget<Slider>(slider(0, 48)).onChanged!(12);
    await tester.pumpAndSettle();
    await tap(tester, '粗体');
    await tap(tester, '斜体');
    await tap(tester, '首行缩进');
    await tap(tester, '三字符');
    await tap(tester, '两端对齐');
    await tap(tester, '中文优化分行');
    expect(find.text('段首标点悬挂'), findsOneWidget);
    await tap(tester, '段首标点悬挂');
    final layout = container
        .read(readerSettingsRepositoryProvider)
        .current
        .textLayout;
    expect(layout.letterSpacing, 0.24);
    expect(layout.paragraphSpacing, 12);
    expect(layout.paragraphIndent, 3);
    expect(layout.textBold, 1);
    expect(layout.italic, isTrue);
    expect(layout.textFullJustify, isFalse);
    expect(layout.useZhLayout, isTrue);
    expect(layout.hangingPunctuation, isTrue);
    expect(storage.writes.map((entry) => entry.$1).toSet(), {
      'reader_letter_spacing',
      'reader_paragraph_spacing',
      'reader_paragraph_indent',
      'reader_text_bold',
      'reader_italic',
      'reader_text_full_justify',
      'reader_use_zh_layout',
      'reader_hanging_punctuation',
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('字体面板保存失败回退、提示并可重试，外部恢复刷新控件', (tester) async {
    await initialize(tester);
    storage.writeFailure = true;
    tester.widget<Slider>(slider(-0.5, 1)).onChanged!(0.4);
    await tester.pumpAndSettle();
    expect(find.text('阅读排版保存失败，请重试'), findsOneWidget);
    expect(tester.widget<Slider>(slider(-0.5, 1)).value, 0);
    expect(storage.values.containsKey('reader_letter_spacing'), isFalse);
    storage.writeFailure = false;
    tester.widget<Slider>(slider(-0.5, 1)).onChanged!(0.4);
    await tester.pumpAndSettle();
    expect(storage.values['reader_letter_spacing'], 0.4);
    storage.values.addAll({
      'reader_letter_spacing': -0.2,
      'reader_paragraph_spacing': 15.0,
    });
    await container.read(readerSettingsRepositoryProvider).reload();
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(slider(-0.5, 1)).value, -0.2);
    expect(tester.widget<Slider>(slider(0, 48)).value, 15);
    expect(tester.takeException(), isNull);
  });

  testWidgets('中文排版面板失败回退，重试与其他入口共享值', (tester) async {
    await initialize(tester, fullPage: false);
    storage.writeFailure = true;
    await tap(tester, '中文优化分行');
    expect(find.text('阅读排版保存失败，请重试'), findsOneWidget);
    expect(find.text('段首标点悬挂'), findsNothing);
    expect(
      container
          .read(readerSettingsRepositoryProvider)
          .current
          .textLayout
          .useZhLayout,
      isFalse,
    );
    storage.writeFailure = false;
    await tap(tester, '中文优化分行');
    await tap(tester, '段首标点悬挂');
    await container
        .read(readerSettingsRepositoryProvider)
        .updateScreen(keepScreenOnSeconds: 60);
    expect(storage.values['reader_use_zh_layout'], isTrue);
    expect(storage.values['reader_hanging_punctuation'], isTrue);
    expect(tester.takeException(), isNull);
  });
}
