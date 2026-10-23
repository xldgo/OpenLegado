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
import 'package:flutter_legado/src/features/settings/presentation/other_settings_screen.dart';
import 'package:flutter_legado/src/features/settings/presentation/webdav_settings_screen.dart';
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

  testWidgets('进度同步保存失败回退，重试后持久化', (tester) async {
    await open(tester, const WebDavSettingsScreen(), tall: true);
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
