import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/domain/models/cover_rule.dart';
import 'package:flutter_legado/src/features/appearance/widgets/cover_rule_config_dialog.dart';
import 'package:flutter_legado/src/l10n/app_strings.dart';

void main() {
  const original = CoverRule(
    enable: false,
    searchUrl: 'url',
    coverRule: 'rule',
    enabledCookieJar: true,
  );
  Future<void> open(
    WidgetTester tester, {
    Future<CoverRule> Function()? load,
    Future<bool> Function(CoverRule)? save,
    Future<bool> Function()? delete,
    Future<List<String>> Function(String)? search,
  }) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CoverRuleConfigDialog(
                  loadRule: load ?? () async => original,
                  saveRule: save ?? (_) async => true,
                  deleteRule: delete ?? () async => true,
                  onSearch: search ?? (_) async => [],
                ),
              ),
              child: const Text('打开规则'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开规则'));
    await tester.pumpAndSettle();
  }

  testWidgets('编辑封面规则保留未展示Cookie开关，保存成功关闭对话框', (tester) async {
    CoverRule? saved;
    await open(
      tester,
      save: (value) async {
        saved = value;
        return true;
      },
    );
    expect(find.text('url'), findsOneWidget);
    expect(find.text('rule'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '新URL');
    await tester.tap(find.text(AppStrings.current.confirm));
    await tester.pumpAndSettle();
    expect(saved!.searchUrl, '新URL');
    expect(saved!.coverRule, 'rule');
    expect(saved!.enable, isFalse);
    expect(saved!.enabledCookieJar, isTrue);
    expect(find.byType(CoverRuleConfigDialog), findsNothing);
  });
  testWidgets('保存或删除返回false时不关闭，并允许重试', (tester) async {
    var succeeds = false;
    await open(tester, save: (_) async => succeeds, delete: () async => false);
    await tester.tap(find.text(AppStrings.current.confirm));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(find.text('url'), findsOneWidget);
    await tester.tap(find.text(AppStrings.current.delete));
    await tester.pumpAndSettle();
    expect(find.textContaining('删除失败'), findsOneWidget);
    succeeds = true;
    await tester.tap(find.text(AppStrings.current.confirm));
    await tester.pumpAndSettle();
    expect(find.byType(CoverRuleConfigDialog), findsNothing);
  });
  testWidgets('规则搜索保留测试书名和返回URL，读取失败不显示伪造规则', (tester) async {
    String? name;
    await open(
      tester,
      search: (value) async {
        name = value;
        return ['https://cover.test/1'];
      },
    );
    await tester.enterText(find.byType(TextField).at(2), '测试书');
    await tester.tap(find.text(AppStrings.current.testSource));
    await tester.pumpAndSettle();
    expect(name, '测试书');
    expect(find.text('https://cover.test/1'), findsOneWidget);
    await tester.tap(find.text(AppStrings.current.cancel));
    await tester.pumpAndSettle();
    await open(tester, load: () async => throw StateError('加载失败样例'));
    expect(find.textContaining('加载失败样例'), findsOneWidget);
  });
}
