import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/cache/presentation/download_cache_settings_screen.dart';
import 'package:flutter_legado/src/widgets/app_settings_sheet.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';
import 'package:flutter_legado/src/providers/config_provider.dart';
import 'package:flutter_legado/src/providers/config_settings_provider.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';

import '../fixtures/app_test_api.dart';
import '../fixtures/config_repository.dart';

void main() {
  testWidgets('离线并发数字Sheet取消不写，越界拒绝，失败回退且不覆盖其他配置', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final values = {'threadCount': '17', 'cacheBookThreadCount': '2'};
    var failRead = false, failWrite = false;
    final config = TestConfigRepository(
      read: (key) async {
        if (key == 'cacheBookThreadCount' && failRead) throw StateError('读取失败');
        return values[key];
      },
      write: (key, value) async {
        if (failWrite) throw StateError('保存失败');
        values[key] = value;
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
        child: const MaterialApp(home: DownloadCacheSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final label = find.text('书籍缓存下载线程数');
    await tester.dragUntilVisible(
      label,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    failRead = true;
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsSheet), findsNothing);
    expect(find.text('下载并发设置读取失败，请重试'), findsOneWidget);
    failRead = false;
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '2'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '8');
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(values['cacheBookThreadCount'], '2');
    await tester.tap(label);
    await tester.pumpAndSettle();
    for (final invalid in ['0', '9']) {
      await tester.enterText(find.byType(TextField), invalid);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('请输入 1～8 之间的整数'), findsOneWidget);
    }
    await tester.enterText(find.byType(TextField), '8');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(values['cacheBookThreadCount'], '8');
    expect(values['threadCount'], '17');
    failWrite = true;
    await tester.tap(label);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(values['cacheBookThreadCount'], '8');
    expect(
      container
          .read(cacheDownloadSettingsRepositoryProvider)
          .current
          .threadCount,
      8,
    );
    expect(find.text('下载并发设置保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
        child: const MaterialApp(home: DownloadCacheSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final label = find.text('更新和搜索线程数');
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
    final row = find.widgetWithText(SettingTile, '更新和搜索线程数');
    expect(tester.widget<SettingTile>(row).enabled, isTrue);
    expect(
      find.descendant(
        of: row,
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text('线程数太多会卡顿'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.widgetWithText(TextField, '3'), findsOneWidget);
    tester.widget<SettingTile>(row).onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsSheet), findsOneWidget);
    await tester.enterText(find.byType(TextField), '8');
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(stored, '3');
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '3'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '257');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsSheet), findsOneWidget);
    expect(find.text('请输入 1～256 之间的整数'), findsOneWidget);
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
        child: const MaterialApp(home: DownloadCacheSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final label = find.text('更新和搜索线程数');
    await tester.dragUntilVisible(
      label,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('读取失败'), findsOneWidget);
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsSheet), findsNothing);
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
