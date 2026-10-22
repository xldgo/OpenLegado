import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/models/page_turn_mode.dart';
import 'package:flutter_legado/src/features/reader/application/reader_pagination_policy.dart';
import 'package:flutter_legado/src/features/reader/layout/chapter_layout.dart';
import 'package:flutter_legado/src/features/reader/layout/chapter_pagination_session.dart';
import 'package:flutter_legado/src/features/reader/layout/paragraph_config.dart';
import 'package:flutter_legado/src/features/reader/layout/text_layout_environment.dart';

const _config = ParagraphConfig(
  backgroundColor: Color(0xffffffff),
  textColor: Color(0xff000000),
  textScaler: TextScaler.noScaling,
  textEnvironment: TextLayoutEnvironment(
    baseStyle: TextStyle(fontFamily: 'fixture'),
    textScaler: TextScaler.noScaling,
    direction: TextDirection.ltr,
  ),
);

ReaderPaginationSignature _signature({
  String book = 'book',
  int chapter = 1,
  String content = '章节内容',
  ParagraphConfig config = _config,
  int revision = 0,
  bool bold = false,
  int textBold = 0,
  EdgeInsets margins = const EdgeInsets.all(16),
  EdgeInsets insets = const EdgeInsets.only(top: 24),
  String chrome = 'header-footer',
  bool doublePage = false,
  bool scroll = false,
  String reviews = '',
}) => ReaderPaginationSignature(
  bookUrl: book,
  chapter: chapter,
  content: content,
  config: config,
  fontRevision: revision,
  boldText: bold,
  textBold: textBold,
  margins: margins,
  insets: insets,
  chromeKey: chrome,
  doublePage: doublePage,
  scroll: scroll,
  reviews: reviews,
);

Object _cacheKey({
  String book = 'book',
  int chapter = 1,
  String content = '章节内容',
  ParagraphConfig config = _config,
  double width = 300,
  double height = 500,
  Object titleKey = 450,
  int revision = 0,
  String reviews = '',
}) => ReaderPaginationPolicy.chapterCacheKey(
  bookUrl: book,
  chapter: chapter,
  content: content,
  config: config,
  width: width,
  height: height,
  titleKey: titleKey,
  fontRevision: revision,
  reviews: reviews,
);

PageInfo _page(int start, int end) => PageInfo(
  paragraphs: [
    ParagraphInfo(
      lines: const [],
      totalHeight: 20,
      startIndex: start,
      endIndex: end,
    ),
  ],
  totalHeight: 20,
);

int? _adjacent({
  int pages = 10,
  int page = 0,
  bool doublePage = false,
  bool book = true,
  bool busy = false,
  bool previous = true,
  bool next = true,
  bool previousReady = false,
  bool nextReady = false,
  bool eager = false,
}) => ReaderPaginationPolicy.adjacentChapter(
  pageCount: pages,
  currentPage: page,
  doublePage: doublePage,
  hasBook: book,
  preloading: busy,
  hasPreviousChapter: previous,
  hasNextChapter: next,
  previousReady: previousReady,
  nextReady: nextReady,
  eager: eager,
);

