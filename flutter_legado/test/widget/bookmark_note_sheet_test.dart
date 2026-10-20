import 'dart:async';

import 'package:flutter_legado/src/features/bookmarks/bookmarks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _inputKey = ValueKey('bookmark-note');
const _saveKey = ValueKey('bookmark-note-save');

Future<void> _open(
  WidgetTester tester, {
  String note = '',
  String original = '只读原文',
  String chapterName = '章节标题',
  required Future<void> Function(String) save,
  List<bool?>? results,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await BookmarkNoteSheet.show(
                context: context,
                bookText: original,
                chapterName: chapterName,
                initialNote: note,
                onSave: save,
              );
              results?.add(result);
            },
            child: const Text('编辑'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('编辑'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('预填多行备注，清空后可保存，原文只读', (tester) async {
    final notes = <String>[];
    final results = <bool?>[];
    await _open(
      tester,
      note: '第一行\n第二行',
      save: (note) async => notes.add(note),
      results: results,
    );
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('只读原文'), findsOneWidget);
    final original = find.byKey(const ValueKey('bookmark-original'));
    final originalField = tester.widget<TextField>(original);
    expect(originalField.readOnly, isTrue);
    expect(originalField.enableInteractiveSelection, isTrue);
    final closeCenter = tester.getCenter(find.byTooltip('关闭'));
    expect(find.text('章节标题'), findsOneWidget);
    expect(find.text('编辑备注'), findsNothing);
    expect(find.text('添加书签'), findsNothing);
    final titleCenter = tester.getCenter(find.text('章节标题'));
    final saveCenter = tester.getCenter(find.byKey(_saveKey));
    expect(closeCenter.dx, lessThan(titleCenter.dx));
    expect(titleCenter.dx, lessThan(saveCenter.dx));
    expect(closeCenter.dy, closeTo(saveCenter.dy, 1));
    expect(tester.getTopLeft(original).dy, greaterThan(saveCenter.dy));
    expect(
      tester.getTopLeft(find.byKey(_inputKey)).dy,
      greaterThan(tester.getBottomLeft(original).dy),
    );
    await tester.tap(original);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(originalField.controller!.text, '只读原文');
    expect(
      tester.widget<TextField>(find.byKey(_inputKey)).controller!.text,
      '第一行\n第二行',
    );
    await tester.enterText(find.byKey(_inputKey), '');
    await tester.tap(find.byKey(_saveKey));
    await tester.pumpAndSettle();
    expect(notes, ['']);
    expect(results, [true]);
    expect(find.byType(BookmarkNoteSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('失败保留输入与面板，修改后重试成功才关闭', (tester) async {
    var attempts = 0;
    final notes = <String>[];
    await _open(
      tester,
      save: (note) async {
        notes.add(note);
        if (++attempts == 1) throw StateError('写入失败');
      },
    );
    await tester.enterText(find.byKey(_inputKey), '需要保留的\n备注');
    await tester.tap(find.byKey(_saveKey));
    await tester.pumpAndSettle();
    expect(find.byType(BookmarkNoteSheet), findsOneWidget);
    expect(find.text('保存失败，输入已保留，请重试。'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(_inputKey)).controller!.text,
      '需要保留的\n备注',
    );
    await tester.enterText(find.byKey(_inputKey), '重新编辑');
    await tester.tap(find.byKey(_saveKey));
    await tester.pumpAndSettle();
    expect(notes, ['需要保留的\n备注', '重新编辑']);
    expect(find.byType(BookmarkNoteSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存期间重复点击、遮罩和系统返回均不关闭或二次提交', (tester) async {
    var calls = 0;
    final gate = Completer<void>();
    await _open(
      tester,
      save: (_) {
        calls++;
        return gate.future;
      },
    );
    await tester.tap(find.byKey(_saveKey));
    await tester.pump();
    expect(find.byTooltip('正在保存…'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(_saveKey)).onPressed, isNull);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == '关闭',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(_saveKey));
    await tester.tapAt(const Offset(4, 4));
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 1);
    expect(find.byType(BookmarkNoteSheet), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(BookmarkNoteSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无修改时取消不调用保存', (tester) async {
    var calls = 0;
    await _open(tester, note: '旧备注', save: (_) async => calls++);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(BookmarkNoteSheet), findsNothing);
  });

  testWidgets('修改后关闭确认，继续编辑保留输入，放弃不写入', (tester) async {
    var calls = 0;
    await _open(tester, save: (_) async => calls++);
    await tester.enterText(find.byKey(_inputKey), '未保存的修改');
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('未保存的修改'), findsWidgets);
    await tester.tap(find.widgetWithText(TextButton, '继续编辑'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(_inputKey)).controller!.text,
      '未保存的修改',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '放弃'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(BookmarkNoteSheet), findsNothing);
  });

  testWidgets('遮罩不关闭编辑器，关闭按钮仍确认未保存修改', (tester) async {
    await _open(tester, save: (_) async {});
    await tester.enterText(find.byKey(_inputKey), '未保存');
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(BookmarkNoteSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, '继续编辑'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '继续编辑'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(_inputKey)).controller!.text,
      '未保存',
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 640), const Size(640, 360)]) {
    testWidgets('长原文与键盘下布局可滚动且保存可见 $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.viewInsets = FakeViewPadding(bottom: size.height / 2);
      addTearDown(tester.view.reset);
      await _open(
        tester,
        original: '长原文。' * 300,
        chapterName: '很长的章节标题' * 20,
        save: (_) async {},
      );
      await tester.ensureVisible(find.byKey(_inputKey));
      await tester.enterText(find.byKey(_inputKey), '多行备注\n' * 12);
      await tester.ensureVisible(find.byKey(_saveKey));
      await tester.tap(find.byKey(_saveKey));
      await tester.pumpAndSettle();
      expect(find.byType(BookmarkNoteSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
