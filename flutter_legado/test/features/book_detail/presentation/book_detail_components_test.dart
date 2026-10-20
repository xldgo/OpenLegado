import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/book_detail/presentation/components/book_action_buttons.dart';
import 'package:flutter_legado/src/features/book_detail/presentation/components/book_expandable_text.dart';
import 'package:flutter_legado/src/features/book_detail/presentation/components/book_meta_card.dart';
import 'package:flutter_legado/src/features/book_detail/presentation/dialogs/book_variable_dialog.dart';
import 'package:flutter_legado/src/models/book.dart';

void main() {
  testWidgets('详情操作按钮按事件分发并反映在架状态', (tester) async {
    final actions = <String>[];
    Widget buttons(bool inShelf) => MaterialApp(
      home: Scaffold(
        body: BookActionButtons(
          inBookshelf: inShelf,
          onToggleShelf: () => actions.add('shelf'),
          onOpenToc: () => actions.add('toc'),
          onChangeSource: () => actions.add('source'),
          onChangeGroup: () => actions.add('group'),
        ),
      ),
    );
    await tester.pumpWidget(buttons(false));
    for (final label in ['加书架', '查看目录', '书源', '设置分组']) {
      await tester.tap(find.text(label));
    }
    expect(actions, ['shelf', 'toc', 'source', 'group']);
    await tester.pumpWidget(buttons(true));
    expect(find.text('已在书架'), findsOneWidget);
    expect(find.text('加书架'), findsNothing);
  });

  testWidgets('元信息点击和长按使用不同事件', (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookMetaCard(
            book: const Book(
              name: '测试书名',
              author: '测试作者',
              bookUrl: 'local-book',
            ),
            onChangeCover: () => actions.add('cover'),
            onPreviewCover: () => actions.add('preview'),
            onNameTap: () => actions.add('name'),
            onNameLongPress: () => actions.add('name-long'),
            onAuthorTap: () => actions.add('author'),
            onAuthorLongPress: () => actions.add('author-long'),
            onChangeSource: () => actions.add('source'),
            onSourceTap: null,
          ),
        ),
      ),
    );
    await tester.tap(find.text('测试书名'));
    await tester.longPress(find.text('测试书名'));
    await tester.tap(find.text('测试作者'));
    await tester.longPress(find.text('测试作者'));
    expect(actions, ['name', 'name-long', 'author', 'author-long']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('长简介支持真实收起和展开', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: BookExpandableText(text: '小说简介与章节内容。' * 25),
          ),
        ),
      ),
    );
    expect(find.text('收起'), findsOneWidget);
    await tester.tap(find.text('收起'));
    await tester.pumpAndSettle();
    expect(find.text('展开'), findsOneWidget);
    await tester.tap(find.text('展开'));
    await tester.pumpAndSettle();
    expect(find.text('收起'), findsOneWidget);
  });

  for (final confirm in [true, false]) {
    testWidgets('变量对话框${confirm ? '提交输入值' : '取消不返回修改'}', (tester) async {
      String? result = '未关闭';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => const BookVariableDialog(
                      title: '书籍变量',
                      comment: '输入变量',
                      initialText: '原变量',
                    ),
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('原变量'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '新变量');
      await tester.tap(find.text(confirm ? '确定' : '取消'));
      await tester.pumpAndSettle();
      expect(result, confirm ? '新变量' : isNull);
      expect(find.byType(BookVariableDialog), findsNothing);
    });
  }
}
