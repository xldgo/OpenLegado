import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/app/bootstrap/application_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/application_scope.dart';

void main() {
  testWidgets('根节点卸载释放同一应用容器及已创建Provider', (tester) async {
    var disposed = false;
    final dependency = Provider<int>((ref) {
      ref.onDispose(() => disposed = true);
      return 7;
    });
    final container = createApplicationContainer(useMock: true);
    await tester.pumpWidget(
      ApplicationScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) => Text(
            '${ref.watch(dependency)}',
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
    expect(find.text('7'), findsOneWidget);
    expect(disposed, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(disposed, isTrue);
  });
}
