import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/features/reader/application/reader_state.dart';
import 'package:flutter_legado/src/widgets/reader/turn/page_direction.dart';
import 'package:flutter_legado/src/widgets/reader/turn/page_turn_controller.dart';
import 'package:flutter_legado/src/widgets/reader/turn/reader_turn_view.dart';
import 'package:flutter_legado/src/widgets/reader/turn/painters/cover_page_painter.dart';
import 'package:flutter_legado/src/widgets/reader/turn/painters/slide_page_painter.dart';
import 'package:flutter_legado/src/widgets/reader/turn/painters/simulation_curl_painter.dart';

Future<void> _releaseTurn(
  PageTurnController controller,
  List<PageTurnDirection> completed,
) {
  controller.onPointerMove(
    const Offset(240, 220),
    hasPrev: true,
    hasNext: true,
    slop: 18,
  );
  controller.onPointerMove(
    const Offset(160, 220),
    hasPrev: true,
    hasNext: true,
    slop: 18,
  );
  return controller.onPointerUp(
    vsync: const TestVSync(),
    viewWidth: 320,
    viewHeight: 500,
    onCompleted: completed.add,
    settleStyle: PageTurnSettleStyle.horizontal,
  );
}

class _TurnHost extends StatefulWidget {
  const _TurnHost({
    super.key,
    required this.mode,
    this.initialPage = 3,
    this.pageCount = 12,
    this.hasChapterNext = false,
  });
  final PageTurnMode mode;
  final int initialPage;
  final int pageCount;
  final bool hasChapterNext;

  @override
  State<_TurnHost> createState() => _TurnHostState();
}

class _TurnHostState extends State<_TurnHost> {
  final turnKey = GlobalKey<ReaderTurnViewState>();
  final committed = <int>[];
  late int page = widget.initialPage;
  int nextChapterCalls = 0;
  int layoutGeneration = 0;
  int? extendedPageCount;
  void growPages() => setState(() => extendedPageCount = widget.pageCount + 8);

