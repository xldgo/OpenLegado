import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/contracts/settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/features/appearance/appearance.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/theme/system_bar_controller.dart';
import 'package:flutter_legado/src/providers/theme/system_bar_notifier.dart';
import 'package:flutter_legado/src/widgets/system_bar_binder.dart';

void main() {
  late _Storage storage;
  late ProviderContainer container;
  late List<ApplicationSystemBars> applied;

  Future<void> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    storage = _Storage();
    applied = [];
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    final controller = SystemBarController(
      applyApplication: (configuration) async => applied.add(configuration),
      applyReader: (_) async {},
    );
    container = ProviderContainer(
      overrides: [
        appSettingsServiceProvider.overrideWithValue(service),
        systemBarControllerProvider.overrideWithValue(controller),
      ],
    );
    addTearDown(() {
      container.dispose();
      controller.dispose();
      unawaited(service.dispose());
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SystemBarBinder(child: ThemeConfigScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    storage.fail = true;
  }

  Future<void> reveal(WidgetTester tester, String label) async {
    await tester.dragUntilVisible(
      find.text(label),
      find.byType(ListView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
  }

  for (final statusBar in [true, false]) {
    final label = statusBar ? '沉浸式状态栏' : '沉浸式导航栏';
    testWidgets('$label 保存失败提示回退，重试同步现有系统栏控制器', (tester) async {
      await open(tester);
      await reveal(tester, label);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      final failed = container.read(systemBarProvider);
      expect(
        statusBar ? failed.transparentStatusBar : failed.immNavigationBar,
        isTrue,
      );
      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(applied.last.transparentStatusBar, isTrue);
      expect(applied.last.immNavigationBar, isTrue);
      storage.fail = false;
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(
        statusBar
            ? applied.last.transparentStatusBar
            : applied.last.immNavigationBar,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

class _Storage implements SettingsStorage {
  final values = <String, Object?>{};
  bool fail = false;

  @override
  Future<Object?> read(String key) async => values[key];

  @override
  Future<void> write(String key, Object? value) async {
    if (fail) throw StateError('模拟系统栏保存失败');
    values[key] = value;
  }
}
