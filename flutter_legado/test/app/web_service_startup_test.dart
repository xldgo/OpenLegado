import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/app.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/providers/app_services_provider.dart';
import 'package:flutter_legado/src/services/auto_task_scheduler.dart';

import '../fixtures/app_test_api.dart';

void main() {
  testWidgets('应用启动无需进入设置页即恢复Web服务，前台恢复不撤销手动停止', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = MockBookApi();
    await api.configRepository.setConfig('webServiceAutoStart', 'true');
    final container = ProviderContainer(
      overrides: mergeTestOverrides(api.overrides),
    );
    addTearDown(container.dispose);
    addTearDown(AutoTaskScheduler.instance.cancelAll);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LegadoApp(initialRoute: AppRoutes.about),
      ),
    );
    await tester.pumpAndSettle();
    expect((await api.localServerService.getServerStatus()).running, isTrue);
    final controller = container.read(appServicesControllerProvider);
    expect(controller.state.web, isTrue);
    await controller.setWeb(false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect((await api.localServerService.getServerStatus()).running, isFalse);
    expect(controller.state.web, isFalse);
    expect(await api.configRepository.getConfig('webServiceAutoStart'), 'true');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
