import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/widgets/app_snack_bar.dart';

void main() {
  testWidgets('默认排队，显式替换且保留操作按钮', (tester) async {
    late BuildContext host;
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              host = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    showAppSnackBar(host, '第一条');
    await tester.pumpAndSettle();
    showAppSnackBar(host, '第二条');
    await tester.pump();
    expect(find.text('第一条'), findsOneWidget);
    expect(find.text('第二条'), findsNothing);
    showAppSnackBar(
      host,
      '第三条',
      replaceCurrent: true,
      action: SnackBarAction(label: '重试', onPressed: () => retried = true),
    );
    await tester.pumpAndSettle();
    // 替换只隐藏当前项，已排队消息仍按原顺序展示。
    expect(find.text('第二条'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('第三条'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retried, isTrue);
  });

  testWidgets('页面卸载后的迟到提示安全忽略', (tester) async {
    late BuildContext page;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              page = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    showAppSnackBar(page, '迟到消息');
    expect(tester.takeException(), isNull);
  });
}
