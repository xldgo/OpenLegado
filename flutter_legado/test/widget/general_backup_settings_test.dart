import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/features/appearance/theme_config_screen.dart';
import 'package:flutter_legado/src/features/appearance/appearance_settings_provider.dart';
import 'package:flutter_legado/src/l10n/app_localization.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/backup_settings_provider.dart';
import 'package:flutter_legado/src/providers/general_settings_provider.dart';
import 'package:flutter_legado/src/screens/other_settings_screen.dart';
import 'package:flutter_legado/src/screens/webdav_settings_screen.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import '../fixtures/home_settings_storage.dart';
import '../mocks/mocks.dart';

void main() {
  late HomeSettingsStorage storage;
  late ProviderContainer container;

  setUpAll(registerFallbacks);

  Future<void> open(
    WidgetTester tester,
    Widget screen, {
    Map<String, Object> initial = const {},
    MockRustApi? api,
    bool tall = false,
  }) async {
    SharedPreferences.setMockInitialValues(initial);
    storage = HomeSettingsStorage()..values.addAll(initial);
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: mergeTestOverrides([
        ...(api ?? MockBookApi()).overrides,
        appSettingsServiceProvider.overrideWithValue(service),
      ]),
    );
    addTearDown(() {
      container.dispose();
      unawaited(service.dispose());
    });
    if (tall) {
      tester.view.physicalSize = const Size(1000, 10000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('其他设置未接线的二十二行禁用，保留说明及已保存值', (tester) async {
    await open(
      tester,
      const OtherSettingsScreen(),
      tall: true,
      initial: {
        'auto_refresh': true,
        'onlyUpdateRead': true,
        'userAgent': '原有浏览器标识',
        'threadCount': 29,
        'crash_record_http_log': true,
      },
    );
    final disabled = tester
        .widgetList<SettingTile>(find.byType(SettingTile))
        .where((row) => !row.enabled)
        .toList();
    expect(disabled, hasLength(22));
    for (final row in disabled) {
      expect(row.onTap, isNull, reason: row.title);
      expect(row.subtitle, contains('待实现'), reason: row.title);
    }
    expect(find.text('原有浏览器标识\n待实现'), findsOneWidget);
    expect(find.text('在内存中保留最近 50 条已脱敏的请求与响应记录\n待实现'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('userAgent'), '原有浏览器标识');
    expect(prefs.getBool('crash_record_http_log'), isTrue);
    expect(storage.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('返回入架提醒失败回退，重试与仓储外部更新能刷新页面', (tester) async {
    await open(tester, const OtherSettingsScreen(), tall: true);
    SettingSwitchRow row() => tester
        .widgetList<SettingSwitchRow>(find.byType(SettingSwitchRow))
        .singleWhere(
          (row) =>
              row.title ==
              tester
                  .element(find.byType(OtherSettingsScreen))
                  .l10n
                  .advancedAddToShelfPrompt,
        );
    storage.writeFailure = true;
    row().onChanged!(false);
    await tester.pumpAndSettle();
    expect(
      container
          .read(generalSettingsRepositoryProvider)
          .current
          .showAddToShelfAlert,
      isTrue,
    );
    expect(row().value, isTrue);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    storage.writeFailure = false;
    row().onChanged!(false);
    await tester.pumpAndSettle();
    expect(row().value, isFalse);
    storage.values['showAddToShelfAlert'] = true;
    await container.read(generalSettingsRepositoryProvider).reload();
    await tester.pumpAndSettle();
    expect(row().value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('端口保存失败不调用 Rust 服务，成功后才应用新端口', (tester) async {
    final api = MockRustApi();
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((_) async => null);
    when(() => api.localServerService.setServerPort(any()))
        .thenAnswer((_) async {});
    await open(tester, const OtherSettingsScreen(), api: api, tall: true);
    Future<void> choosePort() async {
      final row = tester
          .widgetList<SettingTile>(find.byType(SettingTile))
          .singleWhere((row) => row.subtitle == '当前端口 1122');
      row.onTap!();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4321');
      await tester.tap(find.text('确定').last);
      await tester.pumpAndSettle();
    }

    storage.writeFailure = true;
    await choosePort();
    verifyNever(() => api.localServerService.setServerPort(any()));
    expect(find.text('端口保存失败，请重试'), findsOneWidget);
    expect(
      container.read(generalSettingsRepositoryProvider).current.webPort,
      1122,
    );
    storage.writeFailure = false;
    await choosePort();
    verify(() => api.localServerService.setServerPort(4321)).called(1);
    expect(storage.values['webPort'], 4321);
    expect(tester.takeException(), isNull);
  });

  testWidgets('备份四个未接线行禁用，进度同步失败回退并提示', (tester) async {
    await open(tester, const WebDavSettingsScreen(), tall: true);
    final disabled = tester
        .widgetList<SettingTile>(find.byType(SettingTile))
        .where((row) => !row.enabled)
        .toList();
    expect(disabled, hasLength(4));
    for (final row in disabled) {
      expect(row.onTap, isNull);
      expect(row.subtitle, contains('待实现'));
    }
    SettingSwitchRow progress() => tester
        .widgetList<SettingSwitchRow>(find.byType(SettingSwitchRow))
        .singleWhere((row) => row.subtitle == '在多设备间同步书籍阅读进度');
    storage.writeFailure = true;
    progress().onChanged!(false);
    await tester.pumpAndSettle();
    expect(progress().value, isTrue);
    expect(find.text('备份设置保存失败，请重试'), findsOneWidget);
    storage.writeFailure = false;
    progress().onChanged!(false);
    await tester.pumpAndSettle();
    expect(progress().value, isFalse);
    expect(
      container.read(backupSettingsRepositoryProvider).current.syncBookProgress,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('图标保存失败不调用平台，平台失败保留已保存的选择', (tester) async {
    const channel = MethodChannel('legado/launcher_icon');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw PlatformException(code: 'rejected', message: '系统拒绝切换图标');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await open(tester, const ThemeConfigScreen(), tall: true);
    SettingMenuRow<String> icon() => tester
        .widgetList<SettingMenuRow<String>>(find.byType(SettingMenuRow<String>))
        .singleWhere((row) => row.options.containsKey('icon4'));
    storage.writeFailure = true;
    icon().onChanged!('icon4');
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(icon().value, 'iconMain');
    expect(find.text('图标设置保存失败，请重试'), findsOneWidget);
    storage.writeFailure = false;
    icon().onChanged!('icon4');
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(calls.single.arguments, {'icon': 'icon4'});
    expect(
      container.read(appearanceSettingsRepositoryProvider).current.launcherIcon,
      'icon4',
    );
    expect(icon().value, 'icon4');
    expect(find.textContaining('系统拒绝切换图标'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));
}
