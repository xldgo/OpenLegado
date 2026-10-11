import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/reader/reader_notifier.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_legado/src/widgets/reader/text_selection_panel.dart';

class _Reader extends ReaderNotifier {
  @override
  ReaderState build() => const ReaderState(
    currentBook: Book(bookUrl: 'test://book', name: '测试小说', author: '测试作者'),
    chapters: [BookChapter(url: 'test://chapter', title: '测试章节', index: 0)],
    chapterContent: '前缀实际选区后缀',
  );
}

class _Api extends MockBookApi {
  Bookmark? bookmark;
  Map<String, dynamic>? highlight;

  @override
  Future<Bookmark> addBookmark(Bookmark value) async {
    bookmark = value;
    return value;
  }

  @override
  Future<int> highlightAdd({required String highlightJson}) async {
    highlight = jsonDecode(highlightJson) as Map<String, dynamic>;
    return 1;
  }
}

Future<SelectableText> _showPanel(WidgetTester tester, _Api api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        readerNotifierProvider.overrideWith(_Reader.new),
        bookApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => TextSelectionPanel.show(
                context,
                text: '前缀实际选区后缀',
                chapterPos: 100,
              ),
              child: const Text('打开选区'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开选区'));
  await tester.pumpAndSettle();
  final text = tester.widget<SelectableText>(find.byType(SelectableText));
  text.onSelectionChanged!(
    const TextSelection(baseOffset: 2, extentOffset: 6),
    SelectionChangedCause.toolbar,
  );
  await tester.pumpAndSettle();
  return text;
}

void main() {
  testWidgets('书签保存细调选区的原文和全局起始偏移', (tester) async {
    final api = _Api();
    await _showPanel(tester, api);
    await tester.tap(find.text('书签'));
    await tester.pumpAndSettle();
    expect(api.bookmark!.chapterPos, 102);
    expect(api.bookmark!.bookText, '实际选区');
    expect(tester.takeException(), isNull);
  });

  testWidgets('高亮使用打开笔记时的选区，焦点变化不会改成整段', (tester) async {
    final api = _Api();
    final text = await _showPanel(tester, api);
    await tester.tap(find.text('高亮'));
    await tester.pumpAndSettle();
    final color = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == kHighlightColors.first,
    );
    await tester.tap(color.first);
    await tester.pumpAndSettle();
    text.onSelectionChanged!(
      const TextSelection.collapsed(offset: 0),
      SelectionChangedCause.tap,
    );
    await tester.enterText(find.byType(TextField), '选区笔记');
    await tester.tap(find.text('保存高亮'));
    await tester.pumpAndSettle();
    expect(api.highlight!['chapterPos'], 102);
    expect(api.highlight!['chapterPosEnd'], 106);
    expect(api.highlight!['bookText'], '实际选区');
    expect(api.highlight!['note'], '选区笔记');
    expect(tester.takeException(), isNull);
  });
}
