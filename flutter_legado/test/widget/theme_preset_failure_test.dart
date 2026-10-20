import 'package:flutter_legado/src/data/repositories/preferences_theme_preset_repository.dart';
import 'package:flutter_legado/src/features/appearance/theme_actions.dart';
import 'package:flutter_legado/src/features/appearance/theme_config_screen.dart';
import 'package:flutter_legado/src/features/appearance/widgets/theme_preset_dialogs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Preferences extends Fake implements SharedPreferences {
  _Preferences(this.delegate);
  final SharedPreferences delegate;
  bool failRead = false;
  bool rejectNext = false;

  @override
  String? getString(String key) {
    if (failRead) throw StateError('模拟预设读取失败');
    return delegate.getString(key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    final saved = await delegate.setString(key, value);
    if (rejectNext) {
      rejectNext = false;
      return false;
    }
    return saved;
  }

  @override
  Future<bool> remove(String key) => delegate.remove(key);
}

void main() {
  late _Preferences prefs;
  late PreferencesThemePresetRepository repository;
  const raw = '[{"name":"原主题","primary":123,"extra":"保留"}]';
  setUp(() => SharedPreferences.setMockInitialValues({'themeConfigList': raw}));

  Future<void> open(WidgetTester tester) async {
    prefs = _Preferences(await SharedPreferences.getInstance());
    repository = PreferencesThemePresetRepository(
      loadPreferences: () async => prefs,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themePresetRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: ThemeConfigScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapRow(
    WidgetTester tester,
    String title, {
    double delta = -160,
  }) async {
    await tester.dragUntilVisible(
      find.text(title),
      find.byType(ListView),
      Offset(0, delta),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets('预设读取失败有可见反馈，不打开空列表，恢复后可重试', (tester) async {
    await open(tester);
    prefs.failRead = true;
    await tapRow(tester, '主题管理');
    expect(find.byType(ThemePresetListDialog), findsNothing);
    expect(find.textContaining('主题操作失败').hitTestable(), findsOneWidget);
    expect(prefs.delegate.getString('themeConfigList'), raw);
    prefs.failRead = false;
    await tester.tap(find.text('主题管理'));
    await tester.pumpAndSettle();
    expect(find.text('原主题').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除失败在原列表上方显示错误，缓存和条目保留且可重试', (tester) async {
    await open(tester);
    await tapRow(tester, '主题管理');
    prefs.rejectNext = true;
    await tester.tap(find.byIcon(Symbols.delete_rounded));
    await tester.pumpAndSettle();
    expect(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.text('主题操作失败，请重试'),
          )
          .hitTestable(),
      findsOneWidget,
    );
    expect(find.byType(ThemePresetListDialog), findsOneWidget);
    expect(prefs.delegate.getString('themeConfigList'), raw);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('原主题').hitTestable(), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.delete_rounded));
    await tester.pumpAndSettle();
    expect(find.text('原主题'), findsNothing);
    expect((await repository.readAll()), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新增预设失败不提示保存成功，旧列表保持并允许重试', (tester) async {
    await open(tester);
    await tapRow(tester, '保存白天主题');
    await tester.enterText(find.byType(TextField), '新主题');
    prefs.rejectNext = true;
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存失败').hitTestable(), findsOneWidget);
    expect(find.text('已保存主题「新主题」'), findsNothing);
    expect(prefs.delegate.getString('themeConfigList'), raw);
    await tester.tap(find.text('保存白天主题'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新主题');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('已保存主题「新主题」').hitTestable(), findsOneWidget);
    expect((await repository.readAll()).map((preset) => preset.name), [
      '原主题',
      '新主题',
    ]);
    expect(tester.takeException(), isNull);
  });
}
