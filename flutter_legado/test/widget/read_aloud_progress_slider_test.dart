import 'dart:ui' show SemanticsAction;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_legado/src/features/read_aloud/widgets/read_aloud_progress_slider.dart';
import 'package:flutter_legado/src/features/audio/application/read_aloud_position.dart';

void main() {
  final seeks = <int>[];
  String book = 'book', text = '';
  int chapter = 0, session = 1, offset = 50;
  bool enabled = true;
  ReadAloudPosition? position;
  late StateSetter rebuild;

  ReadAloudPosition snapshot() => ReadAloudPosition(
    bookUrl: book,
    chapterIndex: chapter,
    session: session,
    paragraphIndex: 1,
    paragraphStart: 14,
    paragraphEnd: 100,
    offset: offset,
  );

  setUp(() {
    seeks.clear();
    book = 'book';
    chapter = 0;
    session = 1;
    offset = 50;
    enabled = true;
    text = '${'甲' * 10}\r\n  ${'乙' * 86}';
    position = snapshot();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ReadAloudProgressSlider(
              bookUrl: book,
              chapterIndex: chapter,
              sourceText: text,
              position: position,
              enabled: enabled,
              onSeek: seeks.add,
            );
          },
        ),
      ),
    ),
  );

  Slider slider(WidgetTester tester) =>
      tester.widget<Slider>(find.byType(Slider));

  testWidgets('进度使用包含换行缩进的完整原文长度，段内回调实时刷新', (tester) async {
    await pump(tester);
    expect(slider(tester).max, 100);
    expect(slider(tester).value, 50);
    expect(find.text('50%'), findsOneWidget);
    rebuild(() {
      offset = 80;
      position = snapshot();
    });
    await tester.pump();
    expect(slider(tester).value, 80);
    expect(find.text('80%'), findsOneWidget);
    expect(slider(tester).semanticFormatterCallback!(70), contains('70/100'));
    expect(slider(tester).semanticFormatterCallback!(70), contains('70%'));
  });

  testWidgets('拖动只预览，播放进度不覆盖预览，松手只定位一次', (tester) async {
    await pump(tester);
    slider(tester).onChangeStart!(50);
    slider(tester).onChanged!(75);
    await tester.pump();
    expect(slider(tester).value, 75);
    expect(seeks, isEmpty);
    rebuild(() {
      offset = 90;
      position = snapshot();
    });
    await tester.pump();
    expect(slider(tester).value, 75);
    final finish = slider(tester).onChangeEnd!;
    finish(75);
    finish(75);
    await tester.pump();
    expect(seeks, [75]);
  });

  for (final change in ['book', 'chapter', 'text', 'session']) {
    testWidgets('拖动中 $change 改变，不将旧松手事件应用到新正文', (tester) async {
      await pump(tester);
      final old = slider(tester);
      old.onChangeStart!(50);
      old.onChanged!(75);
      await tester.pump();
      rebuild(() {
        switch (change) {
          case 'book':
            book = 'other';
          case 'chapter':
            chapter++;
          case 'text':
            text = '新正文';
          case 'session':
            session++;
        }
        offset = 1;
        position = snapshot();
      });
      await tester.pump();
      old.onChangeEnd!(75);
      await tester.pump();
      expect(seeks, isEmpty);
      expect(slider(tester).value, 1);
    });
  }

  testWidgets('禁用再启用不会恢复已取消的拖动，迟到的结束事件无效', (tester) async {
    await pump(tester);
    final old = slider(tester);
    old.onChangeStart!(50);
    old.onChanged!(75);
    rebuild(() => enabled = false);
    await tester.pump();
    expect(slider(tester).onChanged, isNull);
    rebuild(() => enabled = true);
    await tester.pump();
    old.onChangeEnd!(75);
    await tester.pump();
    expect(seeks, isEmpty);
    expect(slider(tester).value, 50);
  });

  testWidgets('读屏增加动作执行一次定位，销毁后旧松手事件无效', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pump(tester);
      tester.semantics.performAction(
        find.semantics.byAction(SemanticsAction.increase),
        SemanticsAction.increase,
      );
      await tester.pump();
      expect(seeks, hasLength(1));
      expect(seeks.single, greaterThan(50));
      seeks.clear();
      final old = slider(tester);
      old.onChangeStart!(50);
      old.onChanged!(75);
      await tester.pumpWidget(const SizedBox());
      old.onChangeEnd!(75);
      expect(seeks, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('空内容或过期位置禁用，超出范围的有效回调限制到原文范围', (tester) async {
    await pump(tester);
    rebuild(() => offset = 150);
    rebuild(() => position = snapshot());
    await tester.pump();
    expect(slider(tester).value, 100);
    rebuild(() => book = 'other');
    await tester.pump();
    expect(slider(tester).onChanged, isNull);
    expect(find.text('—'), findsOneWidget);
    rebuild(() {
      text = '';
      position = snapshot();
    });
    await tester.pump();
    expect(slider(tester).value, 0);
    expect(slider(tester).max, 1);
    expect(slider(tester).onChanged, isNull);
    expect(tester.takeException(), isNull);
  });
}
