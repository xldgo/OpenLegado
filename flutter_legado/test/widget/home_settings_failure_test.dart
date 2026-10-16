import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_home_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/providers/home_settings_provider.dart';
import 'package:flutter_legado/src/providers/main_prefs_notifier.dart';
import 'package:flutter_legado/src/screens/other_settings_screen.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import '../fixtures/home_settings_storage.dart';
import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  late HomeSettingsStorage storage;
  late ProviderContainer container;

  Future<void> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    storage = HomeSettingsStorage();
    // 写队列在 Widget 测试时钟内创建，避免真实时钟与模拟时钟混用。
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    final api = MockRustApi();
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((_) async => null);
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        homeSettingsRepositoryProvider.overrideWithValue(
          AppHomeSettingsRepository(service),
        ),
      ]),
    );
    addTearDown(() {
      container.dispose();
      unawaited(service.dispose());
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OtherSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String title) => find.byWidgetPredicate(
    (widget) => widget is SettingSwitchRow && widget.title == title,
  );

  for (final label in ['显示发现', '显示订阅']) {
    testWidgets('$label 保存失败回退开关并提示，页面接住错误', (tester) async {
      await open(tester);
      storage.writeFailure = true;
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.widget<SettingSwitchRow>(row(label)).value, isTrue);
      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('默认首页保存失败回退到原选项，不假报成功', (tester) async {
    await open(tester);
    storage.writeFailure = true;
    await tester.ensureVisible(find.text('默认主页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('默认主页'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(SimpleDialog), matching: find.text('首页')),
    );
    await tester.pumpAndSettle();
    expect(container.read(mainPrefsProvider).defaultHomePage, 'bookshelf');
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('开关失败后重新操作可以成功保存', (tester) async {
    await open(tester);
    storage.writeFailure = true;
    await tester.ensureVisible(find.text('显示发现'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示发现'));
    await tester.pumpAndSettle();
    storage.writeFailure = false;
    await tester.tap(find.text('显示发现'));
    await tester.pumpAndSettle();
    expect(tester.widget<SettingSwitchRow>(row('显示发现')).value, isFalse);
    expect(storage.values['showDiscovery'], isFalse);
    expect(storage.writes.length, 2);
    expect(tester.takeException(), isNull);
  });
}
