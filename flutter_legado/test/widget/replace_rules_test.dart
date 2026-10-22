import '../fixtures/app_test_api.dart';

// 替换规则页 widget 测试
//
// [A3 形态对齐 | full-stack-engineer + UI] 编辑器由弹窗表单升级为整页
// ReplaceRuleEditScreen 后，本页只保留入口级断言：
// - 新增入口（FAB）与整卡点击都打开整页编辑器
// - 路由预填 pattern 时首帧后直接打开整页编辑器（pattern 已预填）
// - 整页保存新规则后返回列表且规则出现在列表
// 整页编辑器字段/保存/剪贴板等用例见 replace_rule_edit_test.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/rules/presentation/replace_rules_screen.dart';
import 'package:flutter_legado/src/widgets/help/help_screen.dart';

import '../mocks/mocks.dart';

/// 按 decoration labelText 定位输入框（当前 flutter_test 未提供
/// find.byLabel，以 byWidgetPredicate 等价实现）
Finder byLabel(String label) {
  return find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
}

void main() {
  late MockRustApi mockApi;

  setUpAll(() {
    registerFallbacks();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApi = MockRustApi();
    when(() => mockApi.replaceRuleRepository.getReplaceRules())
        .thenAnswer((_) async => []);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<ReplaceRule> rules = const [],
  }) async {
    when(() => mockApi.replaceRuleRepository.getReplaceRules())
        .thenAnswer((_) async => rules);
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...mockApi.overrides]),
        child: const MaterialApp(home: ReplaceRulesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ReplaceRulesScreen 整页编辑器入口（A3）', () {
    testWidgets('删除取消不写入，删除失败保留规则且不提示成功', (tester) async {
      const rule = ReplaceRule(id: 7, name: '待删除规则', pattern: '广告');
      when(() => mockApi.replaceRuleRepository.deleteReplaceRule(7))
          .thenThrow(StateError('删除失败夹具'));
      await pumpScreen(tester, rules: [rule]);
      Future<void> openDelete() async {
        await tester.tap(find.byTooltip('更多').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
      }

      await openDelete();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      verifyNever(() => mockApi.replaceRuleRepository.deleteReplaceRule(any()));
      await openDelete();
      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();
      verify(() => mockApi.replaceRuleRepository.deleteReplaceRule(7))
          .called(1);
      expect(find.text('待删除规则'), findsOneWidget);
      expect(find.text('规则已删除'), findsNothing);
      expect(find.textContaining('删除规则失败'), findsOneWidget);
    });

    testWidgets('新增入口仅使用FAB并打开整页编辑器', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Symbols.add_rounded),
        ),
        findsNothing,
      );
      expect(find.text('点击右下角 + 添加规则'), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // 整页渲染（非弹窗）：标题 + 关键字段
      expect(find.text('添加替换规则'), findsWidgets);
      for (final label in const ['规则名称', '匹配规则', '替换为', '预览输入']) {
        expect(find.text(label), findsOneWidget, reason: '缺少字段：$label');
      }
    });

    testWidgets('点击卡片打开整页编辑器并回填，不保留重复编辑按钮', (tester) async {
      const rule = ReplaceRule(
        id: 1,
        name: '去广告',
        pattern: '广告',
        replacement: '【广告】',
        scope: '某书',
      );
      when(() => mockApi.replaceRuleRepository.updateReplaceRule(any()))
          .thenAnswer((_) async {});
      await pumpScreen(tester, rules: [rule]);

      expect(find.byTooltip('编辑'), findsNothing);
      await tester.tap(find.text('去广告'));
      await tester.pumpAndSettle();

      expect(find.text('编辑替换规则'), findsWidgets);
      // 字段回填
      final nameField = tester.widget<TextField>(byLabel('规则名称'));
      expect(nameField.controller?.text, '去广告');
      final scopeField = tester.widget<TextField>(byLabel('特定范围'));
      expect(scopeField.controller?.text, '某书');
    });

    testWidgets('整页保存新规则后返回列表且规则出现在列表', (tester) async {
      when(() => mockApi.replaceRuleRepository.addReplaceRule(any()))
          .thenAnswer(
            (inv) async =>
                (inv.positionalArguments[0] as ReplaceRule).copyWith(id: 1),
          );
      await pumpScreen(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(byLabel('规则名称'), '去广告');
      await tester.enterText(byLabel('匹配规则'), '广告');
      await tester.enterText(byLabel('替换为'), '【广告】');
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 返回列表，新规则已入列表（notifier addRule 追加）
      expect(find.text('添加替换规则'), findsNothing);
      expect(find.text('去广告'), findsOneWidget);
      expect(find.text('正则: 广告 → 【广告】'), findsOneWidget);
    });

    testWidgets('路由预填 pattern 时首帧后直接打开整页编辑器', (tester) async {
      when(() => mockApi.replaceRuleRepository.addReplaceRule(any()))
          .thenAnswer((inv) async => const ReplaceRule());
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: mergeTestOverrides([...mockApi.overrides]),
          child: const MaterialApp(
            home: ReplaceRulesScreen(initialPattern: '选中词'),
          ),
        ),
      );
      // 首帧后 postFrame 回调打开编辑器
      await tester.pumpAndSettle();

      expect(find.text('添加替换规则'), findsWidgets);
      final patternField = tester.widget<TextField>(byLabel('匹配规则'));
      expect(patternField.controller?.text, '选中词');
    });
  });

  testWidgets('更多菜单保留三种导入、分组管理和帮助入口', (tester) async {
    await pumpScreen(tester);
    expect(find.byTooltip('导入'), findsNothing);
    expect(find.byTooltip('分组管理'), findsNothing);
    expect(find.byTooltip('帮助'), findsNothing);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    for (final title in ['本地导入', '网络导入', '二维码导入', '分组管理', '帮助']) {
      expect(find.widgetWithText(MenuItemButton, title), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(MenuItemButton, '网络导入'));
    await tester.pumpAndSettle();
    expect(find.text('从 URL 导入替换规则'), findsOneWidget);
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '分组管理'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('分组管理'), findsOneWidget);
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '帮助'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('批量模式隐藏添加FAB，退出后恢复', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('批量操作'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.byTooltip('退出批量模式'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手柄拖动保持圆角卡片，落位后顺序改变且整卡长按进入批量选择', (tester) async {
    await pumpScreen(
      tester,
      rules: [
        for (var i = 0; i < 3; i++)
          ReplaceRule(id: i + 1, name: '规则$i', pattern: '文本$i', order: i),
      ],
    );
    final handle = find.byType(ReorderableDragStartListener).first;
    final start = tester.getCenter(handle);
    final step =
        tester.getTopLeft(find.text('规则1')).dy -
        tester.getTopLeft(find.text('规则0')).dy;
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final card = find
        .ancestor(of: find.text('规则0'), matching: find.byType(Card))
        .last;
    final surface = find
        .descendant(of: card, matching: find.byType(Material))
        .first;
    final material = tester.widget<Material>(surface);
    expect(material.shape, isA<RoundedRectangleBorder>());
    // 拖动Overlay中不再有包住卡片外边距的矩形Material。
    expect(
      find.ancestor(of: card, matching: find.byType(Material)),
      findsNothing,
    );

    await gesture.moveTo(start + Offset(0, step * 2.2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('规则1')).dy,
      lessThan(tester.getTopLeft(find.text('规则0')).dy),
    );
    expect(tester.takeException(), isNull);

    await tester.longPress(find.text('规则0'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 1 项'), findsWidgets);
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.byType(ReorderableListView), findsNothing);
  });

  testWidgets('窄屏长列表末项能完整滚到添加FAB上方', (tester) async {
    await pumpScreen(
      tester,
      rules: [
        for (var i = 0; i < 30; i++)
          ReplaceRule(id: i + 1, name: '规则$i', pattern: '文本$i'),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(360, 640));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byType(ReorderableListView),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final lastCard = find
        .ancestor(of: find.text('规则29'), matching: find.byType(Card))
        .first;
    expect(lastCard.hitTestable(), findsOneWidget);
    expect(
      tester.getRect(lastCard).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(FloatingActionButton)).top),
    );
    expect(tester.takeException(), isNull);
  });
}
