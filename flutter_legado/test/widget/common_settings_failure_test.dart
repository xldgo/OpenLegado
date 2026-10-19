import '../fixtures/routing_test_app.dart';
import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf_manage_screen.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/app_locale_notifier.dart';
import 'package:flutter_legado/src/features/bookshelf/application/bookshelf_settings_provider.dart';
import 'package:flutter_legado/src/providers/ui_settings/eye_protection_notifier.dart';
import 'package:flutter_legado/src/providers/general_settings_provider.dart';
import 'package:flutter_legado/src/features/settings/presentation/other_settings_screen.dart';
import 'package:flutter_legado/src/widgets/app_menu.dart';
import 'package:flutter_legado/src/widgets/eye_protection_settings.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  late HomeSettingsStorage storage;
  late ProviderContainer container;

  Future<void> open(
    WidgetTester tester,
    Widget child, {
    Map<String, Object?> initial = const {},
    bool failSaving = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    storage = HomeSettingsStorage()..values.addAll(initial);
    final service = AppSettingsService(
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RoutingTestApp(home: child),
      ),
    );
    await tester.pumpAndSettle();
    storage.writeFailure = failSaving;
  }

  Future<void> reveal(WidgetTester tester, String label) async {
    await tester.dragUntilVisible(
      find.text(label),
      find.byType(ListView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('护眼开关保存失败回退并显示统一提示', (tester) async {
    await open(tester, const Scaffold(body: EyeProtectionSettingsGroup()));
    await tester.tap(find.text('启用护眼模式'));
    await tester.pumpAndSettle();
    expect(container.read(eyeProtectionProvider).enabled, isFalse);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('语言保存失败不留下页面局部选择', (tester) async {
    await open(tester, const OtherSettingsScreen());
    await reveal(tester, '语言');
    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(container.read(appLocaleProvider), 'system');
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('默认开读保存失败回退，设置页与启动来源一致', (tester) async {
    await open(tester, const OtherSettingsScreen());
    await reveal(tester, '自动跳转最近阅读');
    await tester.tap(find.text('自动跳转最近阅读'));
    await tester.pumpAndSettle();
    expect(
      container.read(generalSettingsRepositoryProvider).current.defaultToRead,
      isFalse,
    );
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('书架管理书名行为保存失败回退并提示', (tester) async {
    await open(tester, const BookshelfManageScreen());
    final menu = find.byWidgetPredicate(
      (widget) => widget is AppMenuButton<String>,
    );
    tester.widget<AppMenuButton<String>>(menu).onSelected!('open_by_title');
    await tester.pumpAndSettle();
    expect(
      container
          .read(bookshelfSettingsRepositoryProvider)
          .current
          .openBookInfoByClickTitle,
      isFalse,
    );
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('记录开关失败回退并提示，阅读器不会收到未保存值', (tester) async {
    await open(tester, const ReadRecordScreen());
    final menu = find.byWidgetPredicate(
      (widget) => widget is AppMenuButton<String>,
    );
    tester.widget<AppMenuButton<String>>(menu).onSelected!('enable');
    await tester.pumpAndSettle();
    expect(container.read(readRecordNotifierProvider).enableRecord, isTrue);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
