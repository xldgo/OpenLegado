import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/app_content_transition.dart';

Widget _host(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('场景切换立即移除旧控制器子树，同一场景增量更新不重启动画', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    Widget scene(String key, int count) => AppSceneTransition(
      scene: key,
      child: SizedBox(
        width: 200,
        height: 200,
        child: ListView.builder(
          controller: scroll,
          itemExtent: 40,
          itemCount: count,
          itemBuilder: (_, i) => Text('$key条目$i'),
        ),
      ),
    );
    await tester.pumpWidget(_host(scene('result', 20)));
    scroll.jumpTo(160);
    await tester.pumpWidget(_host(scene('result', 30)));
    expect(scroll.offset, 160);
    expect(scroll.positions.length, 1);
    expect(
      tester
          .widget<FadeTransition>(
            find.descendant(
              of: find.byType(AppSceneTransition),
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value,
      1,
    );
    await tester.pumpWidget(_host(scene('history', 20)));
    expect(scroll.positions.length, 1);
    expect(find.textContaining('result条目'), findsNothing);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpWidget(_host(scene('result', 20), reduced: true));
    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(AppSceneTransition),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('动作组退场立即失去点击和读屏，快速反向不触发旧动作', (tester) async {
    final semantics = tester.ensureSemantics();
    var oldCalls = 0;
    var newCalls = 0;
    Widget actions(bool selected) => AppActionTransition(
      identity: selected,
      child: TextButton(
        onPressed: selected ? () => newCalls++ : () => oldCalls++,
        child: Text(selected ? '新动作' : '旧动作'),
      ),
    );
    await tester.pumpWidget(_host(actions(false)));
    await tester.pumpWidget(_host(actions(true)));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('新动作'));
    expect(newCalls, 1);
    expect(oldCalls, 0);
    final tree = tester
        .getSemantics(find.byType(AppActionTransition))
        .toStringDeep();
    expect(tree, contains('新动作'));
    expect(tree, isNot(contains('旧动作')));
    await tester.pumpWidget(_host(actions(false)));
    await tester.pumpAndSettle();
    expect(find.text('新动作'), findsNothing);
    await tester.tap(find.text('旧动作'));
    expect(oldCalls, 1);
    semantics.dispose();
  });

  testWidgets('选择标记连续显隐保持子树，减少动态效果即时收起', (tester) async {
    final key = GlobalKey();
    Widget indicator(bool visible) => AppSelectionReveal(
      visible: visible,
      child: SizedBox(key: key, width: 30, height: 20),
    );
    await tester.pumpWidget(_host(indicator(false)));
    final element = key.currentContext;
    expect(tester.getSize(find.byType(AppSelectionReveal)).width, 0);
    await tester.pumpWidget(_host(indicator(true)));
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.getSize(find.byType(AppSelectionReveal)).width,
      inExclusiveRange(0.0, 30.0),
    );
    await tester.pumpWidget(_host(indicator(false), reduced: true));
    expect(tester.getSize(find.byType(AppSelectionReveal)).width, 0);
    expect(key.currentContext, same(element));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
