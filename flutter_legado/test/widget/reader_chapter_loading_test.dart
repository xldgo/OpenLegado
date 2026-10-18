import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/widgets/md3_loading_indicator.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_view.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';

import '../fixtures/app_test_api.dart';
import '../helpers/native_reader_layout.dart';

class _LoadingReader extends ReaderNotifier {
  @override
  ReaderState build() => const ReaderState(
    currentBook: Book(
      bookUrl: 'loc_book/loading.txt',
      name: '章节加载测试',
      origin: BookType.localTag,
    ),
    chapters: [BookChapter(title: '第一章', index: 0)],
    isLoading: true,
    showControls: false,
    pageTurnMode: PageTurnMode.none,
  );

  void finishLoading() {
    state = state.copyWith(
      isLoading: false,
      chapterContent: List.filled(20, '用于验证章节加载后恢复正文，切章等待时保留原页面。').join('\n'),
    );
  }

  void startLoading() => state = state.copyWith(isLoading: true);
}

void main() {
  setUpNativeReaderLayout();

  testWidgets('章节加载使用 Glass spinner，减少动画时静止，加载完成后恢复正文', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final reader = _LoadingReader();
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        readerNotifierProvider.overrideWith(() => reader),
      ]),
    );
    addTearDown(container.dispose);

    Future<void> mount({bool reducedMotion = false}) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reducedMotion),
            child: nativeReaderLayoutBuilder(context, child),
          ),
          home: const Scaffold(body: ReaderPageView(paragraphSpacing: 10)),
        ),
      ),
    );

    await mount();
    expect(find.byType(GlassProgressIndicator), findsOneWidget);
    expect(find.byType(Md3LoadingIndicator), findsNothing);
    expect(find.text('加载章节...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await mount(reducedMotion: true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(GlassProgressIndicator), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await mount();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    reader.finishLoading();
    await tester.pump();
    await settleNativeReaderLayout(tester);
    expect(find.byType(GlassProgressIndicator), findsNothing);
    expect(find.byType(ReaderTextContent), findsWidgets);

    reader.startLoading();
    await tester.pump();
    expect(find.byType(GlassProgressIndicator), findsNothing);
    expect(find.byType(ReaderTextContent), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await settleNativeReaderLayout(tester);
  });
}
