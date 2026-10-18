import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/contracts/settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/features/appearance/appearance.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/ui_settings/ui_settings_notifier.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

void main() {
  late _Storage storage;
  late ProviderContainer container;

  Future<void> open(
    WidgetTester tester, {
    Map<String, Object?> initial = const {},
  }) async {
    SharedPreferences.setMockInitialValues({});
    storage = _Storage()..values.addAll(initial);
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    container = ProviderContainer(
      overrides: [appSettingsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(() {
      container.dispose();
      unawaited(service.dispose());
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ThemeConfigScreen()),
      ),
    );
    await tester.pumpAndSettle();
    storage.fail = true;
  }

  Future<void> reveal(WidgetTester tester, String label) async {
    await tester.dragUntilVisible(
      find.text(label),
      find.byType(ListView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('显示底栏保存失败回退并提示', (tester) async {
    await open(tester);
    await reveal(tester, '显示底栏');
    await tester.tap(find.text('显示底栏'));
    await tester.pumpAndSettle();
    expect(container.read(uiSettingsProvider).showBottomView, isTrue);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('底栏文字选项保存失败回退，菜单回调接住错误', (tester) async {
    await open(tester);
    await reveal(tester, '底栏文字');
    final finder = find.byWidgetPredicate(
      (widget) => widget is SettingMenuRow<BottomBarLabelMode>,
    );
    tester.widget<SettingMenuRow<BottomBarLabelMode>>(finder).onChanged!(
      BottomBarLabelMode.labeled,
    );
    await tester.pumpAndSettle();
    expect(
      container.read(uiSettingsProvider).labelVisibilityMode,
      BottomBarLabelMode.auto,
    );
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('普通背景浮点保存，模糊开关只展示对应模式设置', (tester) async {
    await open(tester);
    storage.fail = false;
    await reveal(tester, '顶栏背景不透明度');
    await tester.tap(find.text('顶栏背景不透明度'));
    await tester.pumpAndSettle();
    final finder = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Slider),
    );
    final slider = tester.widget<Slider>(finder);
    expect(slider.max, 1);
    expect(slider.divisions, 100);
    slider.onChanged!(0.42);
    await tester.pump();
    expect(find.text('当前 42%'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('确定')),
    );
    await tester.pumpAndSettle();
    expect(storage.values['topBarBackgroundOpacity'], 0.42);
    final notifier = container.read(uiSettingsProvider.notifier);
    await notifier.setEnableBlur(true);
    await tester.pumpAndSettle();
    expect(find.text('顶栏背景不透明度'), findsNothing);
    await reveal(tester, '顶栏模糊');
    await tester.tap(find.text('顶栏模糊'));
    await tester.pumpAndSettle();
    expect(find.text('底色不透明度 73%'), findsOneWidget);
    final sliders = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Slider),
    );
    expect(tester.widget<Slider>(sliders.at(0)).value, 24);
    expect(tester.widget<Slider>(sliders.at(1)).value, 0.73);
    expect(tester.widget<Slider>(sliders.at(1)).max, 1);
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('取消')),
    );
    await tester.pumpAndSettle();
    await notifier.setEnableBlur(false);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('顶栏背景不透明度'),
      find.byType(ListView),
      const Offset(0, 220),
    );
    expect(find.text('当前 42%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('存储中的越界值和非有限值不会进入模糊滑块', (tester) async {
    await open(
      tester,
      initial: {
        'enableBlur': true,
        'topBarBlurSigma': -2.0,
        'topBarBlurTintOpacity': double.nan,
      },
    );
    await reveal(tester, '顶栏模糊');
    await tester.tap(find.text('顶栏模糊'));
    await tester.pumpAndSettle();
    final sliders = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Slider),
    );
    expect(tester.widget<Slider>(sliders.at(0)).value, 0);
    expect(tester.widget<Slider>(sliders.at(1)).value, 0.73);
    expect(tester.takeException(), isNull);
  });

  testWidgets('顶栏透明度保存失败恢复原值并提示', (tester) async {
    await open(tester);
    await reveal(tester, '顶栏背景不透明度');
    await tester.tap(find.text('顶栏背景不透明度'));
    await tester.pumpAndSettle();
    final slider = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Slider),
    );
    tester.widget<Slider>(slider).onChanged!(0.5);
    await tester.pump();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('确定')),
    );
    await tester.pumpAndSettle();
    expect(container.read(uiSettingsProvider).topBarBackgroundOpacity, 1.0);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (label, value) in [
    ('纯黑深色模式', (UiSettings ui) => ui.themeAmoled),
    ('界面颜色跟随封面取色', (UiSettings ui) => ui.bookInfoFollowCoverColor),
    ('显示分隔线', (UiSettings ui) => ui.enableItemDivider),
    ('启用毛玻璃', (UiSettings ui) => ui.enableBlur),
  ]) {
    testWidgets('$label 保存失败回退，页面接住错误', (tester) async {
      await open(tester);
      final before = value(container.read(uiSettingsProvider));
      await reveal(tester, label);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(value(container.read(uiSettingsProvider)), before);
      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('配色风格保存失败回退，菜单回调接住错误', (tester) async {
    await open(tester);
    await reveal(tester, '配色风格');
    final row = find.byWidgetPredicate(
      (widget) => widget is SettingMenuRow<String> && widget.title == '配色风格',
    );
    tester.widget<SettingMenuRow<String>>(row).onChanged!('expressive');
    await tester.pumpAndSettle();
    expect(container.read(uiSettingsProvider).themeStyle, 'none');
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('圆角对话框等待保存，失败时开关和数值一起回退', (tester) async {
    await open(tester);
    await reveal(tester, '卡片圆角');
    await tester.tap(find.text('卡片圆角'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('覆写主题圆角'));
    final slider = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Slider),
    );
    tester.widget<Slider>(slider).onChanged!(22);
    await tester.pump();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('确定')),
    );
    await tester.pumpAndSettle();
    final ui = container.read(uiSettingsProvider);
    expect(ui.overrideBaseCardCornerRadius, isFalse);
    expect(ui.baseCardCornerRadius, 16);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('模糊对话框等待保存，参数失败回退并可重试', (tester) async {
    await open(tester, initial: {'enableBlur': true});
    await reveal(tester, '顶栏模糊');
    Future<void> saveParameters() async {
      await tester.tap(find.text('顶栏模糊'));
      await tester.pumpAndSettle();
      final sliders = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Slider),
      );
      tester.widget<Slider>(sliders.at(0)).onChanged!(32);
      tester.widget<Slider>(sliders.at(1)).onChanged!(0.6);
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('确定'),
        ),
      );
      await tester.pumpAndSettle();
    }

    await saveParameters();
    expect(container.read(uiSettingsProvider).topBarBlurSigma, 24);
    expect(container.read(uiSettingsProvider).topBarBlurTintOpacity, 0.73);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    storage.fail = false;
    await saveParameters();
    expect(container.read(uiSettingsProvider).topBarBlurSigma, 32);
    expect(container.read(uiSettingsProvider).topBarBlurTintOpacity, 0.6);
    expect(tester.takeException(), isNull);
  });
}

class _Storage implements SettingsStorage {
  final values = <String, Object?>{};
  bool fail = false;
  @override
  Future<Object?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Object? value) async {
    if (fail) throw StateError('模拟保存失败');
    values[key] = value;
  }
}
