import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_legado/app.dart';
import 'package:flutter_legado/src/app/routing/startup_default_to_read.dart';
import 'package:flutter_legado/src/app/routing/startup_reading_navigation.dart';
import 'package:flutter_legado/src/features/imports/presentation/association_import_dialog.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/services/auto_task_scheduler.dart';
import 'package:flutter_legado/src/services/platform_bridge_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/app_test_api.dart';

void main() {
  testWidgets('正式应用等待迟到的初始深链，导入关闭后也不自动开读', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('legado/deep_link');
    final initial = Completer<String?>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) => initial.future);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    final opened = <Book>[];
    final navigation = StartupReadingNavigation(
      open: (book, current) async {
        if (current()) opened.add(book);
      },
      onError: (error, _) => fail('$error'),
    );
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        startupDefaultToReadProvider.overrideWith(
          (ref) async => const Book(bookUrl: 'last', name: '上次阅读'),
        ),
        startupReadingNavigationProvider.overrideWithValue(navigation),
      ]),
    );
    addTearDown(container.dispose);
    addTearDown(AutoTaskScheduler.instance.cancelAll);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const LegadoApp()),
    );
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    initial.complete('legado://import/bookSource');
    // 直接检查真实弹窗和返回后的行为，不等待输入框的持续动效。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AssociationImportDialog), findsOneWidget);
    expect(opened, isEmpty);
    PlatformBridgeService.navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AssociationImportDialog), findsNothing);
    expect(opened, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
