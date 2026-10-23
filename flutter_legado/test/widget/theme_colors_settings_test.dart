import 'package:flutter_legado/src/l10n/app_localization.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/constants/pref_keys.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/features/appearance/appearance.dart';
import 'package:flutter_legado/src/features/appearance/theme_actions.dart';
import 'package:flutter_legado/src/models/theme_document.dart';
import 'package:flutter_legado/src/platform/files/theme_file_service.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/theme/theme_colors_notifier.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import '../fixtures/theme_settings_storage.dart';

void main() {
  late ThemeSettingsStorage storage;
  late ProviderContainer container;

  Future<void> open(
    WidgetTester tester, {
    Map<String, Object> preferences = const {},
    Map<String, Object?> values = const {},
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    storage = ThemeSettingsStorage(values);
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    container = ProviderContainer(
      overrides: [
        appSettingsServiceProvider.overrideWithValue(service),
        themeFileServiceProvider.overrideWithValue(_Files()),
      ],
    );
    addTearDown(() {
      container.dispose();
      unawaited(service.dispose());
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: ThemeConfigScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.dragUntilVisible(
      finder,
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> dayRow(WidgetTester tester, String title) async {
    final group = find.byWidgetPredicate(
      (widget) => widget is SettingsGroup && widget.title == '自定义主题 · 白天',
    );
    final label = find.descendant(of: group, matching: find.text(title));
    await tester.scrollUntilVisible(
      label,
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(label);
    await tester.pumpAndSettle();
  }

  testWidgets('颜色选择保存失败提示并回退，重试后共享快照同步', (tester) async {
    await open(tester, values: {PrefKeys.cPrimary: 11});
    await dayRow(tester, '主色调');
    storage.failNext = true;
    final swatch = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
          (widget.decoration! as BoxDecoration).color ==
              const Color(0xFFD32F2F),
    );
    await tester.tap(swatch);
    await tester.pumpAndSettle();
    expect(container.read(themeColorsProvider).primary, 11);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    await dayRow(tester, '主色调');
    await tester.tap(swatch);
    await tester.pumpAndSettle();
    expect(container.read(themeColorsProvider).primary, 0xFFD32F2F);
    expect(storage.values[PrefKeys.cPrimary], 0xFFD32F2F);
    expect(tester.takeException(), isNull);
  });

  testWidgets('恢复默认保存失败保留颜色，重试成功删除原键', (tester) async {
    await open(tester, values: {PrefKeys.cPrimary: 11});
    await dayRow(tester, '主色调');
    storage.failNext = true;
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    expect(container.read(themeColorsProvider).primary, 11);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    await dayRow(tester, '主色调');
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    expect(container.read(themeColorsProvider).primary, isNull);
    expect(storage.values.containsKey(PrefKeys.cPrimary), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('预设应用失败不显示成功且保留弹层，重试可应用', (tester) async {
    await open(
      tester,
      preferences: {
        'themeConfigList': jsonEncode([
          {'name': '测试主题', 'primary': 22},
        ]),
      },
      values: {PrefKeys.cPrimary: 11},
    );
    await reveal(tester, find.text('主题管理'));
    await tester.tap(find.text('主题管理'));
    await tester.pumpAndSettle();
    storage.failNext = true;
    await tester.tap(find.text('测试主题'));
    await tester.pumpAndSettle();
    expect(container.read(themeColorsProvider).primary, 11);
    expect(find.textContaining('主题操作失败'), findsOneWidget);
    expect(find.text('已应用主题「测试主题」'), findsNothing);
    // 错误提示覆盖在仍保留的预设列表之上，关闭提示后才能重试。
    expect(find.byType(AlertDialog), findsNWidgets(2));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('测试主题'));
    await tester.pumpAndSettle();
    expect(container.read(themeColorsProvider).primary, 22);
    expect(find.text('已应用主题「测试主题」'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('主题导入失败不显示成功，重试成功后显示真实结果', (tester) async {
    await open(tester, values: {PrefKeys.cPrimary: 11});
    await reveal(tester, find.text('导入主题'));
    storage.failNext = true;
    await tester.tap(find.text('导入主题'));
    await tester.pumpAndSettle();
    expect(container.read(themeColorsProvider).primary, 11);
    expect(find.textContaining('导入失败：'), findsOneWidget);
    expect(find.text('主题已导入'), findsNothing);
    await tester.tap(find.text('导入主题'));
    await tester.pumpAndSettle();
    expect(container.read(themeColorsProvider).primary, 22);
    expect(find.text('主题已导入'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('背景图保存失败回退提示，删除成功清除原路径', (tester) async {
    await open(tester, values: {PrefKeys.bgImage: '原图.jpg'});
    await dayRow(tester, '背景图片');
    storage.failNext = true;
    await tester.tap(find.text('选择图片'));
    await tester.pumpAndSettle();
    expect(container.read(themeColorsProvider).bgImage, '原图.jpg');
    expect(find.textContaining('背景图片操作失败'), findsOneWidget);
    await dayRow(tester, '背景图片');
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(container.read(themeColorsProvider).bgImage, '');
    expect(storage.values.containsKey(PrefKeys.bgImage), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未接线的导航栏阴影禁用且不改写保存值', (tester) async {
    await open(tester, preferences: {PrefKeys.barElevation: 12});
    await reveal(tester, find.text('导航栏阴影'));
    final tile = find.ancestor(
      of: find.text('导航栏阴影'),
      matching: find.byType(SettingTile),
    );
    expect(tester.widget<SettingTile>(tile).enabled, isFalse);
    expect(
      tester.widget<SettingTile>(tile).subtitle,
      '当前阴影大小（elevation）：12\n待实现',
    );
    await tester.tap(find.text('导航栏阴影'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(storage.writes, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(PrefKeys.barElevation), 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('四项封面偏好禁用并保留值，实际封面规则入口可用', (tester) async {
    final original = <String, Object>{
      PrefKeys.loadCoverOnlyWifi: true,
      PrefKeys.useDefaultCover: true,
      PrefKeys.coverShowName: false,
      PrefKeys.coverShowAuthor: false,
    };
    await open(tester, preferences: original);
    await reveal(tester, find.text('封面设置'));
    await tester.tap(find.text('封面设置'));
    await tester.pumpAndSettle();
    final rows = tester
        .widgetList<SettingSwitchRow>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(SettingSwitchRow),
          ),
        )
        .toList();
    expect(rows.map((row) => row.value), [true, true, false, false]);
    expect(
      rows.every((row) => row.onChanged == null && row.subtitle == '待实现'),
      isTrue,
    );
    for (final row in rows) {
      final label = find.text(row.title);
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      await tester.tap(label);
      await tester.pumpAndSettle();
    }
    final rule = find.ancestor(
      of: find.text('封面规则'),
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(rule).onTap, isNotNull);
    final prefs = await SharedPreferences.getInstance();
    expect({for (final key in original.keys) key: prefs.get(key)}, original);
    expect(storage.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

class _Files extends ThemeFileService {
  @override
  Future<ThemeDocument?> importTheme() async => const ThemeDocument(
    day: ThemeDocumentColors(primary: 22),
    night: ThemeDocumentColors(),
  );
  @override
  Future<String?> selectBackgroundImage() async => '新图.jpg';
}
