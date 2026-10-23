import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/widgets/app_progress_indicator.dart';
import 'package:flutter_test/flutter_test.dart';

/// 保留项目封装的无障碍标签，不复测原生进度条的模式与数值透传。
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
    testWidgets('语义标签默认「加载中」', (tester) async {
      await pumpCircular(tester);
      expect(
        find.bySemanticsLabel('加载中'),
        findsOneWidget,
        reason: '默认 semanticsLabel 暴露到无障碍树',
      );
    });
  });
}
