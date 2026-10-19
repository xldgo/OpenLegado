import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_legado/src/providers/theme/system_bar_controller.dart';
import 'package:flutter_legado/src/widgets/system_bar_binder.dart';

void main() {
  late ProviderContainer container;
  late SystemBarController controller;
  late List<ApplicationSystemBars> applied;
  void initialize() {
    applied = [];
    controller = SystemBarController(
      applyApplication: (bars) async => applied.add(bars),
      applyReader: (_) async {},
    );
    container = ProviderContainer(
      overrides: [systemBarControllerProvider.overrideWithValue(controller)],
    );
    addTearDown(() {
      container.dispose();
      controller.dispose();
    });
  }

  Future<void> show(WidgetTester tester, Color top, Color bottom) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            appBarTheme: AppBarThemeData(backgroundColor: top),
            navigationBarTheme: NavigationBarThemeData(backgroundColor: bottom),
          ),
          home: const SystemBarBinder(child: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('首帧直接同步主题，主题变化与前台恢复更新当前应用样式', (tester) async {
    initialize();
    await show(tester, Colors.white, Colors.grey);
    expect(applied.single, (
      appBarColor: Colors.white,
      navigationBarColor: Colors.grey,
    ));
    await show(tester, Colors.black, Colors.blue);
    expect(applied.last, (
      appBarColor: Colors.black,
      navigationBarColor: Colors.blue,
    ));
    final count = applied.length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(applied.length, count + 1);
    expect(applied.last, (
      appBarColor: Colors.black,
      navigationBarColor: Colors.blue,
    ));
  });

  testWidgets('阅读器拥有显隐时主题只更新待恢复样式，退出后应用最新主题', (tester) async {
    initialize();
    await show(tester, Colors.white, Colors.grey);
    final reader = Object();
    controller.updateReader(reader, (
      statusBarVisible: false,
      navigationBarVisible: false,
    ));
    await tester.pumpAndSettle();
    await show(tester, Colors.black, Colors.blue);
    expect(applied, [
      (appBarColor: Colors.white, navigationBarColor: Colors.grey),
    ]);
    controller.releaseReader(reader);
    await tester.pumpAndSettle();
    expect(applied.last, (
      appBarColor: Colors.black,
      navigationBarColor: Colors.blue,
    ));
  });
}
