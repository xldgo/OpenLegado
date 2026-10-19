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
import 'package:flutter_legado/src/widgets/book_cover.dart';
import 'package:flutter_legado/src/widgets/reader/book_reader_route.dart';

const _book = Book(bookUrl: 'book://transition', name: '封面展开');

class _Reader extends ReaderNotifier {
  @override
  ReaderState build() => const ReaderState(
    currentBook: _book,
    isLoading: true,
    backgroundColor: Color(0xFFE9DFC9),
  );

  void loaded() => state = state.copyWith(isLoading: false);
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
          listenable: Listenable.merge([offset, visible]),
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
                        image: image,
                        width: 80,
                        height: 112,
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

  _Harness(this.image, {this.anchored = true});
  final ui.Image image;
  final bool anchored;

  Future<void> pump(WidgetTester tester, {bool reduced = false}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: navigation,
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
  final clip = tester.widget<ClipPath>(
    find.byKey(const ValueKey('book-reader-reveal')),
  );
  return clip.clipper!.getClip(const Size(400, 800)).getBounds();
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

  testWidgets('封面逐步展开，正文始终全屏布局且完成时不重新初始化', (tester) async {
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

  testWidgets('返回重新测量来源封面的位置', (tester) async {
    final h = _Harness(image);
    await h.pump(tester);
    await h.open(tester);
    await tester.pumpAndSettle();
    h.offset.value = const Offset(160, 220);
    await tester.pump();
    h.key.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 270));
    final nearEnd = _reveal(tester);
    expect(nearEnd.left, closeTo(160, 2));
    expect(nearEnd.top, closeTo(220, 2));
    expect(nearEnd.width, closeTo(80, 2));
    await tester.pumpAndSettle();
  });

  for (final removed in [false, true]) {
    testWidgets('封面${removed ? '移除' : '移出视口'}时返回淡出', (tester) async {
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
      expect(_reveal(tester), const Rect.fromLTWH(0, 0, 400, 800));
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

  testWidgets('没有来源封面时短淡入，正文布局保持不变', (tester) async {
    final h = _Harness(image, anchored: false);
    await h.pump(tester);
    final route = await h.open(tester);
    expect(route.transitionDuration, const Duration(milliseconds: 160));
    await tester.pump(const Duration(milliseconds: 80));
    expect(_reveal(tester), const Rect.fromLTWH(0, 0, 400, 800));
    expect(h.probe.sizes, everyElement(const Size(400, 800)));
    await tester.pumpAndSettle();
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
