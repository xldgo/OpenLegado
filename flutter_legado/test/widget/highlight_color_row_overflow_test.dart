import '../fixtures/app_test_api.dart';

// 「新增高亮规则」弹窗颜色行窄屏溢出回归测试
//
// 缺陷证据：MuMu 实机截图 .tmp/b3_ours_hl_dialog.png —— 360dp 逻辑宽设备上
// 新增弹窗颜色行报 RIGHT OVERFLOWED BY 16 PIXELS。
// 成因：颜色行 8 个 32dp 色块 + 每块右侧 10dp 间距 = 336dp，
// 而弹窗内容可用宽仅 360 - 20*2 = 320dp → 溢出 16dp。
// 本测试固定 360dp（QA 取证机 1080px / dpr3 的逻辑宽）复现：
// 修复前 takeException 非空（RenderFlex 溢出），颜色行改 Wrap 换行后为空。
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/features/rules/presentation/highlight_rules_screen.dart';

import '../mocks/mocks.dart';

void main() {
  late MockRustApi mockApi;

  setUp(() {
    mockApi = MockRustApi();
    when(() => mockApi.highlightRuleRepository.highlightRuleList())
        .thenAnswer((_) async => []);
  });

  /// 弹窗内圆形色块（ColorScheme 预设色板）
  ///
  /// 限定在 modal BottomSheet 子树内：顶栏 action 按钮（TopBarButton）
  /// 同样是圆形 Container，不限定作用域会误计入。
  Finder circleSwatches() => find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle,
    ),
  );

  /// 选中态色块（primary 描边）
  bool isSelected(Widget w, ColorScheme cs) {
    if (w is! Container) return false;
    final d = w.decoration;
    if (d is! BoxDecoration || d.shape != BoxShape.circle) return false;
    final b = d.border;
    return b is Border && b.top.color == cs.primary;
  }

  testWidgets('360dp 窄屏：新增高亮规则弹窗颜色行不溢出且色块可点选', (tester) async {
    // 复现 QA 取证机逻辑宽：1080px @ dpr3 = 360dp
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...mockApi.overrides]),
        child: const MaterialApp(home: HighlightRulesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('新增高亮规则'), findsOneWidget);

    // 色板 8 色全量渲染（换行后不裁切、不丢失）
    final palette = find.descendant(
      of: find.byKey(const ValueKey('highlight-color-textColor')),
      matching: circleSwatches(),
    );
    expect(palette, findsNWidgets(8));

    // 修复前：颜色行 RenderFlex 向右溢出 16px，测试框架记录为异常
    expect(
      tester.takeException(),
      isNull,
      reason: '颜色行不应触发 RenderFlex 溢出（RIGHT OVERFLOWED BY 16 PIXELS）',
    );

    await tester.ensureVisible(palette.last);
    await tester.tap(palette.last);
    await tester.pump();
    // 换行后末尾色块仍可命中：点选后末位选中、首位取消选中
    // （注：预设色板中 primaryFixedDim 与 inversePrimary 同色，两同色块会
    // 一同显示描边，属色板取值现状，本测试仅断言点选生效）
    final cs = Theme.of(tester.element(find.text('文字颜色'))).colorScheme;
    final containers = tester.widgetList<Container>(palette).toList();
    expect(isSelected(containers.last, cs), isTrue);
    expect(isSelected(containers.first, cs), isFalse);
    expect(tester.takeException(), isNull);
  });
}
