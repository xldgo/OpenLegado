import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Theme, ThemeData;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/skeleton.dart';
import 'package:flutter_legado/src/widgets/app_search_transition.dart';

Widget _host(Widget child, {bool reduced = false, bool ticking = true}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: TickerMode(
        enabled: ticking,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: ThemeData(),
            child: Center(child: child),
          ),
        ),
      ),
    );

void main() {
  testWidgets('骨架扫光响应减少动态效果与页面停用，恢复后才继续请求帧', (tester) async {
    const box = SkeletonBox(width: 80, height: 20);
    await tester.pumpWidget(_host(box));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(_host(box, reduced: true));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(_host(box));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(_host(box, ticking: false));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('应用进入后台停止骨架时钟，返回前台恢复，退出不留观察者', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(_host(const SkeletonBox(width: 80, height: 20)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('搜索展开中切换减少动态效果即时到目标，收起不残留输入层', (tester) async {
    var progress = 0.0;
    Widget content(bool expanded) => AppSearchTransition(
      expanded: expanded,
      builder: (_, value) {
        progress = value;
        return const SizedBox(width: 80, height: 20);
      },
    );
    await tester.pumpWidget(_host(content(false)));
    await tester.pumpWidget(_host(content(true)));
    await tester.pump(const Duration(milliseconds: 60));
    expect(progress, inExclusiveRange(0.0, 1.0));
    await tester.pumpWidget(_host(content(true), reduced: true));
    expect(progress, 1);
    await tester.pumpWidget(_host(content(false), reduced: true));
    expect(progress, 0);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
