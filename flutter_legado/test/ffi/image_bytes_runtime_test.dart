library;

/// 通过实际 DLL 验证字节传输、CBZ 与缓存，不依赖模拟桥。— Codex + Bridge
@Timeout(Duration(minutes: 3))
import '../helpers/native_ffi.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_book_image_repository.dart';
import 'package:flutter_legado/src/data/services/rust_local_book_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  const images = RustBookImageRepository();
  const books = RustLocalBookService();
  final bytes = Uint8List.fromList(List.generate(1024 * 1024, (i) => i % 256));
  setUpAll(() async {
    root = Directory(
      '.dart_tool/image-bytes-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    await RustLib.init(externalLibrary: nativeTestLibrary());
    await bridge.init();
    await bridge.dbOpen(path: '${root.absolute.path}/images.db');
    await bridge.setImageCacheDir(dir: '${root.absolute.path}/cache');
  });

  test('缓存往返完整字节域和 1 MiB 数据，未命中及空数据不伪造命中', () async {
    expect(
      await images.getImageCache('书', 'https://example.test/missing.png'),
      isNull,
    );
    expect(
      await images.saveImageCache(
        bookUrl: '书',
        url: 'https://example.test/page.png',
        bytes: bytes,
      ),
      isTrue,
    );
    final stored = await images.getImageCache(
      '书',
      'https://example.test/page.png',
    );
    expect(stored, isA<Uint8List>());
    expect(stored, bytes);
    expect(
      await images.saveImageCache(
        bookUrl: '书',
        url: 'https://example.test/empty.png',
        bytes: [],
      ),
      isTrue,
    );
    expect(
      await images.getImageCache('书', 'https://example.test/empty.png'),
      isNull,
    );
  });

  test('CBZ 中文和空格条目及 cbz 前缀字节一致，缺条目明确失败', () async {
    final zip = Archive()
      ..addFile(ArchiveFile('目录/封面 01.png', bytes.length, bytes));
    final file = File('${root.absolute.path}/漫画.cbz')
      ..writeAsBytesSync(ZipEncoder().encode(zip));
    final original = await books.cbzReadPage(
      path: file.path,
      entry: '目录/封面 01.png',
    );
    expect(original, bytes);
    expect(
      await books.cbzReadPage(path: file.path, entry: 'cbz://目录/封面 01.png'),
      bytes,
    );
    await expectLater(
      books.cbzReadPage(path: file.path, entry: '不存在.png'),
      throwsA(anything),
    );
  });

  test('真实 HTTP 图片直接返回字节，保留书源请求头和 Referer', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final headers = <String, String?>{};
    server.listen((request) async {
      headers['referer'] = request.headers.value('referer');
      headers['x-image'] = request.headers.value('x-image');
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.add(bytes);
      await request.response.close();
    });
    try {
      final source = jsonEncode({
        'bookSourceUrl': 'http://127.0.0.1:${server.port}/source',
        'bookSourceName': '图片',
        'header': jsonEncode({'X-Image': 'preserved'}),
      });
      final result = await images.fetchImageWithDecode(
        'http://127.0.0.1:${server.port}/page.png',
        source,
      );
      expect(result, bytes);
      expect(headers['referer'], 'http://127.0.0.1:${server.port}/');
      expect(headers['x-image'], 'preserved');
    } finally {
      await server.close(force: true);
    }
  });
}
