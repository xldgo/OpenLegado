@Tags(['native'])
@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/bridge/entity_dto_mapping.dart';
import 'package:flutter_legado/src/data/services/rust_cache_download_service.dart';
import 'package:flutter_legado/src/models/book.dart';

import '../helpers/native_ffi.dart';

/// 新增流入口使用真实宿主库，确认正文/图片落在同一缓存且不创建手动任务。— Codex + Bridge
void main() {
  test('自动缓存流完成时图片可离线读取，手动任务列表保持空', () async {
    final root = await Directory(
      '.dart_tool/manga-auto-ffi-${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final base = 'http://127.0.0.1:${server.port}';
    final requests = <String>[];
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
    );
    server.listen((request) async {
      requests.add(request.uri.path);
      switch (request.uri.path) {
        case '/toc':
          request.response.headers.contentType = ContentType.html;
          request.response.write(
            '<a href="/chapter/0">首章</a><a href="/chapter/1">次章</a>',
          );
        case '/chapter/1':
          request.response.headers.contentType = ContentType.html;
          request.response.write(
            '<div class="content"><img src="$base/page.png"></div>',
          );
        case '/page.png':
          request.response.headers.contentType = ContentType('image', 'png');
          request.response.add(png);
        default:
          request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
    addTearDown(() async {
      await server.close(force: true);
      RustLib.dispose();
    });
    await RustLib.init(externalLibrary: nativeTestLibrary());
    await bridge.init();
    await bridge.dbOpen(path: '${root.path}/legado.db');
    await bridge.setImageCacheDir(dir: '${root.path}/images');
    await bridge.sourceImport(
      jsonArray: jsonEncode([
        {
          'bookSourceUrl': base,
          'bookSourceName': '本机漫画',
          'bookSourceType': 2,
          'ruleToc': {
            'chapterList': 'a',
            'chapterName': 'text',
            'chapterUrl': 'href',
          },
          'ruleContent': {'content': '.content@html'},
        },
      ]),
    );
    final book = Book(
      bookUrl: '$base/book',
      name: '自动缓存测试',
      origin: base,
      tocUrl: '$base/toc',
      bookType: 2,
    );
    await bridge.bookshelfAdd(book: bookToDto(book));
    final chapters = await bridge.readerRefreshToc(
      bookUrl: book.bookUrl,
      sourceUrl: base,
    );
    expect(chapters.chapters.length, 2);
    const downloads = RustCacheDownloadService();
    expect(
      await downloads
          .prefetchMangaChapters(
            bookUrl: book.bookUrl,
            currentChapter: 0,
            nextCount: 1,
            previousCount: 0,
          )
          .toList(),
      [1],
    );
    expect(requests, ['/toc', '/chapter/1', '/page.png']);
    expect(await bridge.cacheListCachedChapterUrls(bookUrl: book.bookUrl), [
      '$base/chapter/1',
    ]);
    expect(
      await bridge.getImageCache(bookUrl: book.bookUrl, url: '$base/page.png'),
      png,
    );
    expect(await downloads.cacheDownloadList(), isEmpty);
  });
}
