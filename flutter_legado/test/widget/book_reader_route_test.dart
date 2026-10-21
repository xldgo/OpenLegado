import 'package:go_router/go_router.dart';

import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_legado/src/app/routing/app_router.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/features/privacy/privacy_controller.dart';
import 'package:flutter_legado/src/features/privacy/privacy_gate.dart';
import 'package:flutter_legado/src/features/privacy/privacy_settings.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/book_open_motion_provider.dart';
import 'package:flutter_legado/src/widgets/book_cover.dart';
import 'package:flutter_legado/src/widgets/reader/book_reader_route.dart';

const _book = Book(bookUrl: 'book://transition', name: '封面展开');

class _DefaultPageTransitions extends PageTransitionsBuilder {
  const _DefaultPageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => SlideTransition(
    key: ValueKey('default-transition:${route.settings.name}'),
    position: Tween(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(animation),
    child: child,
  );
}

class _Reader extends ReaderNotifier {
  @override
  ReaderState build() => const ReaderState(
    currentBook: _book,
    isLoading: true,
    backgroundColor: Color(0xFFE9DFC9),
  );

  void loaded() => state = state.copyWith(isLoading: false);
  void showBook(Book? book) => state = state.copyWith(currentBook: book);
  void setBackground(Color color) =>
      state = state.copyWith(backgroundColor: color);
}

class _Privacy extends PrivacyController {
  @override
  PrivacyState build() => const PrivacyState(loading: false);

  void relock() => state = PrivacyState(
    loading: false,
    settings: const PrivacySettings(enabled: true),
    books: [_book.copyWith(isPrivate: true)],
  );
}

class _ProbeState {
  int initialized = 0;
  int disposed = 0;
  final sizes = <Size>[];
}

class _ReaderProbe extends ConsumerStatefulWidget {
  const _ReaderProbe(this.probe);
  final _ProbeState probe;

  @override
  ConsumerState<_ReaderProbe> createState() => _ReaderProbeState();
}

class _ReaderProbeState extends ConsumerState<_ReaderProbe> {
  @override
  void initState() {
    super.initState();
    widget.probe.initialized++;
  }

  @override
  void dispose() {
    widget.probe.disposed++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      widget.probe.sizes.add(constraints.biggest);
      return Scaffold(
        body: Text(
          ref.watch(readerNotifierProvider).isLoading ? '加载章节...' : '正文',
        ),
      );
    },
  );
}

