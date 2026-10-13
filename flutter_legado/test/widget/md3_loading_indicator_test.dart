// MD3 波浪加载指示器组件测试
//
// 覆盖：结构渲染 / 语义标签 / message 展示 / 减少动画退化分支 /
// 动画推进稳定性（多帧泵不抛异常）。
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/widgets/loading_indicator.dart';
import 'package:flutter_legado/src/widgets/loading_overlay.dart';
import 'package:flutter_legado/src/widgets/md3_loading_indicator.dart';

Widget wrap(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('渲染波浪指示器并暴露语义标签', (tester) async {
    await tester.pumpWidget(wrap(const Md3LoadingIndicator()));
    await tester.pump();
    expect(find.byType(Md3LoadingIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 多帧推进动画稳定（相位/呼吸计算不抛异常）
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('LoadingIndicator 展示 message', (tester) async {
    await tester.pumpWidget(wrap(const LoadingIndicator(message: '加载书源...')));
    await tester.pump();
    expect(find.text('加载书源...'), findsOneWidget);
  });

  testWidgets('减少动画偏好下渲染静态弧分支', (tester) async {
    await tester.pumpWidget(
      wrap(const Md3LoadingIndicator(), disableAnimations: true),
    );
    await tester.pump();
    expect(find.byType(Md3LoadingIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);

    // 系统取消减少动画后恢复流动，再开启时停止，避免保留后台动画时钟。
    await tester.pumpWidget(wrap(const Md3LoadingIndicator()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(
      wrap(const Md3LoadingIndicator(), disableAnimations: true),
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('LoadingOverlay 遮罩含指示器与 message', (tester) async {
    await tester.pumpWidget(
      wrap(
        const LoadingOverlay(
          isLoading: true,
          message: '处理中',
          child: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LoadingOverlay), findsOneWidget);
    expect(find.text('处理中'), findsOneWidget);
  });
}
