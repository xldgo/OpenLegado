import 'package:flutter_legado/src/data/services/comic_image_decode_cache.dart';

import '../fixtures/app_test_api.dart';
import '../mocks/book_image_fixture.dart';

import 'package:flutter_legado/src/domain/contracts/book_image_repository.dart';

import '../mocks/reading_fixture.dart';
import '../mocks/book_source_fixture.dart';
import '../mocks/bookshelf_fixture.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/reader_comic/presentation/reader_comic_screen.dart';

/// 1x1 透明 PNG（与 reader_comic_decode_test 同款，作为解码结果 base64）
const _kPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQAB'
    'h6FO1AAAAABJRU5ErkJggg==';

const _kBookUrl = 'mock://comic/1';
const _kImageUrl = 'https://cdn.example.com/img/1.jpg';

/// 含 imageDecode 规则的漫画书源（对齐 reader_comic_decode_test 形态）
BookSource _buildComicSource() {
  return BookSource(
    bookSourceUrl: 'https://manga.example.com',
    bookSourceName: '测试漫画源',
    bookSourceGroup: '漫画',
    bookSourceType: 2,
    enabled: true,
    ruleContent: ContentRule(content: '.x', imageDecode: 'decode(result);'),
    customOrder: 0,
    lastUpdateTime: 0,
    respondTime: 0,
    weight: 0,
  );
}

/// 测试专用 MockBookApi：注入漫画书 + 含 img 的章节正文 + 解码返回；
/// 网络下载链路计数用于断言「磁盘命中不再走网络」。
class _ComicCacheMockApi extends MockBookApi {
  late final _fixtureImages = TestBookImageRepository(
    delegate: super.bookImageRepository,
    fetch: _fixtureFetchImage,
  );
  @override
  BookImageRepository get bookImageRepository => _fixtureImages;

  late final _fixtureReading = TestReadingRepository(
    delegate: super.readingRepository,
    getChapters: _readingGetChapters,
    fetchChapterContent: _readingFetchChapterContent,
  );
  @override
  TestReadingRepository get readingRepository => _fixtureReading;

  late final _fixtureSources = TestBookSourceRepository(
    delegate: super.bookSourceRepository,
    getBookSources: _fixtureGetBookSources,
  );
  @override
  TestBookSourceRepository get bookSourceRepository => _fixtureSources;

  late final _fixtureShelf = TestBookshelfRepository(
    delegate: super.bookshelfRepository,
    getBook: _fixtureGetBook,
  );
  @override
  TestBookshelfRepository get bookshelfRepository => _fixtureShelf;

  _ComicCacheMockApi({required this.source, required this.decodeCalls});

  final BookSource source;
  final List<String> decodeCalls;

  Future<List<BookSource>> _fixtureGetBookSources() async => [source];

  Future<Book?> _fixtureGetBook(String bookUrl) async => Book(
    bookUrl: bookUrl,
    tocUrl: 'https://manga.example.com/comic/1/',
    name: '测试漫画',
    author: '作者',
    origin: source.bookSourceUrl,
    originName: source.bookSourceName,
    canUpdate: true,
    totalChapterNum: 1,
  );

  Future<List<BookChapter>> _readingGetChapters(String bookUrl) async => [
    BookChapter(
      index: 0,
      url: 'https://manga.example.com/comic/1/ch1.html',
      title: '第一章',
    ),
  ];

  Future<String> _readingFetchChapterContent(
    String bookUrl,
    String chapterUrl,
    String sourceUrl,
  ) async {
    return '<p><img src="$_kImageUrl"></p>';
  }

  Future<String> _fixtureFetchImage(String url, String sourceJson) async {
    decodeCalls.add(url);
    return jsonEncode({'base64': _kPngBase64, 'len': 68});
  }
}

void main() {
  Widget buildApp(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ReaderComicScreen(bookUrl: _kBookUrl)),
    );
  }

  testWidgets('P4-2a 磁盘缓存优先：冷启走网络并写缓存；清内存后重挂载磁盘命中不再走网络', (tester) async {
    final decodeCalls = <String>[];
    final api = _ComicCacheMockApi(
      source: _buildComicSource(),
      decodeCalls: decodeCalls,
    );
    final container = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(container.dispose);

    // ── 会话 1：冷启动（磁盘缓存为空）→ 网络加载并写磁盘缓存 ──
    await tester.pumpWidget(buildApp(container));
    await tester.pumpAndSettle();
    expect(decodeCalls, [contains(_kImageUrl)], reason: '冷启动应走一次网络解码');
    // 屏幕侧 fire-and-forget 的 saveImageCache 应已落地（mock 内存 Map 模拟）
    final saved = await api.bookImageRepository.getImageCache(
      _kBookUrl,
      _kImageUrl,
    );
    expect(saved, isNotNull, reason: '加载成功后应写入图片磁盘缓存');

    // ── 会话 2：清内存缓存（模拟应用重启）→ 磁盘命中，不再走网络 ──
    ComicImageDecodeCache.clearForTest();
    await tester.pumpWidget(buildApp(container));
    await tester.pumpAndSettle();
    expect(decodeCalls.length, 1, reason: '磁盘缓存命中后不得再次调用网络解码链（仍为 1 次）');
    expect(
      find.byType(Image, skipOffstage: false),
      findsWidgets,
      reason: '磁盘命中应直接渲染图片',
    );
  });
}
