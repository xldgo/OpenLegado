// 普通表单输入主题回归：按用户授权统一为 12dp 圆角填充与描边。
// 沿用既有用例，更新历史 B3 输入形态的断言。
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/theme/app_theme.dart';

void main() {
  /// 统一输入框四角形状。
  const expectedRadius = BorderRadius.all(Radius.circular(12));

  final themes = <String, ThemeData>{
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  };

  for (final MapEntry(key: label, value: theme) in themes.entries) {
    final deco = theme.inputDecorationTheme;
    final scheme = theme.colorScheme;

    group('inputDecorationTheme 统一形态（$label）', () {
      test('填充盒：filled + surfaceContainerLow 底', () {
        expect(deco.filled, isTrue);
        expect(deco.fillColor, scheme.surfaceContainerLow);
      });

      test('未聚焦（border/enabledBorder）：统一细描边', () {
        for (final (name, border) in [
          ('border', deco.border),
          ('enabledBorder', deco.enabledBorder),
        ]) {
          expect(border, isA<OutlineInputBorder>(), reason: '$name 应为圆角描边');
          expect(
            border,
            isNot(isA<UnderlineInputBorder>()),
            reason: '$name 不再使用旧下划线形态',
          );
          final outline = border! as OutlineInputBorder;
          expect(
            outline.borderSide.color,
            scheme.outlineVariant,
            reason: '$name 普通态使用 outlineVariant',
          );
          expect(outline.borderSide.width, 1, reason: '$name 普通态为 1dp 细线');
          expect(outline.borderRadius, expectedRadius, reason: '$name 四角应保持一致');
        }
      });

      test('聚焦（focusedBorder）：主题色 2dp 描边与四角圆角', () {
        final border = deco.focusedBorder;
        expect(border, isA<OutlineInputBorder>());
        expect(
          border,
          isNot(isA<UnderlineInputBorder>()),
          reason: '聚焦态不再使用旧下划线形态',
        );
        final outline = border! as OutlineInputBorder;
        expect(outline.borderSide.color, scheme.primary);
        expect(outline.borderSide.width, 2);
        expect(outline.borderRadius.topLeft, const Radius.circular(12));
        expect(outline.borderRadius.topRight, const Radius.circular(12));
        expect(outline.borderRadius.bottomLeft, const Radius.circular(12));
        expect(outline.borderRadius.bottomRight, const Radius.circular(12));
      });

      test('生效链：无局部覆盖的字段解析为圆角描边', () {
        final merged = const InputDecoration(hintText: 'h').applyDefaults(deco);
        expect(merged.border, isA<OutlineInputBorder>());
        expect(merged.border!.isOutline, isTrue, reason: '字段沿用圆角描边的标签布局');
        expect(
          (merged.border! as OutlineInputBorder).borderRadius,
          expectedRadius,
        );
      });

      testWidgets('经 MaterialApp 落到真实字段：未聚焦解析出统一描边', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(body: TextField()),
          ),
        );
        final context = tester.element(find.byType(TextField));
        final resolved = Theme.of(context).inputDecorationTheme;
        expect(resolved.enabledBorder, isA<OutlineInputBorder>());
        expect(
          (resolved.enabledBorder! as OutlineInputBorder).borderSide.color,
          Theme.of(context).colorScheme.outlineVariant,
        );
      });
    });
  }
}
