@Tags(['native'])
library;

import '../fixtures/app_test_api.dart';
import '../helpers/native_reader_layout.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_view.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';
import 'package:flutter_legado/src/widgets/reader/turn/reader_turn_view.dart';

class _Reader extends ReaderNotifier {
  @override
  ReaderState build() => ReaderState(
    chapters: const [BookChapter(title: '测试章节', index: 0)],
    chapterContent: List.filled(30, '这是用于检验字号缩放与屏幕尺寸变化的小说正文。' * 3).join('\n'),
    pageTurnMode: PageTurnMode.none,
  );
}

void main() {
  setUpNativeReaderLayout();
  testWidgets('系统字体缩放和屏幕宽度变化会使真实阅读器重新分页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final key = GlobalKey<ReaderPageViewState>();
    Future<void> pump(
      double width,
      double scale, {
      int count = 0,
      bool bottomJustify = true,
      EdgeInsets insets = EdgeInsets.zero,
      bool outerInsets = false,
    }) async {
      await pumpNativeReaderLayout(
        tester,
        ProviderScope(
          overrides: mergeTestOverrides([
            ...MockBookApi().overrides,
            readerNotifierProvider.overrideWith(_Reader.new),
          ]),
          child: MaterialApp(
            builder: nativeReaderLayoutBuilder,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  height: 500,
                  child: MediaQuery(
                    data: MediaQueryData(
                      // 屏幕可比阅读面板更大；分页必须消费面板约束。
                      size: const Size(900, 900),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Padding(
                      padding: outerInsets ? insets : EdgeInsets.zero,
                      child: ReaderPageView(
                        key: key,
                        paragraphSpacing: 8,
                        selectText: false,
                        textBottomJustify: bottomJustify,
                        reviewCounts: {1: count},
                        contentInsets: outerInsets ? null : insets,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settleNativeReaderLayout(tester);
      await tester.pump(const Duration(milliseconds: 1));
    }

    await pump(500, 1);
    final wide = key.currentState!.pageCount;
    key.currentState!.goToPage(2);
    await settleNativeReaderLayout(tester);
    final anchor = ProviderScope.containerOf(
      tester.element(find.byType(ReaderPageView)),
    ).read(readerNotifierProvider.notifier).currentSourceOffset!;
    expect(anchor, greaterThan(0));
    await pump(320, 1);
    final narrow = key.currentState!.pageCount;
    expect(narrow, greaterThan(wide));
    expect(key.currentState!.currentSourceRange.$1, lessThanOrEqualTo(anchor));
    expect(key.currentState!.currentSourceRange.$2, greaterThan(anchor));
    await pump(320, 2, count: 9);
    final layout = tester
        .widget<ReaderTextContent>(find.byType(ReaderTextContent).first)
        .pageInfo;
    await pump(320, 2, count: 1000);
    expect(
      identical(
        layout,
        tester
            .widget<ReaderTextContent>(find.byType(ReaderTextContent).first)
            .pageInfo,
      ),
      isTrue,
    );
    await pump(320, 2);
    expect(key.currentState!.currentSourceRange.$1, lessThanOrEqualTo(anchor));
    expect(key.currentState!.currentSourceRange.$2, greaterThan(anchor));
    await pump(320, 2);
    expect(key.currentState!.pageCount, greaterThan(narrow));
    expect(key.currentState!.currentSourceRange.$1, lessThanOrEqualTo(anchor));
    expect(key.currentState!.currentSourceRange.$2, greaterThan(anchor));
    final beforeToggle = key.currentState!.layoutMeasurements;
    await pump(320, 2, bottomJustify: false);
    expect(key.currentState!.layoutMeasurements, greaterThan(beforeToggle));
    expect(key.currentState!.currentSourceRange.$1, lessThanOrEqualTo(anchor));
    expect(key.currentState!.currentSourceRange.$2, greaterThan(anchor));
    // 同样的内容容量下，内部避让应保持分页和位置，但扩大翻页画布。
    const insets = EdgeInsets.fromLTRB(12, 40, 16, 20);
    await pump(500, 1, insets: insets, outerInsets: true);
    final insetPageCount = key.currentState!.pageCount;
    final insetSourceRange = key.currentState!.currentSourceRange;
    expect(tester.getSize(find.byType(ReaderTurnView)), const Size(472, 440));
    await pump(500, 1, insets: insets);
    expect(key.currentState!.pageCount, insetPageCount);
    expect(key.currentState!.currentSourceRange, insetSourceRange);
    expect(tester.getSize(find.byType(ReaderTurnView)), const Size(500, 500));
    expect(tester.takeException(), isNull);
  });
}
