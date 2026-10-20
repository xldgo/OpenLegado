import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/presentation/font_screen.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_settings_sheet.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late ProviderContainer container;

  void initialize() {
    SharedPreferences.setMockInitialValues({});
    storage = HomeSettingsStorage()
      ..values.addAll({
        'reader_font_family': 'SimSun',
        'reader_title_font_family': 'KaiTi',
      });
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    container = ProviderContainer(
      overrides: [appSettingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(() {
      container.dispose();
      unawaited(service.dispose());
    });
  }

  Future<void> show(WidgetTester tester, String target) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: FontScreen(key: ValueKey(target), target: target),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapFont(WidgetTester tester, String label) async {
    final scrollable = find.byType(Scrollable).last;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text(label),
      120,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('正文和标题选择写入各自键，默认正文删除键、默认标题跟随正文', (tester) async {
    initialize();
    await show(tester, 'body');
    expect(find.text('当前字体：宋体'), findsOneWidget);
    await tapFont(tester, '楷体');
    expect(storage.values['reader_font_family'], 'KaiTi');
    expect(storage.values['reader_title_font_family'], 'KaiTi');
    await tapFont(tester, '默认字体');
    expect(storage.values['reader_font_family'], isNull);
    expect(
      container.read(readerSettingsRepositoryProvider).current.fontFamily,
      isNull,
    );
    await show(tester, 'title');
    expect(find.text('当前标题字体：楷体'), findsOneWidget);
    await tapFont(tester, '宋体');
    expect(storage.values['reader_title_font_family'], 'SimSun');
    expect(storage.values['reader_font_family'], isNull);
    await tapFont(tester, '默认字体');
    expect(storage.values['reader_title_font_family'], '');
    expect(find.text('当前标题字体：跟随正文'), findsOneWidget);
    expect(storage.values.containsKey('titleFont'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('字体选择失败回退预览和显示，重试保存并通知其他字体控件', (tester) async {
    initialize();
    await show(tester, 'title');
    storage.writeFailure = true;
    await tapFont(tester, '宋体');
    expect(find.text('字体选择保存失败，请重试'), findsOneWidget);
    expect(find.text('当前标题字体：楷体'), findsOneWidget);
    expect(storage.values['reader_title_font_family'], 'KaiTi');
    storage.writeFailure = false;
    await tapFont(tester, '宋体');
    expect(find.text('当前标题字体：宋体'), findsOneWidget);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: ReaderFontPanel(titleOnly: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SimSun'), findsOneWidget);
    await container
        .read(readerSettingsRepositoryProvider)
        .update(titleFontFamily: 'Georgia');
    await tester.pumpAndSettle();
    expect(find.text('Georgia'), findsOneWidget);
    expect(find.text('SimSun'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
