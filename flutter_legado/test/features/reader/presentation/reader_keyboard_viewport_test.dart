import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/features/bookmarks/bookmarks.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/features/reader/presentation/reader_screen.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/reader/widgets/reader_page_view.dart';

import '../../../fixtures/app_test_api.dart';

// 使用加载态隔离文字测量与Rust，只验证真实阅读页和弹层的视口约束。— Codex + UI
class _Reader extends ReaderNotifier {
  @override
  ReaderState build() => const ReaderState(
    currentBook: Book(bookUrl: 'local/keyboard.txt', name: '键盘视口'),
    chapters: [BookChapter(title: '第一章', index: 0)],
    isLoading: true,
    showControls: false,
  );
}

void main() {
  testWidgets(
    '书签键盘只避让弹层，正文视口稳定且仍响应窗口尺寸变化',
    (tester) async {
      SharedPreferences.setMockInitialValues({'enableReadRecord': false});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: mergeTestOverrides([
          ...MockBookApi().overrides,
          readerNotifierProvider.overrideWith(_Reader.new),
        ]),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const ReaderScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final viewport = find.byType(ReaderPageView);
      final before = tester.getRect(viewport);
      final page = tester.state(viewport);
      String? saved;
      unawaited(
        BookmarkNoteSheet.show(
          context: tester.element(viewport),
          bookText: '书签原文',
          chapterName: '第一章',
          onSave: (note) async => saved = note,
        ),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport), before);
      expect(identical(tester.state(viewport), page), isTrue);
      final save = find.byKey(const ValueKey('bookmark-note-save'));
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(844 - 320));
      expect(save.hitTestable(), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('bookmark-note')), '备注');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, '备注');
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport), before);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.getSize(viewport), const Size(844, 390));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
