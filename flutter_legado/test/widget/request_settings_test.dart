import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/settings/presentation/other_settings_screen.dart';
import 'package:flutter_legado/src/providers/config_provider.dart';
import 'package:flutter_legado/src/providers/config_settings_provider.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';

import '../fixtures/app_test_api.dart';
import '../fixtures/config_repository.dart';

void main() {
  testWidgets('并发输入保存到Rust配置，拒绝非法值且保存失败回退', (tester) async {
    SharedPreferences.setMockInitialValues({'threadCount': 99});
    var stored = '3';
    var fail = false;
    final config = TestConfigRepository(
      read: (key) async => key == 'threadCount' ? stored : null,
      write: (key, value) async {
        if (key == 'threadCount') {
          if (fail) throw StateError('无法保存');
          stored = value;
        }
      },
    );
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        configRepositoryProvider.overrideWithValue(config),
      ]),
    );
    addTearDown(() {
      final service = container.read(appSettingsServiceProvider);
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
    final label = find.text('更新和搜索线程数（太多会卡顿）');
    await tester.dragUntilVisible(
      label,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(requestSettingsRepositoryProvider).current.threadCount,
      3,
    );
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '3'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '257');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(stored, '3');
    await tester.enterText(find.byType(TextField), '7');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(stored, '7');
    expect(
      container.read(requestSettingsRepositoryProvider).current.threadCount,
      7,
    );
    expect((await SharedPreferences.getInstance()).getInt('threadCount'), 99);
    fail = true;
    await tester.tap(label);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(stored, '7');
    expect(
      container.read(requestSettingsRepositoryProvider).current.threadCount,
      7,
    );
    expect(find.text('并发设置保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('并发读取失败显示错误，修复后点按可以重试', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var fail = true;
    final config = TestConfigRepository(
      read: (key) async {
        if (key == 'threadCount') {
          if (fail) throw StateError('无法读取');
          return '5';
        }
        return null;
      },
    );
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        configRepositoryProvider.overrideWithValue(config),
      ]),
    );
    addTearDown(() {
      final service = container.read(appSettingsServiceProvider);
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
    final label = find.text('更新和搜索线程数（太多会卡顿）');
    await tester.dragUntilVisible(
      label,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('读取失败'), findsOneWidget);
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('并发设置读取失败，请重试'), findsOneWidget);
    fail = false;
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '5'), findsOneWidget);
    expect(
      container.read(requestSettingsRepositoryProvider).current.threadCount,
      5,
    );
    expect(tester.takeException(), isNull);
  });
}
