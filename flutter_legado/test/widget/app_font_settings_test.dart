import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_reader_font_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/features/appearance/app_font_provider.dart';
import 'package:flutter_legado/src/features/appearance/theme_config_screen.dart';
import 'package:flutter_legado/src/features/appearance/widgets/app_font_sheet.dart';
import 'package:flutter_legado/src/features/reader/presentation/views/reader_content_viewport.dart';
import 'package:flutter_legado/src/platform/app_font_picker.dart';
import 'package:flutter_legado/src/domain/contracts/font_catalog.dart';
import 'package:flutter_legado/src/domain/models/reader_font.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/font_catalog_provider.dart';
import 'package:flutter_legado/src/providers/theme/app_theme_preferences_provider.dart';
import 'package:flutter_legado/src/theme/app_theme_resolver.dart';

import '../fixtures/theme_settings_storage.dart';

class _Picker extends AppFontPicker {
  @override
  Future<({String name, Uint8List bytes})?> pick() async =>
      (name: '测试字体.ttf', bytes: Uint8List.fromList([1, 2, 3]));
}

class _Catalog implements FontCatalog {
  _Catalog(this.repository);
  final AppReaderFontRepository repository;
  @override
  Future<({List<ReaderFont> fonts, List<String> missing})>
  loadAvailable() async =>
      (fonts: await repository.load(), missing: <String>[]);
  @override
  Future<String?> loadFamily(String family) async {
    if (family.isEmpty) return null;
    if ((await repository.load()).any((font) => font.family == family)) {
      return family;
    }
    throw StateError('测试字体不存在');
  }

  @override
  Future<ReaderFont> importFont(String name, Uint8List bytes) async {
    const font = ReaderFont(family: 'Custom_测试字体', path: 'fonts/test.ttf');
    await repository.add(font);
    return font;
  }
}

void main() {
  late ThemeSettingsStorage storage;
  late ProviderContainer container;
  late AppSettingsService service;
  late AppReaderFontRepository catalog;

  void initialize() {
    SharedPreferences.setMockInitialValues({});
    storage = ThemeSettingsStorage({'reader_font_family': 'ReaderOnly'});
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    catalog = AppReaderFontRepository();
    container = ProviderContainer(
      overrides: [
        appSettingsServiceProvider.overrideWithValue(service),
        readerFontRepositoryProvider.overrideWithValue(catalog),
        fontCatalogServiceProvider.overrideWithValue(_Catalog(catalog)),
        appFontPickerProvider.overrideWithValue(_Picker()),
      ],
    );
  }

  tearDown(() {
    container.dispose();
    unawaited(service.dispose());
    unawaited(catalog.dispose());
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: resolveAppThemes(
              preferences: ref.watch(appThemePreferencesProvider),
            ).light,
            home: const ThemeConfigScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('字体设置'),
      find.byType(ListView),
      const Offset(0, -180),
    );
    await tester.ensureVisible(find.text('字体设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('字体设置'));
    await tester.pumpAndSettle();
  }

  Finder inSheet(String text) =>
      find.descendant(of: find.byType(AppFontSheet), matching: find.text(text));

  testWidgets('外观打开字体sheet，导入即时生效并可恢复默认，不改正文选择', (tester) async {
    initialize();
    await open(tester);
    await tester.tap(inSheet('导入字体'));
    await tester.pumpAndSettle();
    expect(storage.values['app_font_family'], 'Custom_测试字体');
    expect(storage.values['reader_font_family'], 'ReaderOnly');
    expect(
      container.read(appThemePreferencesProvider).fontFamily,
      'Custom_测试字体',
    );
    expect(inSheet('测试字体'), findsOneWidget);
    await tester.tap(inSheet('默认字体'));
    await tester.pumpAndSettle();
    expect(storage.values['app_font_family'], '');
    expect(container.read(appThemePreferencesProvider).fontFamily, isNull);
    expect(storage.values['reader_font_family'], 'ReaderOnly');
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存失败保留默认并展示错误，重试选择可成功', (tester) async {
    initialize();
    await open(tester);
    storage.failNext = true;
    await tester.tap(inSheet('导入字体'));
    await tester.pumpAndSettle();
    expect(storage.values['app_font_family'], isNull);
    expect(find.textContaining('字体设置失败'), findsOneWidget);
    await tester.tap(inSheet('测试字体'));
    await tester.pumpAndSettle();
    expect(storage.values['app_font_family'], 'Custom_测试字体');
    expect(find.textContaining('字体设置失败'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('缺失已选字体不改偏好，运行时回退默认并提示', (tester) async {
    initialize();
    storage.values['app_font_family'] = 'Custom_Missing';
    await open(tester);
    expect(container.read(appThemePreferencesProvider).fontFamily, isNull);
    expect(storage.values['app_font_family'], 'Custom_Missing');
    expect(find.text('已选字体无法加载，暂用默认字体'), findsOneWidget);
    await tester.tap(inSheet('默认字体'));
    await tester.pumpAndSettle();
    expect(find.text('已选字体无法加载，暂用默认字体'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('界面字体不会污染阅读默认字体，明确选择的正文字体仍生效', (tester) async {
    initialize();
    final theme = resolveAppThemes(
      preferences: const AppThemePreferences(fontFamily: 'InterfaceOnly'),
    ).light;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: ReaderBodyTypography(
            child: Column(
              children: [
                Text('默认正文'),
                Text('自选正文', style: TextStyle(fontFamily: 'ReaderOnly')),
              ],
            ),
          ),
        ),
      ),
    );
    final first = tester.renderObject<RenderParagraph>(find.text('默认正文'));
    final second = tester.renderObject<RenderParagraph>(find.text('自选正文'));
    expect(first.text.style?.fontFamily, isNot('InterfaceOnly'));
    expect(second.text.style?.fontFamily, 'ReaderOnly');
    expect(tester.takeException(), isNull);
  });
}