void main() {
  group('实际内容区与单双页', () {
    test('避让只从视口减去一次，横竖边距独立计算', () {
      final content = ReaderPaginationPolicy.contentSize(
        const Size(800, 600),
        const EdgeInsets.fromLTRB(10, 24, 30, 16),
      );
      expect(content, const Size(760, 560));
      expect(
        ReaderPaginationPolicy.bounds(
          content: content,
          margins: const EdgeInsets.fromLTRB(12, 20, 28, 30),
          doublePage: false,
          headerHeight: 20,
          footerHeight: 30,
        ),
        (width: 720.0, height: 460.0),
      );
    });

    test('双栏取左右可用宽度较小值，并各自扣除半栏间隔', () {
      expect(
        ReaderPaginationPolicy.bounds(
          content: const Size(800, 600),
          margins: const EdgeInsets.fromLTRB(12, 20, 28, 30),
          doublePage: true,
          headerHeight: 20,
          footerHeight: 30,
        ),
        (width: 364.0, height: 500.0),
      );
    });

    test('无效可用尺寸原样交给调用方报错，不伪造最小宽高', () {
      expect(
        ReaderPaginationPolicy.bounds(
          content: const Size(20, 40),
          margins: const EdgeInsets.all(16),
          doublePage: false,
          headerHeight: 20,
          footerHeight: 20,
        ),
        (width: -12.0, height: -32.0),
      );
    });

    test('单双页档位保留横屏与700宽边界，滚动始终单页', () {
      bool dual(
        int mode,
        Size size, [
        PageTurnMode turn = PageTurnMode.slide,
      ]) => ReaderPaginationPolicy.doublePage(mode, size, turn);
      expect(dual(0, const Size(900, 500)), isFalse);
      expect(dual(1, const Size(320, 600)), isTrue);
      expect(dual(2, const Size(600, 600)), isFalse);
      expect(dual(2, const Size(601, 600)), isTrue);
      expect(dual(3, const Size(699, 900)), isFalse);
      expect(dual(3, const Size(700, 900)), isTrue);
      expect(dual(3, const Size(500, 400)), isTrue);
      expect(dual(99, const Size(900, 500)), isFalse);
      for (final mode in [0, 1, 2, 3]) {
        expect(dual(mode, const Size(900, 500), PageTurnMode.scroll), isFalse);
      }
    });
  });

  group('重排签名和完整布局缓存', () {
    final paintOnly = _config.copyWith(
      backgroundColor: const Color(0xff101010),
      textColor: const Color(0xffeeeeee),
      textEnvironment: const TextLayoutEnvironment(
        baseStyle: TextStyle(fontFamily: 'fixture', color: Color(0xffeeeeee)),
        textScaler: TextScaler.noScaling,
        direction: TextDirection.ltr,
      ),
    );

    test('正文配色及环境配色不触发重排，命中同一完整布局', () {
      expect(_signature(config: paintOnly), _signature());
      expect(_signature(config: paintOnly).hashCode, _signature().hashCode);
      final cache = ChapterLayoutCache();
      final pages = [_page(0, 20)];
      cache.put(_cacheKey(), pages);
      final cached = cache.get(_cacheKey(config: paintOnly));
      expect(cached, orderedEquals(pages));
      expect(cached!.single, same(pages.single));
    });

    final geometryChanges = <String, ParagraphConfig>{
      '字号': _config.copyWith(fontSize: 18),
      '行高': _config.copyWith(lineHeight: 1.8),
      '段距': _config.copyWith(paragraphSpacing: 12),
      '缩进宽度': _config.copyWith(indent: 32),
      '缩进档位': _config.copyWith(indentCount: 3),
      '显式字距': _config.copyWith(letterSpacing: 1),
      '字体': _config.copyWith(fontFamily: 'other'),
      '字重': _config.copyWith(fontWeight: FontWeight.bold),
      '斜体': _config.copyWith(fontStyle: FontStyle.italic),
      '对齐': _config.copyWith(justify: false),
      '中文断行': _config.copyWith(useZhLayout: false),
      '悬挂': _config.copyWith(hangingPunctuation: true),
      '缩放': _config.copyWith(
        textEnvironment: const TextLayoutEnvironment(
          baseStyle: TextStyle(fontFamily: 'fixture'),
          textScaler: TextScaler.linear(1.2),
          direction: TextDirection.ltr,
        ),
      ),
      '方向': _config.copyWith(
        textEnvironment: const TextLayoutEnvironment(
          baseStyle: TextStyle(fontFamily: 'fixture'),
          textScaler: TextScaler.noScaling,
          direction: TextDirection.rtl,
        ),
      ),
      '语言': _config.copyWith(
        textEnvironment: const TextLayoutEnvironment(
          baseStyle: TextStyle(fontFamily: 'fixture'),
          textScaler: TextScaler.noScaling,
          direction: TextDirection.ltr,
          locale: Locale('zh'),
        ),
      ),
      '文字高度': _config.copyWith(
        textEnvironment: const TextLayoutEnvironment(
          baseStyle: TextStyle(fontFamily: 'fixture'),
          textScaler: TextScaler.noScaling,
          direction: TextDirection.ltr,
          heightBehavior: TextHeightBehavior(applyHeightToFirstAscent: false),
        ),
      ),
    };
    for (final entry in geometryChanges.entries) {
      test('${entry.key}变化使重排签名和完整布局缓存失效', () {
        expect(_signature(config: entry.value), isNot(_signature()));
        final cache = ChapterLayoutCache()..put(_cacheKey(), [_page(0, 20)]);
        expect(cache.get(_cacheKey(config: entry.value)), isNull);
      });
    }

    test('章节身份、可用尺寸、首页高度、字体版本和段评显隐隔离缓存', () {
      final cache = ChapterLayoutCache()..put(_cacheKey(), [_page(0, 20)]);
      for (final key in [
        _cacheKey(book: 'other'),
        _cacheKey(chapter: 2),
        _cacheKey(content: '新内容'),
        _cacheKey(width: 301),
        _cacheKey(height: 501),
        _cacheKey(titleKey: 449),
        _cacheKey(revision: 1),
        _cacheKey(reviews: '1:geometry'),
      ]) {
        expect(cache.get(key), isNull);
      }
    });

    test('签名保留宿主布局及原始字重设置的失效条件', () {
      for (final signature in [
        _signature(book: 'other'),
        _signature(chapter: 2),
        _signature(content: '新内容'),
        _signature(revision: 1),
        _signature(bold: true),
        _signature(textBold: 1),
        _signature(margins: EdgeInsets.zero),
        _signature(insets: EdgeInsets.zero),
        _signature(chrome: 'hidden'),
        _signature(doublePage: true),
        _signature(scroll: true),
        _signature(reviews: '1:geometry'),
        _signature(
          config: _config.copyWith(textScaler: const TextScaler.linear(2)),
        ),
      ]) {
        expect(signature, isNot(_signature()));
      }
    });
  });

  group('目标就绪与原文恢复', () {
    final pages = [_page(0, 10), _page(15, 30), _page(35, 50)];

    test('空的未完成布局等待，空的已完成布局结束等待', () {
      const target = ReaderPaginationTarget(requestedPage: 0);
      expect(target.waiting([], complete: false), isTrue);
      expect(target.waiting([], complete: true), isFalse);
      expect(target.ready([], complete: true), isFalse);
      expect(target.resolve([]), 0);
    });

    test('显式远页请求等待生成足够页面，最终越界才夹到末页', () {
      const target = ReaderPaginationTarget(requestedPage: 4);
      expect(target.waiting(pages, complete: false), isTrue);
      expect(target.ready(pages, complete: true), isTrue);
      expect(target.resolve(pages), 2);
      expect(
        const ReaderPaginationTarget(requestedPage: 1)
            .ready(pages, complete: false),
        isTrue,
      );
    });

    test('锚点恰好处于当前末尾仍等待，后续页到达后定位到下一页', () {
      const target = ReaderPaginationTarget(requestedPage: 0, sourceAnchor: 30);
      expect(target.waiting(pages.take(2).toList(), complete: false), isTrue);
      expect(target.ready(pages, complete: false), isTrue);
      expect(target.resolve(pages), 2);
    });

    test('原文锚点优先于旧布局页号，空白间隙归后页，越界归末页', () {
      expect(
        const ReaderPaginationTarget(
          requestedPage: 2,
          sourceAnchor: 3,
        ).resolve(pages),
        0,
      );
      expect(
        const ReaderPaginationTarget(
          requestedPage: 0,
          sourceAnchor: 12,
        ).resolve(pages),
        1,
      );
      const beyond = ReaderPaginationTarget(
        requestedPage: 0,
        sourceAnchor: 100,
      );
      expect(beyond.waiting(pages, complete: false), isTrue);
      expect(beyond.waiting(pages, complete: true), isFalse);
      expect(beyond.resolve(pages), 2);
    });

    test('末页请求优先于锚点，必须等待整章完成', () {
      const target = ReaderPaginationTarget(requestedPage: -1, sourceAnchor: 3);
      expect(target.waiting(pages, complete: false), isTrue);
      expect(target.ready(pages, complete: true), isTrue);
      expect(target.resolve(pages), 2);
    });
  });

  group('相邻章串行预载', () {
    test('首尾两屏预取，章节中间不提前启动', () {
      expect(_adjacent(page: 0), -1);
      expect(_adjacent(page: 1), -1);
      expect(_adjacent(page: 2), isNull);
      expect(_adjacent(page: 7), isNull);
      expect(_adjacent(page: 8), 1);
      expect(_adjacent(page: 9), 1);
    });

    test('双页以屏计算距离，奇数页末屏保留', () {
      expect(_adjacent(pages: 9, page: 3, doublePage: true), -1);
      expect(_adjacent(pages: 9, page: 4, doublePage: true), isNull);
      expect(_adjacent(pages: 9, page: 6, doublePage: true), 1);
      expect(_adjacent(pages: 9, page: 8, doublePage: true), 1);
    });

    test('立即预载按距离选择，等距优先下一章', () {
      expect(_adjacent(pages: 5, page: 1, eager: true), -1);
      expect(_adjacent(pages: 5, page: 2, eager: true), 1);
      expect(_adjacent(pages: 5, page: 3, eager: true), 1);
      expect(_adjacent(pages: 1, eager: true), 1);
      expect(_adjacent(pages: 1, nextReady: true, eager: true), -1);
    });

    test('无书无页面、在途任务、缺邻章和已准备预览均不重复预取', () {
      expect(_adjacent(pages: 0), isNull);
      expect(_adjacent(book: false), isNull);
      expect(_adjacent(busy: true, eager: true), isNull);
      expect(_adjacent(previous: false), isNull);
      expect(_adjacent(previousReady: true), isNull);
      expect(_adjacent(page: 9, next: false), isNull);
      expect(_adjacent(page: 9, nextReady: true), isNull);
      expect(
        _adjacent(eager: true, previousReady: true, nextReady: true),
        isNull,
      );
    });
  });

  test('异步任务必须同时匹配书籍、章节与代次', () {
    const task = ReaderPaginationTask(
      bookUrl: 'book',
      chapter: 2,
      generation: 3,
    );
    expect(task.matches(bookUrl: 'book', chapter: 2, generation: 3), isTrue);
    expect(task.matches(bookUrl: 'other', chapter: 2, generation: 3), isFalse);
    expect(task.matches(bookUrl: null, chapter: 2, generation: 3), isFalse);
    expect(task.matches(bookUrl: 'book', chapter: 1, generation: 3), isFalse);
    expect(task.matches(bookUrl: 'book', chapter: 2, generation: 4), isFalse);
  });
}
