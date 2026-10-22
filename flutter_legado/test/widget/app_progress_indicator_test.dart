import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/widgets/app_progress_indicator.dart';
import 'package:flutter_test/flutter_test.dart';

/// [STAGE-UI-P43UNIFY2 B3] 统一封装三件套 widget 测试
///
/// 仅保留进度模式与无障碍语义，不逐项复述装饰参数。
void main() {
  Future<void> pumpCircular(WidgetTester tester, {double? progress}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: AppCircularProgressIndicator(progress: progress)),
        ),
      ),
    );
  }

  group('AppCircularProgressIndicator', () {
    testWidgets('未传进度时显示不确定进度', (tester) async {
      await pumpCircular(tester);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, isNull, reason: '不传 progress = indeterminate');
    });

    testWidgets('progress 确定性模式：value 透传 0~1 区间', (tester) async {
      await pumpCircular(tester, progress: 0.42);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(
        indicator.value,
        0.42,
        reason: '确定性模式 value 透传（SDK 环 value 即 0~1 比例）',
      );
    });

    testWidgets('语义标签默认「加载中」', (tester) async {
      await pumpCircular(tester);
      expect(
        find.bySemanticsLabel('加载中'),
        findsOneWidget,
        reason: '默认 semanticsLabel 暴露到无障碍树',
      );
    });
  });

  group('AppLinearProgressIndicator', () {
    Future<void> pumpLinear(WidgetTester tester, {double? progress}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: AppLinearProgressIndicator(progress: progress)),
          ),
        ),
      );
    }

    testWidgets('未传进度时显示不确定进度', (tester) async {
      await pumpLinear(tester);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, isNull, reason: '不传 progress = indeterminate');
    });

    testWidgets('progress 确定性模式：value 透传 0~1 区间', (tester) async {
      await pumpLinear(tester, progress: 0.6);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(
        indicator.value,
        0.6,
        reason: '确定性模式 value 透传（SDK 线 value 即 0~1 比例）',
      );
    });
  });
}
