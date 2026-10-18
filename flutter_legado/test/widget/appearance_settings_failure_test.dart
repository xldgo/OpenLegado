import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/bridge/runtime_configuration.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/contracts/settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/features/appearance/appearance.dart';
import 'package:flutter_legado/src/features/appearance/appearance_settings_provider.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/theme/theme_notifier.dart';
import 'package:flutter_legado/src/providers/ui_settings/ui_settings_notifier.dart';

void main() {
  late _Storage storage;
  late _Sync sync;
  late AppSettingsService service;
  late ProviderContainer container;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = _Storage();
    sync = _Sync();
  });
  tearDown(() {
    container.dispose();
    unawaited(service.dispose());
  });

  Future<void> open(WidgetTester tester) async {
    // 在 Widget 测试时钟内装配，写队列不能来自 setUp 的真实异步时钟。
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    container = ProviderContainer(
      overrides: [
        appSettingsServiceProvider.overrideWithValue(service),
        themeConfigSyncProvider.overrideWithValue(sync),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ThemeConfigScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('主题保存失败回退并提示，错误由页面接住', (tester) async {
    await open(tester);
    storage.fail = true;
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(storage.writes, 1);
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.system);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('液态底栏保存失败回退，重试后无需开启普通毛玻璃', (tester) async {
    storage.values['useFloatingBottomBar'] = true;
    await open(tester);
    final setting = find.text('悬浮底栏液态玻璃');
    await tester.dragUntilVisible(
      setting,
      find.byType(ListView),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    storage.fail = true;
    await tester.tap(setting);
    await tester.pumpAndSettle();
    expect(
      container.read(uiSettingsProvider).useFloatingBottomBarLiquidGlass,
      isFalse,
    );
    expect(storage.values['useFloatingBottomBarLiquidGlass'], isNull);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    storage.fail = false;
    await tester.tap(setting);
    await tester.pumpAndSettle();
    expect(
      container.read(uiSettingsProvider).useFloatingBottomBarLiquidGlass,
      isTrue,
    );
    expect(container.read(uiSettingsProvider).enableBlur, isFalse);
    expect(storage.values['useFloatingBottomBarLiquidGlass'], isTrue);
    await tester.dragUntilVisible(
      find.text('底栏模糊'),
      find.byType(ListView),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('底栏模糊'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('原生同步失败保留已保存主题，提示重试只执行同步', (tester) async {
    await open(tester);
    sync.fail = true;
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.dark);
    expect(storage.values['app_theme_mode'], 'dark');
    expect(find.text('设置已保存，主题同步失败'), findsOneWidget);
    sync.fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(sync.calls, 2);
    expect(storage.writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('字体保存期间阻止重复提交与返回，失败保留输入并允许重试', (tester) async {
    await open(tester);
    await tester.dragUntilVisible(
      find.text('字体大小'),
      find.byType(ListView),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('字体大小'));
    await tester.pumpAndSettle();
    final barrier = Completer<void>();
    storage.barrier = barrier;
    storage.fail = true;
    final save = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('确定'),
    );
    await tester.tap(save);
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确定'))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    barrier.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.text('当前字体大小: 1.0'), findsOneWidget);
    expect(container.read(themeNotifierProvider).fontScaleRaw, 0);
    storage.barrier = null;
    storage.fail = false;
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(storage.values['app_font_scale'], 10);
    expect(tester.takeException(), isNull);
  });
}

class _Storage implements SettingsStorage {
  final values = <String, Object?>{};
  bool fail = false;
  int writes = 0;
  Completer<void>? barrier;
  @override
  Future<Object?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Object? value) async {
    writes++;
    await barrier?.future;
    if (fail) throw StateError('模拟保存失败');
    values[key] = value;
  }
}

class _Sync implements ThemeConfigSync {
  bool fail = false;
  int calls = 0;
  @override
  Future<void> synchronizeThemeConfig() async {
    calls++;
    if (fail) throw StateError('模拟同步失败');
  }
}
