import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';
import 'package:flutter_legado/src/features/reader/presentation/reader_screen.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/platform/display/screen_awake.dart';
import 'package:flutter_legado/src/providers/screen_awake_provider.dart';
import 'package:flutter_legado/src/utils/app_route_observer.dart';

import '../../../fixtures/app_test_api.dart';

/// 真实页面加载态隔离Rust，验证设置、路由及平台生命周期接线。— Codex + UI
class _Reader extends ReaderNotifier {
  @override
  ReaderState build() => const ReaderState(
    currentBook: Book(bookUrl: 'local/awake.txt', name: '保持亮屏'),
    chapters: [BookChapter(title: '第一章', index: 0)],
    isLoading: true,
    showControls: false,
  );
}

void main() {
  testWidgets(
    '真实阅读页触摸重计时，弹层保留，覆盖/后台/退出释放',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'enableReadRecord': false,
        'reader_keep_screen_on_seconds': 300,
      });
      final calls = <bool>[];
      final navigator = GlobalKey<NavigatorState>();
      final container = ProviderContainer(
        overrides: mergeTestOverrides([
          ...MockBookApi().overrides,
          readerNotifierProvider.overrideWith(_Reader.new),
          screenAwakeProvider.overrideWithValue(
            ScreenAwake(toggle: (value) async => calls.add(value)),
          ),
        ]),
      );
      addTearDown(container.dispose);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await container.read(readerSettingsRepositoryProvider).load();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [systemBarRouteObserver],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const ReaderScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.last, isTrue);
      await tester.pump(const Duration(seconds: 250));
      final gesture = await tester.startGesture(const Offset(20, 100));
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 250));
      expect(calls.last, isTrue);
      await tester.pump(const Duration(seconds: 51));
      expect(calls.last, isFalse);
      // 其他屏幕设置引起重建不应重新获取。
      await container
          .read(readerSettingsRepositoryProvider)
          .updateScreen(avoidDisplayCutouts: true);
      await tester.pumpAndSettle();
      expect(calls.last, isFalse);
      await container
          .read(readerSettingsRepositoryProvider)
          .updateScreen(keepScreenOnSeconds: -1);
      await tester.pumpAndSettle();
      expect(calls.last, isTrue);
      unawaited(
        showModalBottomSheet<void>(
          context: tester.element(find.byType(ReaderScreen)),
          builder: (_) => const SizedBox(height: 100),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.last, isTrue);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(builder: (_) => const Scaffold(body: Text('其他页面'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.last, isFalse);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(calls.last, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(calls.last, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls.last, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(calls.last, isFalse);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