class _Harness {
  final key = GlobalKey<NavigatorState>();
  final offset = ValueNotifier(const Offset(32, 80));
  final visible = ValueNotifier(true);
  final coverSize = ValueNotifier(const Size(80, 112));
  final probe = _ProbeState();
  final reader = _Reader();
  final privacy = _Privacy();
  late final container = ProviderContainer(
    overrides: [
      readerNotifierProvider.overrideWith(() => reader),
      privacyControllerProvider.overrideWith(() => privacy),
    ],
  );
  late final router = AppRouter(
    routes: {
      AppRoutes.home: (context) => Scaffold(
        body: ListenableBuilder(
          listenable: Listenable.merge([offset, visible, coverSize]),
          builder: (context, _) => Stack(
            children: [
              if (visible.value)
                Positioned(
                  left: offset.value.dx,
                  top: offset.value.dy,
                  child: BookCoverHero(
                    tag: 'book-cover:${_book.bookUrl}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: RawImage(
                        image: decodedCover ? image : null,
                        width: coverSize.value.width,
                        height: coverSize.value.height,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: TextButton(
                  onPressed: () => navigation.push(
                    AppRoutes.reader,
                    extra: anchored
                        ? BookCoverHero.originFor(context, _book.bookUrl)
                        : null,
                  ),
                  child: const Text('开书'),
                ),
              ),
            ],
          ),
        ),
      ),
      AppRoutes.reader: (context) => Consumer(
        builder: (context, ref, _) => PrivacyBookGate(
          book: ref.watch(readerNotifierProvider).currentBook,
          builder: (_) => _ReaderProbe(probe),
        ),
      ),
      '/detail': (_) => Scaffold(
        body: Center(
          child: BookCoverHero(
            tag: 'book-cover:${_book.bookUrl}',
            child: RawImage(
              image: image,
              width: 160,
              height: 224,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    },
  );

  late final GoRouter navigation = router.createRouter(navigatorKey: key);

  _Harness(this.image, {this.anchored = true, this.decodedCover = true});
  final ui.Image image;
  final bool anchored;
  final bool decodedCover;

  Future<void> pump(WidgetTester tester, {bool reduced = false}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: navigation,
          theme: ThemeData(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _DefaultPageTransitions(),
                TargetPlatform.iOS: _DefaultPageTransitions(),
                TargetPlatform.windows: _DefaultPageTransitions(),
              },
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      navigation.dispose();
      container.dispose();
      offset.dispose();
      visible.dispose();
      coverSize.dispose();
    });
  }

  Future<BookReaderRoute<dynamic>> open(WidgetTester tester) async {
    await tester.tap(find.text('开书'));
    await tester.pump();
    await tester.pump();
    final route = ModalRoute.of(
      tester.element(find.byType(_ReaderProbe, skipOffstage: false)),
    );
    return route! as BookReaderRoute<dynamic>;
  }
}

Rect _reveal(WidgetTester tester) {
  final clip = tester.widget<ClipRRect>(
    find.byKey(const ValueKey('book-reader-reveal')),
  );
  final box = tester.renderObject<RenderBox>(
    find.byKey(const ValueKey('book-reader-reveal')),
  );
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    clip.clipper!.getClip(box.size).outerRect,
  );
}

void main() {
  late ui.Image image;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 40, 56),
      Paint()..color = Colors.orange,
    );
    final picture = recorder.endRecording();
    image = await picture.toImage(40, 56);
    picture.dispose();
  });
  tearDownAll(() => image.dispose());

  testWidgets('相同书籍出现多次时只从点击卡片读取封面，不依赖标准Hero标签', (tester) async {
    late BuildContext selectedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              BookCoverHero(
                tag: 'duplicate:first',
                child: RawImage(image: image, width: 80, height: 112),
              ),
              Builder(
                builder: (context) {
                  selectedContext = context;
                  return BookCoverHero(
                    tag: 'duplicate:second',
                    child: RawImage(image: image, width: 120, height: 168),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    final origin = BookCoverOrigin.fromContext(selectedContext, _book.bookUrl);
    expect(origin, isNotNull);
    expect(origin!.bounds(), tester.getRect(find.byType(BookCoverHero).last));
    expect(origin.bounds()!.top, 112);
    expect(origin.image()!.isCloneOf(image), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(origin.bounds(), isNull);
    expect(origin.image(), isNull);
  });

  testWidgets('默认封面不作为真实图片翻开，隐藏卡片不作为来源', (tester) async {
    late BuildContext visibleContext;
    late BuildContext hiddenContext;
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SizedBox())),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Builder(
                  builder: (context) {
                    visibleContext = context;
                    return const BookCover();
                  },
                ),
                Offstage(
                  child: Builder(
                    builder: (context) {
                      hiddenContext = context;
                      return BookCoverHero(
                        tag: 'hidden',
                        child: RawImage(image: image, width: 80, height: 112),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final origin = BookCoverOrigin.fromContext(visibleContext, _book.bookUrl);
    expect(origin?.bounds(), isNotNull);
    expect(origin?.image(), isNull);
    expect(BookCoverOrigin.fromContext(hiddenContext, _book.bookUrl), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('原有书架详情 Hero 过渡保留来源图片元素', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    final source = tester.element(find.byType(RawImage));
    h.navigation.push('/detail');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(source.mounted, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    h.key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(RawImage)), same(source));
  });

  testWidgets('展开路由继续遵守页面退出门禁', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    final origin = BookCoverHero.originFor(
      tester.element(find.byType(BookCoverHero)),
      _book.bookUrl,
    );
    var intercepted = 0;
    final route = BookReaderRoute<void>(
      settings: RouteSettings(name: AppRoutes.reader, arguments: origin),
      builder: (_) => PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) intercepted++;
        },
        child: const Scaffold(body: Text('退出前保存')),
      ),
    );
    h.key.currentState!.push(route);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await h.key.currentState!.maybePop();
    await tester.pump();
    expect(intercepted, 1);
    expect(route.isCurrent, isTrue);
    await tester.pumpAndSettle();
    h.key.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('轻拟物转场上拱放大、同步翻盖，深色正文后半程显现', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    h.container.read(readerNotifierProvider);
    h.reader.setBackground(const Color(0xFF121212));
    final route = await h.open(tester);
    expect(route.transitionDuration, const Duration(milliseconds: 420));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 350));
    ColoredBox veil() => tester.widget<ColoredBox>(
      find.byKey(const ValueKey('book-reader-content-veil')),
    );
    expect(veil().color, const Color(0xFF121212));
    await tester.pump(const Duration(milliseconds: 180));
    final rect = _reveal(tester);
    final travel = (rect.width - 80) / (400 - 80);
    final expectedY =
        136 * (1 - travel) * (1 - travel) +
        2 * 80 * (1 - travel) * travel +
        400 * travel * travel;
    expect(rect.center.dy, closeTo(expectedY, 0.001));
    expect(rect.center.dy, lessThan(136 + (400 - 136) * travel));
    expect(
      rect.center.dx,
      closeTo(
        72 * (1 - travel) * (1 - travel) +
            400 * (1 - travel) * travel +
            200 * travel * travel,
        0.001,
      ),
    );
    expect(veil().color.a, inExclusiveRange(0, 1));
    expect(veil().color.withValues(alpha: 1), const Color(0xFF121212));
    expect(h.probe.sizes, everyElement(const Size(400, 800)));
    final body = tester.element(find.byType(_ReaderProbe));
    final alpha = veil().color.a;
    h.key.currentState!.pop();
    await tester.pump();
    expect(_reveal(tester), rect, reason: '中途返回保留几何');
    expect(veil().color.a, alpha, reason: '中途返回保留显现进度');
    await tester.pumpAndSettle();
    expect(body.mounted, isFalse);
    expect(h.probe.initialized, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A轨迹顶边单调上移，下次开书才使用新选择', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    h.container
        .read(bookOpenMotionProvider.notifier)
        .select(BookOpenMotion.top);
    await h.open(tester);
    await tester.pump(const Duration(milliseconds: 100));
    var previous = _reveal(tester);
    h.container
        .read(bookOpenMotionProvider.notifier)
        .select(BookOpenMotion.arc);
    for (var frame = 0; frame < 16; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
      final current = _reveal(tester);
      final travel = (current.width - 80) / 320;
      expect(current.top, closeTo(80 * (1 - travel), 0.001));
      expect(current.top, lessThanOrEqualTo(previous.top + 0.001));
      previous = current;
    }
    await tester.pumpAndSettle();
    h.key.currentState!.pop();
    await tester.pumpAndSettle();
    await h.open(tester);
    await tester.pump(const Duration(milliseconds: 180));
    final curve = _reveal(tester);
    final travel = (curve.width - 80) / 320;
    expect(curve.top, isNot(closeTo(80 * (1 - travel), 0.1)));
    await tester.pumpAndSettle();
  });

  testWidgets('中心上拱轨迹连续放大，最终精确落到全屏', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    await h.open(tester);
    var previous = _reveal(tester);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 21));
      final current = _reveal(tester);
      expect(current.isFinite, isTrue);
      expect(current.width, greaterThanOrEqualTo(previous.width - 0.001));
      previous = current;
    }
    expect(previous, const Rect.fromLTWH(0, 0, 400, 800));
    expect(h.probe.initialized, 1);
    expect(h.probe.sizes, everyElement(const Size(400, 800)));
  });

  testWidgets('阅读背景变化只更新配色和光影，深浅及护眼色共用几何轨迹', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    await h.open(tester);
    await tester.pump(const Duration(milliseconds: 280));
    final bounds = _reveal(tester);
    final hinge = tester
        .widget<Transform>(
          find.byKey(const ValueKey('book-reader-cover-hinge')),
        )
        .transform
        .clone();
    for (final background in [
      const Color(0xFF121212),
      Colors.white,
      const Color(0xFFDCE8CF),
    ]) {
      h.reader.setBackground(background);
      await tester.pump();
      final veil = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('book-reader-content-veil')),
      );
      expect(veil.color.withValues(alpha: 1), background);
      final back =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('book-reader-cover-back')),
                  )
                  .decoration
              as BoxDecoration;
      final lining = (back.gradient! as LinearGradient).colors.last;
      expect((lining.r - background.r).abs(), lessThan(0.06));
      expect((lining.g - background.g).abs(), lessThan(0.06));
      expect((lining.b - background.b).abs(), lessThan(0.06));
      expect(_reveal(tester), bounds);
      expect(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey('book-reader-cover-hinge')),
            )
            .transform,
        hinge,
      );
    }
    await tester.pumpAndSettle();
    expect(h.probe.initialized, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('封面以左侧书脊翻开，正文始终全屏布局且完成时不重新初始化', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    final route = await h.open(tester);
    expect(_reveal(tester), const Rect.fromLTWH(32, 80, 80, 112));
    expect(route.opaque, isTrue);
    await tester.pump(const Duration(milliseconds: 180));
    final midway = _reveal(tester);
    expect(midway.width, greaterThan(80));
    expect(midway.width, lessThan(400));
    expect(find.byType(RawImage), findsNWidgets(2));
    final hinge = tester.widget<Transform>(
      find.byKey(const ValueKey('book-reader-cover-hinge')),
    );
    expect(hinge.alignment, Alignment.centerLeft);
    expect(hinge.transform.entry(0, 0), inExclusiveRange(0, 1));
    expect(hinge.transform.entry(2, 0), greaterThan(0));
    expect(hinge.transform.entry(3, 2), lessThan(0));
    expect(h.probe.sizes, everyElement(const Size(400, 800)));
    await tester.pumpAndSettle();
    expect(_reveal(tester), const Rect.fromLTWH(0, 0, 400, 800));
    expect(find.text('加载章节...'), findsOneWidget);
    expect(h.probe.initialized, 1);
    h.reader.loaded();
    await tester.pump();
    expect(find.text('正文'), findsOneWidget);
    expect(h.probe.initialized, 1);
    expect(h.probe.disposed, 0);
    h.key.currentState!.pop('读完');
    await tester.pumpAndSettle();
    expect(await route.popped, '读完');
    expect(h.probe.disposed, 1);
    expect(find.text('开书'), findsOneWidget);
    expect(image.width, 40, reason: '路由只释放自己的图片引用');
  });

  testWidgets('翻盖与放大覆盖完整进场，返回时同步合上缩回', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    await h.open(tester);
    final hingeFinder = find.byKey(const ValueKey('book-reader-cover-hinge'));

    await tester.pump(const Duration(milliseconds: 48));
    expect(_reveal(tester).width, inExclusiveRange(80, 400));
    var hinge = tester.widget<Transform>(hingeFinder);
    expect(hinge.transform.entry(2, 0), greaterThan(0), reason: '开始放大时封面已在翻开');

    await tester.pump(const Duration(milliseconds: 288));
    expect(_reveal(tester).width, lessThan(400), reason: '翻开后段仍在放大，不能提前展开为全屏');
    hinge = tester.widget<Transform>(hingeFinder);
    expect(hinge.transform.entry(0, 0), lessThan(0));
    expect(h.probe.sizes, everyElement(const Size(400, 800)));
    await tester.pumpAndSettle();

    h.key.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      _reveal(tester).width,
      inExclusiveRange(80, 400),
      reason: '合盖开始时同时缩回',
    );
    hinge = tester.widget<Transform>(hingeFinder);
    expect(hinge.transform.entry(0, 0), lessThan(0));
    await tester.pumpAndSettle();
    expect(h.probe.initialized, 1);
    expect(h.probe.disposed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('正文实际等比缩放，封面不随纸面比例重新裁切', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    await h.open(tester);
    final body = tester.renderObject<RenderBox>(find.byType(_ReaderProbe));
    final bodySize = body.size;
    double scale() => body.getTransformTo(null).entry(0, 0);
    final firstScale = scale();
    expect(firstScale, closeTo(0.2, 0.001), reason: '正文须缩小到封面宽度，而非保持原尺寸只裁剪');
    final hingeFinder = find.byKey(const ValueKey('book-reader-cover-hinge'));
    Size coverSize() => tester.getSize(hingeFinder);
    final initialCover = coverSize();
    expect(initialCover.aspectRatio, closeTo(80 / 112, 0.001));

    await tester.pump(const Duration(milliseconds: 180));
    expect(scale(), inExclusiveRange(firstScale, 1));
    final transform = body.getTransformTo(null);
    expect(transform.entry(1, 1), closeTo(scale(), 0.001), reason: '文字不能非等比拉伸');
    expect(body.size, bodySize, reason: '绘制缩放不改变正文排版约束');
    expect(coverSize(), initialCover, reason: '封面只做绘制变换，不随窗口改变裁切比例');
    final forwardScale = scale();
    h.key.currentState!.pop();
    await tester.pump();
    expect(scale(), closeTo(forwardScale, 0.001), reason: '中途返回不跳变');
    await tester.pump(const Duration(milliseconds: 40));
    expect(scale(), lessThan(forwardScale));
    await tester.pumpAndSettle();
    expect(h.probe.initialized, 1);
    expect(h.probe.disposed, 1);
    expect(tester.takeException(), isNull);
  });

  for (final previous in [
    null,
    const Book(bookUrl: 'book://previous', name: '旧书'),
  ]) {
    testWidgets('目标会话未就绪时保留封面轨迹且隐藏${previous == null ? '空' : '旧书'}正文', (
      tester,
    ) async {
      final h = _Harness(image);
      await h.pump(tester);
      h.container.read(readerNotifierProvider);
      h.reader.showBook(previous);
      await tester.pump();
      await h.open(tester);
      await tester.pump(const Duration(milliseconds: 80));
      final before = _reveal(tester);
      final hingeFinder = find.byKey(const ValueKey('book-reader-cover-hinge'));
      final angle = tester.widget<Transform>(hingeFinder).transform.clone();
      Opacity bodyVisibility() => tester.widget<Opacity>(
        find
            .descendant(
              of: find.byKey(const ValueKey('book-reader-reveal')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(before.width, inExclusiveRange(80, 400));
      expect(bodyVisibility().opacity, 0);
      h.reader.showBook(_book);
      await tester.pump();
      expect(_reveal(tester), before, reason: '正文就绪不改变转场轨迹');
      expect(tester.widget<Transform>(hingeFinder).transform, angle);
      expect(bodyVisibility().opacity, 1);
      await tester.pumpAndSettle();
      h.reader.showBook(const Book(bookUrl: 'book://next', name: '后续会话'));
      await tester.pump();
      expect(bodyVisibility().opacity, 1, reason: '转场结束后不遮挡后续会话或页面错误提示');
      expect(h.probe.initialized, 1);
      expect(h.probe.disposed, 0);
    });
  }

  testWidgets('目标会话未就绪仍按目标书阻止私密封面飞行', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    h.container.read(readerNotifierProvider);
    h.reader.showBook(null);
    h.privacy.relock();
    await tester.pump();
    await h.open(tester);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('book-reader-cover-hinge')), findsNothing);
    expect(_reveal(tester), const Rect.fromLTWH(0, 0, 400, 800));
    await tester.pumpAndSettle();
  });

  for (final elapsed in [180, 320]) {
    testWidgets('进场${elapsed}ms返回到已移动且改变尺寸的来源，首帧保持位置尺寸和角度', (tester) async {
      final h = _Harness(image);
      await h.pump(tester);
      await h.open(tester);
      await tester.pump(Duration(milliseconds: elapsed));
      h.offset.value = const Offset(160, 220);
      h.coverSize.value = const Size(96, 120);
      await tester.pump();
      final before = _reveal(tester);
      final hingeFinder = find.byKey(const ValueKey('book-reader-cover-hinge'));
      final angle = tester.widget<Transform>(hingeFinder).transform.clone();
      final cover = tester.getSize(hingeFinder);
      h.key.currentState!.pop();
      await tester.pump();
      expect(_reveal(tester), before);
      expect(tester.widget<Transform>(hingeFinder).transform, angle);
      expect(tester.getSize(hingeFinder), cover);
      await tester.pump(
        Duration(milliseconds: (elapsed / 420 * 350).ceil() - 1),
      );
      final nearEnd = _reveal(tester);
      expect(nearEnd.left, closeTo(160, 1));
      expect(nearEnd.top, closeTo(220, 1));
      expect(nearEnd.width, closeTo(96, 1));
      expect(nearEnd.height, closeTo(120, 1));
      await tester.pumpAndSettle();
      expect(h.probe.initialized, 1);
      expect(h.probe.disposed, 1);
    });
  }

  testWidgets('封面正面可见时纸面同高，翻过侧面后再延展到屏幕', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    await h.open(tester);
    final surfaceFinder = find.byKey(
      const ValueKey('book-reader-surface-transform'),
    );
    final hingeFinder = find.byKey(const ValueKey('book-reader-cover-hinge'));
    double coverHeight() =>
        tester.getSize(hingeFinder).height *
        tester.widget<Transform>(surfaceFinder).transform.entry(1, 1);
    await tester.pump(const Duration(milliseconds: 180));
    expect(_reveal(tester).height, closeTo(coverHeight(), 0.001));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('book-reader-cover-back')),
      findsOneWidget,
    );
    expect(_reveal(tester).height, greaterThan(coverHeight()));
    await tester.pumpAndSettle();
    expect(_reveal(tester), const Rect.fromLTWH(0, 0, 400, 800));
    h.key.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(_reveal(tester).height, closeTo(coverHeight(), 0.001));
    await tester.pumpAndSettle();
  });

  testWidgets('返回重新测量来源封面的位置', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    await h.open(tester);
    await tester.pumpAndSettle();
    h.offset.value = const Offset(160, 220);
    await tester.pump();
    h.key.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 340));
    final nearEnd = _reveal(tester);
    expect(nearEnd.left, closeTo(160, 2));
    expect(nearEnd.top, closeTo(220, 2));
    expect(nearEnd.width, closeTo(80, 2));
    await tester.pumpAndSettle();
  });

  testWidgets('封面翻过侧面只画纸张背面，返回时反向合上', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    await h.open(tester);
    await tester.pump(const Duration(milliseconds: 360));
    final hingeFinder = find.byKey(const ValueKey('book-reader-cover-hinge'));
    final hinge = tester.widget<Transform>(hingeFinder);
    expect(hinge.transform.entry(0, 0), lessThan(0));
    expect(
      find.descendant(of: hingeFinder, matching: find.byType(RawImage)),
      findsNothing,
      reason: '超过90度后不显示镜像封面文字',
    );
    expect(
      find.byKey(const ValueKey('book-reader-cover-back')),
      findsOneWidget,
    );
    final box = tester.renderObject<RenderBox>(hingeFinder);
    final right = MatrixUtils.transformPoint(
      hinge.transform,
      Offset(box.size.width, 0),
    );
    expect(right.dx, lessThan(0), reason: '封面右边缘已翻到书脊左侧');
    expect(right.dx.isFinite, isTrue);
    expect(h.probe.initialized, 1);
    await tester.pumpAndSettle();
    expect(hingeFinder, findsNothing, reason: '动画完成后不保留封面绘制层');
    h.key.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    final closing = tester.widget<Transform>(hingeFinder);
    expect(closing.transform.entry(0, 0), greaterThan(0));
    expect(
      find.descendant(of: hingeFinder, matching: find.byType(RawImage)),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(h.probe.disposed, 1);
    expect(tester.takeException(), isNull);
  });

  for (final removed in [false, true]) {
    testWidgets('封面${removed ? '移除' : '移出视口'}时返回默认转场', (tester) async {
      final h = _Harness(image);
      await h.pump(tester);
      await h.open(tester);
      await tester.pumpAndSettle();
      if (removed) {
        h.visible.value = false;
      } else {
        h.offset.value = const Offset(32, -200);
      }
      await tester.pump();
      h.key.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('book-reader-reveal')), findsNothing);
      expect(h.probe.initialized, 1, reason: '更换返回动效不重新初始化正文');
      expect(h.probe.disposed, 0);
      expect(
        find.byKey(const ValueKey('default-transition:/reader')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('book-reader-transition')),
          matching: find.byType(RawImage),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
    });
  }

  testWidgets('展开中返回能正常取消，不残留路由或重复初始化正文', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    await h.open(tester);
    await tester.pump(const Duration(milliseconds: 100));
    h.key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('开书'), findsOneWidget);
    expect(find.byKey(const ValueKey('book-reader-reveal')), findsNothing);
    expect(h.probe.initialized, 1);
    expect(h.probe.disposed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('没有来源封面时使用主题默认转场，正文布局保持不变', (tester) async {
    final h = _Harness(image, anchored: false);
    await h.pump(tester);
    final route = await h.open(tester);
    expect(route.transitionDuration, const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('book-reader-reveal')), findsNothing);
    expect(
      find.byKey(const ValueKey('default-transition:/reader')),
      findsOneWidget,
    );
    expect(h.probe.sizes, everyElement(const Size(400, 800)));
    await tester.pumpAndSettle();
  });

  testWidgets('来源图片尚未解码时使用默认转场，不翻开空白封面', (tester) async {
    final h = _Harness(image, decodedCover: false);
    await h.pump(tester);
    final route = await h.open(tester);
    expect(route.transitionDuration, const Duration(milliseconds: 300));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('book-reader-reveal')), findsNothing);
    expect(
      find.byKey(const ValueKey('default-transition:/reader')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('book-reader-cover-hinge')), findsNothing);
    expect(h.probe.sizes, everyElement(const Size(400, 800)));
    await tester.pumpAndSettle();
    expect(h.probe.initialized, 1);
  });

  testWidgets('减少动态效果直接显示正文，不播放封面快照', (tester) async {
    final h = _Harness(image);
    await h.pump(tester, reduced: true);
    final route = await h.open(tester);
    await tester.pumpAndSettle();
    expect(route.transitionDuration, Duration.zero);
    expect(find.byType(RawImage), findsNothing);
    expect(h.probe.initialized, 1);
    h.key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('开书'), findsOneWidget);
  });

  testWidgets('动画中隐私状态回锁，立即隐藏封面快照及正文', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    await h.open(tester);
    await tester.pump(const Duration(milliseconds: 90));
    h.privacy.relock();
    await tester.pump();
    expect(find.byType(_ReaderProbe), findsNothing);
    expect(find.byType(RawImage), findsOneWidget, reason: '仅有下层来源页，不再绘制飞行快照');
    expect(find.text('验证后阅读'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsNothing);
  });
}
