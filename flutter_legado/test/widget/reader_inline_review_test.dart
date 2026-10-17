import '../helpers/native_reader_layout.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/widgets/reader/review_column.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';
import 'package:flutter_legado/src/widgets/reader/reader_selection_controller.dart';
import 'package:flutter_legado/src/widgets/reader/reader_selection_region.dart';
import 'package:flutter_legado/src/widgets/reader/text_layout_environment.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' show BridgeError;

void main() {
  setUpNativeReaderLayout();
  for (final scale in [1.0, 2.0]) {
    testWidgets('段评只改变尾行，测绘同参且原生全选排除角标，缩放$scale', (tester) async {
      final controller = ReaderSelectionController();
      addTearDown(controller.dispose);
      final source = '${'甲乙丙丁戊己庚辛' * 4}。';
      late List<PageInfo> pages;
      late List<PageInfo> plain;
      var tapped = 0;
      await pumpNativeReaderLayout(
        tester,
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: LayoutTestBuilder(
                  builder: (context) async {
                    final engine = ParagraphLayoutEngine(
                      transport: nativeReaderLayout,
                      context: context,
                      config: ParagraphConfig(
                        fontSize: 16,
                        lineHeight: 1.6,
                        justify: false,
                        textEnvironment: TextLayoutEnvironment.of(context),
                        backgroundColor: Colors.white,
                        textColor: Colors.black,
                      ),
                    );
                    plain = (await engine.paginateChapter(source, 160, 1500));
                    pages = (await engine.paginateChapter(
                      source,
                      160,
                      1500,
                      paragraphReviews: ReviewColumnBadge.measureParagraphs(
                        context,
                        source,
                        {1: 23},
                      ),
                    ));
                    return SizedBox(
                      width: 160,
                      child: ReaderSelectionRegion(
                        controller: controller,
                        pages: pages,
                        source: source,
                        child: ReaderTextContent(
                          pageInfo: pages.first,
                          fontSize: 16,
                          lineHeight: 1.6,
                          paragraphSpacing: 8,
                          textColor: Colors.black,
                          reviewCounts: const {1: 23},
                          onReviewTap: (key, count) {
                            tapped = key;
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await settleNativeReaderLayout(tester);
      final lines = pages
          .expand((p) => p.paragraphs)
          .expand((p) => p.lines)
          .toList();
      expect(
        lines.first.displayText,
        plain.first.paragraphs.first.lines.first.displayText,
      );
      expect(lines.where((l) => l.trailingReview != null), hasLength(1));
      final end = lines.last;
      expect(end.selectableText, isNotEmpty);
      expect(
        end.trailingReview!.offset.dx + end.trailingReview!.size.width,
        lessThanOrEqualTo(160.001),
      );
      expect(end.trailingReview!.element.sourceAnchor, source.length);
      expect(lines.map((l) => l.selectableText).join(), source);
      for (final element in find.byType(RichText).evaluate()) {
        expect(
          (element.renderObject as RenderParagraph).didExceedMaxLines,
          isFalse,
        );
      }
      await tester.tap(find.byType(ReviewColumnBadge));
      expect(tapped, 1);
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion).first)
          .selectAll();
      await settleNativeReaderLayout(tester);
      expect(controller.selection!.text, source);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('段末正文与角标一起移页，正数槽宽固定，零评论无占位', (tester) async {
    await pumpNativeReaderLayout(
      tester,
      MaterialApp(
        home: LayoutTestBuilder(
          builder: (context) async {
            final engine = ParagraphLayoutEngine(
              transport: nativeReaderLayout,
              context: context,
              config: const ParagraphConfig(
                fontSize: 10,
                lineHeight: 1,
                justify: false,
                backgroundColor: Colors.white,
                textColor: Colors.black,
              ),
            );
            const source = '甲乙丙丁戊己庚辛壬癸。';
            final sizes = <Size>[];
            for (final count in [9, 10, 100, 1000]) {
              final review = ReviewColumnBadge.measureParagraphs(
                context,
                source,
                {1: count},
              );
              sizes.add(review[1]!.size);
              final pages = (await engine.paginateChapter(
                source,
                60,
                22,
                paragraphReviews: review,
              ));
              final lines = pages
                  .expand((p) => p.paragraphs)
                  .expand((p) => p.lines)
                  .toList();
              expect(lines.last.trailingReview, isNotNull);
              expect(lines.last.selectableText, isNotEmpty);
              expect(lines.last.selectableText.characters.first, isNot('。'));
              expect(pages.every((p) => p.totalHeight <= 22.001), isTrue);
              expect(lines.map((l) => l.selectableText).join(), source);
            }
            expect(sizes.toSet(), hasLength(1));
            final narrow = (await engine.paginateChapter(
              '甲乙',
              40,
              200,
              paragraphReviews: ReviewColumnBadge.measureParagraphs(
                context,
                '甲乙',
                {1: 1},
              ),
            ));
            final tail = narrow.last.paragraphs.last.lines.last;
            expect(tail.selectableText, isNotEmpty);
            expect(tail.trailingReview!.compact, isTrue);
            expect(tail.trailingReview!.size.width, greaterThan(0));
            expect(
              tail.trailingReview!.offset.dx + tail.trailingReview!.size.width,
              lessThanOrEqualTo(40.001),
            );
            // 紧凑图标本身宽24px，20px连图标都放不下，应明确失败而非吞字。
            await expectLater(
              engine.paginateChapter(
                '甲乙',
                20,
                200,
                paragraphReviews: ReviewColumnBadge.measureParagraphs(
                  context,
                  '甲乙',
                  {1: 1},
                ),
              ),
              throwsA(
                isA<BridgeError>().having(
                  (error) => error.message,
                  'message',
                  contains('阅读区域太窄'),
                ),
              ),
            );
            expect(
              ReviewColumnBadge.measureParagraphs(context, source, {1: 0}),
              isEmpty,
            );
            return const SizedBox();
          },
        ),
      ),
    );
  });
}
