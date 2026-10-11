import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/reader/reader_notifier.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_view.dart';

class _Reader extends ReaderNotifier {
  @override
  ReaderState build() => ReaderState(
    chapters: const [BookChapter(title: '测试章节', index: 0)],
    chapterContent: List.filled(30, '这是用于检验字号缩放与屏幕尺寸变化的小说正文。').join('\n'),
    pageTurnMode: PageTurnMode.none,
  );
}

void main() {
  testWidgets('系统字体缩放和屏幕宽度变化会使真实阅读器重新分页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final key = GlobalKey<ReaderPageViewState>();
    Future<void> pump(double width, double scale) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerNotifierProvider.overrideWith(_Reader.new),
            bookApiProvider.overrideWithValue(MockBookApi()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  height: 500,
                  child: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 500),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: ReaderPageView(
                      key: key,
                      paragraphSpacing: 8,
                      selectText: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1));
    }

    await pump(500, 1);
    final wide = key.currentState!.pageCount;
    await pump(320, 1);
    final narrow = key.currentState!.pageCount;
    expect(narrow, greaterThan(wide));
    await pump(320, 2);
    expect(key.currentState!.pageCount, greaterThan(narrow));
    expect(tester.takeException(), isNull);
  });
}
