import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/reader_theme_mode.dart';
import 'package:flutter_legado/src/domain/models/reader_style.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';
import 'package:flutter_legado/src/providers/theme/theme_notifier.dart';
import 'package:flutter_legado/src/features/reader/presentation/reader_screen.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_settings_sheet.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late ProviderContainer container;

  void initialize() {
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
    const channel = MethodChannel('github.com/aaassseee/screen_brightness');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unsupported');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    addTearDown(() {
      container.dispose();
      unawaited(service.dispose());
    });
  }

  Future<void> show(WidgetTester tester, {bool fullPage = false}) async {
    final settings = ReaderSettingsSheet(
      fullPage: fullPage,
      category: fullPage ? ReaderSettingsCategory.background : null,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: fullPage
              ? settings
              : Scaffold(body: SingleChildScrollView(child: settings)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String id) async {
    final finder = find.byKey(ValueKey('reader-style-$id'));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> mode(WidgetTester tester, String label) async {
    final selector = find.byType(SettingMenuRow<ReaderThemeMode>);
    await tester.ensureVisible(selector);
    await tester.tap(
      find.descendant(of: selector, matching: find.text('阅读模式')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  void colors(int background, int text) {
    final state = container.read(readerNotifierProvider);
    expect(state.backgroundColor.toARGB32(), background);
    expect(state.textColor.toARGB32(), text);
  }

  testWidgets('退出真实阅读页清除覆盖，临时打开子页面保持当前日夜', (tester) async {
    initialize();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('书架')),
        ),
      ),
    );
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => const ReaderScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final session = container.read(readerThemeSessionProvider);
    await container
        .read(readerNotifierProvider.notifier)
        .updateReaderThemeMode(ReaderThemeMode.night);
    await tester.pumpAndSettle();
    expect(session.mode, ReaderThemeMode.night);
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('阅读设置'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(session.mode, ReaderThemeMode.night);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(session.mode, ReaderThemeMode.night);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(session.mode, ReaderThemeMode.followApp);
    expect(tester.takeException(), isNull);
  });

  testWidgets('六套模板显示并选择，日夜颜色与预览同步，阅读模式不改应用主题', (tester) async {
    initialize();
    await show(tester);
    for (final style in readerStylePresets) {
      expect(find.byKey(ValueKey('reader-style-${style.id}')), findsOneWidget);
    }
    await select(tester, 'preset3');
    colors(0xFFC2D8AA, 0xFF596C44);
    expect(find.byTooltip('切换夜间'), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    final originalTheme = container.read(themeNotifierProvider).themeMode;
    await mode(tester, '夜间');
    colors(0xFF3C3F43, 0xFF88C16F);
    expect(find.byTooltip('切换日间'), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    final preview = find.descendant(
      of: find.byKey(const ValueKey('reader-style-preset3')),
      matching: find.byType(Container),
    );
    expect(
      (tester.widget<Container>(preview).decoration as BoxDecoration).color,
      const Color(0xFF3C3F43),
    );
    expect(container.read(themeNotifierProvider).themeMode, originalTheme);
    final toggle = find.byTooltip('切换日间');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    colors(0xFFC2D8AA, 0xFF596C44);
    expect(find.byTooltip('切换夜间'), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    expect(
      container.read(readerStyleRepositoryProvider).current.selectedId,
      'preset3',
    );
  });

  testWidgets('长按编辑当前模板的夜间颜色，切换日夜与模板保留各自修改', (tester) async {
    initialize();
    await show(tester);
    await select(tester, 'preset2');
    await mode(tester, '夜间');
    final style = find.byKey(const ValueKey('reader-style-preset2'));
    await tester.ensureVisible(style);
    await tester.longPress(style);
    await tester.pumpAndSettle();
    expect(find.text('自定义夜间配色'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('reader-text-color-${0xFF616161}')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('reader-background-color-${0xFFF5F5DC}')),
    );
    await tester.pumpAndSettle();
    colors(0xFFF5F5DC, 0xFF616161);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await mode(tester, '日间');
    colors(0xFFDDC090, 0xFF3E3422);
    await select(tester, 'preset4');
    await select(tester, 'preset2');
    await mode(tester, '夜间');
    colors(0xFFF5F5DC, 0xFF616161);
  });

  testWidgets('模板保存失败回退，日夜覆盖不依赖存储且两个设置入口同步', (tester) async {
    initialize();
    await show(tester);
    storage.writeFailure = true;
    await select(tester, 'preset5');
    expect(find.text('阅读配色保存失败，请重试'), findsOneWidget);
    expect(
      container.read(readerStyleRepositoryProvider).current.selectedId,
      'custom',
    );
    await mode(tester, '夜间');
    expect(
      container.read(readerThemeSessionProvider).mode,
      ReaderThemeMode.night,
    );
    storage.writeFailure = false;
    await select(tester, 'preset5');
    await show(tester, fullPage: true);
    colors(0xFF3C3F43, 0xFF90BFF5);
    await mode(tester, '夜间');
    colors(0xFF3C3F43, 0xFF90BFF5);
    await show(tester);
    expect(
      tester
          .widget<SettingMenuRow<ReaderThemeMode>>(
            find.byType(SettingMenuRow<ReaderThemeMode>),
          )
          .value,
      ReaderThemeMode.night,
    );
    expect(storage.values.containsKey('reader_theme_mode'), isFalse);
    final writes = storage.writes.length;
    await mode(tester, '日间');
    expect(storage.writes.length, writes);
    container.read(readerThemeSessionProvider).reset();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SettingMenuRow<ReaderThemeMode>>(
            find.byType(SettingMenuRow<ReaderThemeMode>),
          )
          .value,
      ReaderThemeMode.followApp,
    );
  });
}
