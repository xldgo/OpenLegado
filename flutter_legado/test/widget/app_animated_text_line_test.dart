import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/app_animated_text_line.dart';

void main() {
  Widget host(
    String text, {
    bool disabled = false,
    bool rtl = false,
    double fontSize = 14,
  }) => MediaQuery(
    data: MediaQueryData(
      disableAnimations: disabled,
      textScaler: TextScaler.linear(2),
    ),
    child: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 140,
          child: AppAnimatedTextLine(
            text,
            style: TextStyle(fontSize: fontSize, height: 1.2),
          ),
        ),
      ),
    ),
  );

  double offset(WidgetTester tester, String text) => tester
      .widget<FractionalTranslation>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(FractionalTranslation),
            )
            .first,
      )
      .translation
      .dy;

  testWidgets('整行旧字向上、新字从下进入，不叠加透明度动画', (tester) async {
    await tester.pumpWidget(host('阅读记录'));
    final height = tester.getSize(find.byType(AppAnimatedTextLine)).height;
    await tester.pumpWidget(host('已选 1 项'));
    expect(offset(tester, '阅读记录'), 0);
    expect(offset(tester, '已选 1 项'), 1);
    await tester.pump(const Duration(milliseconds: 70));
    expect(offset(tester, '阅读记录'), inExclusiveRange(-1.0, 0.0));
    expect(offset(tester, '已选 1 项'), inExclusiveRange(0.0, 1.0));
    expect(tester.getSize(find.byType(AppAnimatedTextLine)).height, height);
    expect(
      find.descendant(
        of: find.byType(AppAnimatedTextLine),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppAnimatedTextLine),
        matching: find.byType(ClipRect),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.text('阅读记录'), findsNothing);
    expect(offset(tester, '已选 1 项'), closeTo(0, 0.001));
  });

  testWidgets('快速连续替换和反向切回不跳位，无旧文字语义或残留', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host('阅读记录'));
    await tester.pumpWidget(host('已选 1 项'));
    await tester.pump(const Duration(milliseconds: 40));
    final before = offset(tester, '已选 1 项');
    await tester.pumpWidget(host('已选 2 项'));
    expect(offset(tester, '已选 1 项'), before);
    await tester.pump(const Duration(milliseconds: 40));
    final semanticsTree = tester
        .getSemantics(find.byType(AppAnimatedTextLine))
        .toStringDeep();
    expect(semanticsTree, isNot(contains('已选 1 项')));
    expect(semanticsTree, contains('已选 2 项'));
    await tester.pumpWidget(host('阅读记录'));
    await tester.pumpAndSettle();
    expect(find.text('阅读记录'), findsOneWidget);
    expect(find.text('已选 1 项'), findsNothing);
    expect(find.text('已选 2 项'), findsNothing);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动态效果即时清理退场文字，切换后和中途销毁均安全', (tester) async {
    await tester.pumpWidget(host('阅读记录'));
    await tester.pumpWidget(host('已选 1 项'));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(host('已选 1 项', disabled: true));
    expect(find.text('阅读记录'), findsNothing);
    expect(offset(tester, '已选 1 项'), 0);
    await tester.pumpWidget(host('已选 2 项', disabled: true));
    expect(find.text('已选 1 项'), findsNothing);
    expect(offset(tester, '已选 2 项'), 0);
    await tester.pumpWidget(host('阅读记录', rtl: true));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄宽度和大字号保持单行省略，样式更新不触发文字切换', (tester) async {
    await tester.pumpWidget(host('点按项目选择，返回退出', rtl: true));
    expect(tester.getSize(find.byType(AppAnimatedTextLine)).width, 140);
    final text = tester.widget<Text>(find.text('点按项目选择，返回退出'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    await tester.pumpWidget(host('点按项目选择，返回退出', fontSize: 16));
    expect(find.byType(Text), findsOneWidget);
    expect(tester.widget<Text>(find.text('点按项目选择，返回退出')).style!.fontSize, 16);
    expect(offset(tester, '点按项目选择，返回退出'), 0);
    expect(tester.takeException(), isNull);
  });
}
