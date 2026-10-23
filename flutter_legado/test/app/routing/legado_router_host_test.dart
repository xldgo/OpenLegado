import 'package:flutter_legado/src/features/logs/presentation/app_log_screen.dart';
import 'package:flutter_legado/src/providers/theme/theme_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/app.dart';
import 'package:flutter_legado/src/app/routing/app_navigation.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/services/platform_bridge_service.dart';
import 'package:flutter_legado/src/services/auto_task_scheduler.dart';

import '../../fixtures/app_test_api.dart';

void main() {
  testWidgets('正式应用根创建Router并保留全局导航及主题重建后的栈', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: mergeTestOverrides(MockBookApi().overrides),
    );
    addTearDown(container.dispose);
    addTearDown(AutoTaskScheduler.instance.cancelAll);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LegadoApp(
          initialRoute: AppRoutes.about,
          glassAvailable: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final navigator = PlatformBridgeService.navigatorKey.currentState;
    expect(navigator, isNotNull);
    final router = GoRouter.of(navigator!.context);
    expect(router.state.uri.path, AppRoutes.about);
    router.pushAppRoute(AppRoutes.appLog);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.appLog);
    final pageContext = tester.element(find.byType(AppLogScreen));
    final route = ModalRoute.of(pageContext);
    await container
        .read(themeNotifierProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(identical(GoRouter.of(navigator.context), router), isTrue);
    expect(
      identical(
        ModalRoute.of(tester.element(find.byType(AppLogScreen))),
        route,
      ),
      isTrue,
    );
    expect(
      Theme.of(tester.element(find.byType(AppLogScreen))).brightness,
      Brightness.dark,
    );
    expect(router.state.uri.path, AppRoutes.appLog);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