  void loadNextChapter() => setState(() {
    page = 0;
    layoutGeneration++;
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 320,
          height: 500,
          child: ReaderTurnView(
            key: turnKey,
            mode: widget.mode,
            pageIndex: page,
            pageCount: extendedPageCount ?? widget.pageCount,
            layoutGeneration: layoutGeneration,
            hasChapterPrev: false,
            hasChapterNext: widget.hasChapterNext,
            onTurnChapterPrev: () {},
            onTurnChapterNext: () => nextChapterCalls++,
            chapterNextPage: widget.hasChapterNext
                ? const ColoredBox(color: Colors.white, child: Text('下一章预览'))
                : null,
            onPageChanged: (index) => setState(() {
              page = index;
              committed.add(index);
            }),
            buildPage: (index) => ColoredBox(
              color: index.isEven ? Colors.white : Colors.grey.shade200,
              child: Center(child: Text('测试正文第 $index 页')),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _warmSnapshots(WidgetTester tester) async {
  // 使用真正的 RepaintBoundary 快照，确保复现动画模式而非缺图时的瞬时翻页。
  await tester.pump();
  tester.binding.scheduleFrame();
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
}

Future<void> _swipeNext(WidgetTester tester, {bool pump = true}) async {
  final gesture = await tester.startGesture(const Offset(280, 220));
  await gesture.moveTo(const Offset(240, 220));
  await gesture.moveTo(const Offset(160, 220));
  await gesture.up();
  if (pump) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('分批追加页面不打断正在进行的拖动', (tester) async {
    final key = GlobalKey<_TurnHostState>();
    await tester.pumpWidget(_TurnHost(key: key, mode: PageTurnMode.cover));
    await _warmSnapshots(tester);
    final gesture = await tester.startGesture(const Offset(280, 220));
    await gesture.moveTo(const Offset(240, 220));
    await gesture.moveTo(const Offset(180, 220));
    await tester.pump();
    key.currentState!.growPages();
    await tester.pump();
    await gesture.moveTo(const Offset(80, 220));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(key.currentState!.page, 4);
    expect(key.currentState!.committed, [4]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('下一次按下完成上一轮有效翻页，并结束旧异步等待', (tester) async {
    final controller = PageTurnController();
    addTearDown(controller.dispose);
    final completed = <PageTurnDirection>[];
    var ended = false;
    controller.onPointerDown(const Offset(280, 220));
    _releaseTurn(controller, completed).then((_) => ended = true);
    await tester.pump(const Duration(milliseconds: 20));
    expect(controller.isSettling, isTrue);
    controller.onPointerDown(const Offset(280, 220));
    await tester.pump();
    expect(completed, [PageTurnDirection.next]);
    expect(ended, isTrue);
    expect(controller.direction, PageTurnDirection.none);
    expect(controller.isSettling, isFalse);
  });

  testWidgets('取消中的回弹被下一次手势打断，不提交页码但结束等待', (tester) async {
    final controller = PageTurnController();
    addTearDown(controller.dispose);
    final completed = <PageTurnDirection>[];
    controller.onPointerDown(const Offset(280, 220));
    controller.onPointerMove(
      const Offset(200, 220),
      hasPrev: true,
      hasNext: true,
      slop: 18,
    );
    controller.onPointerMove(
      const Offset(230, 220),
      hasPrev: true,
      hasNext: true,
      slop: 18,
    );
    expect(controller.isCancel, isTrue);
    var ended = false;
    controller
        .onPointerUp(
          vsync: const TestVSync(),
          viewWidth: 320,
          viewHeight: 500,
          onCompleted: completed.add,
          settleStyle: PageTurnSettleStyle.horizontal,
        )
        .then((_) => ended = true);
    controller.onPointerDown(const Offset(280, 220));
    await tester.pump();
    expect(completed, isEmpty);
    expect(ended, isTrue);
  });

  testWidgets('重排或选区取消翻页时结束等待，禁止旧页码回写', (tester) async {
    final controller = PageTurnController();
    addTearDown(controller.dispose);
    final completed = <PageTurnDirection>[];
    var ended = false;
    controller.onPointerDown(const Offset(280, 220));
    _releaseTurn(controller, completed).then((_) => ended = true);
    controller.resetGesture();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(ended, isTrue);
    expect(completed, isEmpty);
    expect(controller.isSettling, isFalse);
  });

  testWidgets('连续程序翻页打断旧动画时，每次有效操作只提交一页', (tester) async {
    final controller = PageTurnController();
    addTearDown(controller.dispose);
    final completed = <PageTurnDirection>[];
    final ended = <bool>[];
    for (var i = 0; i < 4; i++) {
      ended.add(false);
      controller
          .turnByAnim(
            PageTurnDirection.next,
            vsync: const TestVSync(),
            viewWidth: 320,
            viewHeight: 500,
            hasPrev: true,
            hasNext: true,
            onCompleted: completed.add,
            settleStyle: PageTurnSettleStyle.horizontal,
          )
          .then((_) => ended[i] = true);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(completed, List.filled(4, PageTurnDirection.next));
    expect(ended, everyElement(isTrue));
  });

  for (final mode in [
    PageTurnMode.cover,
    PageTurnMode.slide,
    PageTurnMode.simulate,
  ]) {
    testWidgets('$mode 连滑后慢划，快照就绪时同一手势恢复跟手动画', (tester) async {
      final key = GlobalKey<_TurnHostState>();
      await tester.pumpWidget(_TurnHost(key: key, mode: mode));
      await _warmSnapshots(tester);
      for (var i = 0; i < 3; i++) {
        await _swipeNext(tester, pump: false);
      }
      final gesture = await tester.startGesture(const Offset(280, 220));
      await gesture.moveTo(const Offset(240, 220));
      await _warmSnapshots(tester);
      final canvas = find.descendant(
        of: find.byType(ReaderTurnView),
        matching: find.byType(CustomPaint),
      );
      expect(canvas, findsOneWidget, reason: '快照在拖动途中准备好后应立即显示动画，不能等松手直接换页');
      final painter = tester.widget<CustomPaint>(canvas).painter;
      final image = switch (painter) {
        CoverPagePainter(:final cur) => cur,
        SlidePagePainter(:final cur) => cur,
        SimulationCurlPainter(:final cur) => cur,
        _ => null,
      };
      expect(image, isNotNull);
      final bytes = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      expect(bytes!.buffer.asUint8List().take(4).toList(), [
        255,
        255,
        255,
        255,
      ], reason: '动画应使用已提交的第 6 页白色快照');
      await gesture.moveTo(const Offset(160, 220));
      await tester.pump(const Duration(milliseconds: 40));
      expect(canvas, findsOneWidget);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(canvas, findsOneWidget, reason: '松手后仍应完成收尾动画');
      await tester.pumpAndSettle();
      expect(key.currentState!.committed, [4, 5, 6, 7]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('$mode 快速连续四次滑动仍前进四页，未完成动画不循环', (tester) async {
      final key = GlobalKey<_TurnHostState>();
      await tester.pumpWidget(_TurnHost(key: key, mode: mode));
      await _warmSnapshots(tester);
      await _swipeNext(tester);
      expect(
        find.descendant(
          of: find.byType(ReaderTurnView),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
        reason: '首轮必须实际进入翻页动画，否则无法复现中断时丢页码的问题',
      );
      for (var i = 0; i < 3; i++) {
        await _swipeNext(tester);
      }
      await tester.pumpAndSettle();
      await _warmSnapshots(tester);
      expect(key.currentState!.committed, [4, 5, 6, 7]);
      expect(key.currentState!.page, 7);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('$mode 同一帧内连滑不重复提交同一页', (tester) async {
      final key = GlobalKey<_TurnHostState>();
      await tester.pumpWidget(_TurnHost(key: key, mode: mode));
      await _warmSnapshots(tester);
      for (var i = 0; i < 4; i++) {
        await _swipeNext(tester, pump: false);
      }
      await tester.pumpAndSettle();
      expect(key.currentState!.committed, [4, 5, 6, 7]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('$mode 第二次拖动不绘制上一页的旧快照', (tester) async {
      final key = GlobalKey<_TurnHostState>();
      await tester.pumpWidget(_TurnHost(key: key, mode: mode));
      await _warmSnapshots(tester);
      await _swipeNext(tester);
      final gesture = await tester.startGesture(const Offset(280, 220));
      await tester.pump();
      expect(key.currentState!.page, 4);
      await gesture.moveTo(const Offset(240, 220));
      await gesture.moveTo(const Offset(160, 220));
      await tester.pump();
      final canvas = find.descendant(
        of: find.byType(ReaderTurnView),
        matching: find.byType(CustomPaint),
      );
      if (canvas.evaluate().isNotEmpty) {
        final painter = tester.widget<CustomPaint>(canvas).painter;
        final image = switch (painter) {
          CoverPagePainter(:final cur) => cur,
          SlidePagePainter(:final cur) => cur,
          SimulationCurlPainter(:final cur) => cur,
          _ => null,
        };
        expect(image, isNotNull);
        final bytes = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        expect(bytes!.buffer.asUint8List().take(4).toList(), [
          255,
          255,
          255,
          255,
        ], reason: '已提交到第 4 页，动画的当前页应为白色，不能仍显示第 3 页灰色快照');
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('章末快速连滑只请求下一章一次，正文落地后继续翻页', (tester) async {
    final key = GlobalKey<_TurnHostState>();
    await tester.pumpWidget(
      _TurnHost(
        key: key,
        mode: PageTurnMode.cover,
        initialPage: 1,
        pageCount: 2,
        hasChapterNext: true,
      ),
    );
    await _warmSnapshots(tester);
    await _swipeNext(tester);
    for (var i = 0; i < 3; i++) {
      await _swipeNext(tester);
    }
    await tester.pumpAndSettle();
    expect(key.currentState!.nextChapterCalls, 1);
    expect(key.currentState!.committed, isEmpty);
    key.currentState!.loadNextChapter();
    await _warmSnapshots(tester);
    await _swipeNext(tester);
    await tester.pumpAndSettle();
    expect(key.currentState!.committed, [1]);
    expect(key.currentState!.nextChapterCalls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('同帧连续反向滑动从已提交的新页返回，不跳过原页', (tester) async {
    final key = GlobalKey<_TurnHostState>();
    await tester.pumpWidget(_TurnHost(key: key, mode: PageTurnMode.cover));
    await _warmSnapshots(tester);
    await _swipeNext(tester, pump: false);
    final gesture = await tester.startGesture(const Offset(40, 220));
    await gesture.moveTo(const Offset(80, 220));
    await gesture.moveTo(const Offset(160, 220));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(key.currentState!.committed, [4, 3]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
