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
import 'package:flutter_legado/src/providers/welcome_settings_provider.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/features/settings/presentation/other_settings_screen.dart';
import 'package:flutter_legado/src/features/onboarding/presentation/welcome_config_screen.dart';
import 'package:flutter_legado/src/features/onboarding/presentation/welcome_screen.dart';
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
        child: RoutingTestApp(
          home: child is WelcomeScreen ? null : child,
          initialRoute: child is WelcomeScreen ? AppRoutes.welcome : null,
          routes: {
            if (child is WelcomeScreen) AppRoutes.welcome: (_) => child,
            if (child is WelcomeScreen)
              AppRoutes.home: (_) => const Scaffold(body: Text('启动后的主页')),
          },
        ),
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

  testWidgets('欢迎时长拖动为临时预览，保存失败恢复并可重试', (tester) async {
    await open(tester, const WelcomeConfigScreen());
    final slider = find.byType(Slider);
    tester.widget<Slider>(slider).onChanged!(120);
    await tester.pump();
    expect(find.text('启动闪屏停留 120 毫秒'), findsOneWidget);
    tester.widget<Slider>(slider).onChangeEnd!(120);
    await tester.pumpAndSettle();
    expect(
      container.read(welcomeSettingsRepositoryProvider).current.showTime,
      500,
    );
    expect(find.text('启动闪屏停留 500 毫秒'), findsOneWidget);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    storage.writeFailure = false;
    tester.widget<Slider>(slider).onChangeEnd!(120);
    await tester.pumpAndSettle();
    expect(storage.values['welcomeShowTime'], 120);
    expect(tester.takeException(), isNull);
  });

  testWidgets('自定义欢迎保存失败回退开关并提示', (tester) async {
    await open(tester, const WelcomeConfigScreen());
    await tester.tap(find.text('自定义欢迎页'));
    await tester.pumpAndSettle();
    expect(
      container.read(welcomeSettingsRepositoryProvider).current.customWelcome,
      isFalse,
    );
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('欢迎图片删除失败保留原路径与界面', (tester) async {
    await open(
      tester,
      const WelcomeConfigScreen(),
      initial: {'customWelcome': true, 'welcomeImagePath': 'fixtures/day.png'},
    );
    await tester.ensureVisible(find.text('背景图片').first);
    await tester.tap(find.text('背景图片').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(
      container.read(welcomeSettingsRepositoryProvider).current.imageDay,
      'fixtures/day.png',
    );
    expect(find.text('fixtures/day.png'), findsOneWidget);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('欢迎页实际读取共享时长，零时长进入原主页路由', (tester) async {
    await open(
      tester,
      const WelcomeScreen(),
      initial: {'welcomeShowTime': 0},
      failSaving: false,
    );
    expect(find.text('启动后的主页'), findsOneWidget);
    expect(storage.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

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
      container.read(welcomeSettingsRepositoryProvider).current.defaultToRead,
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
