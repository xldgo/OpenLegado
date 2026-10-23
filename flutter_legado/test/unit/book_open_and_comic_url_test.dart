import 'package:flutter_legado/src/domain/services/book_metadata_policy.dart';
import 'package:flutter_legado/src/domain/services/book_type_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/utils/book_open_utils.dart';
import 'package:flutter_legado/src/utils/comic_image_utils.dart';

void main() {
  group('BookOpenUtils 类型分流（对齐 startActivityForBook）', () {
    test('routeForTypeBits 按位标记选路由', () {
      expect(BookOpenUtils.routeForTypeBits(BookType.video), AppRoutes.video);
      expect(BookOpenUtils.routeForTypeBits(BookType.audio), AppRoutes.audio);
      expect(
        BookOpenUtils.routeForTypeBits(BookType.image),
        AppRoutes.readerComic,
      );
      expect(BookOpenUtils.routeForTypeBits(BookType.text), AppRoutes.reader);
      expect(BookOpenUtils.routeForTypeBits(0), AppRoutes.reader);
    });

    test('argumentsForRoute 漫画传 bookUrl，音视频传 Book', () {
      const book = Book(
        bookUrl: 'https://ex.com/b',
        name: '测',
        bookType: BookType.image,
      );
      expect(
        BookOpenUtils.argumentsForRoute(AppRoutes.readerComic, book),
        book.bookUrl,
      );
      expect(
        BookOpenUtils.argumentsForRoute(AppRoutes.video, book),
        same(book),
      );
      expect(BookOpenUtils.argumentsForRoute(AppRoutes.reader, book), isNull);
    });
  });

  group('mergeBookType（P2-15 ② 详情解析 type 回流合并）', () {
    test('非零新值覆盖媒体位，非媒体标记位保留', () {
      final existing = BookType.text | BookType.local; // 8 + 4096
      expect(
        BookTypePolicy.mergeBookType(existing, BookType.image),
        BookType.image | BookType.local,
      );
    });

    test('新值 video 覆盖既有 image 媒体位', () {
      expect(
        BookTypePolicy.mergeBookType(BookType.image, BookType.video),
        BookType.video,
      );
    });

    test('零值/缺键（Rust 侧零值省略）保留现有值', () {
      final existing = BookType.image | BookType.notShelf;
      expect(BookTypePolicy.mergeBookType(existing, 0), existing);
      expect(BookTypePolicy.mergeBookType(0, 0), 0);
    });

    test('新值仅含 mask 外标记位（notShelf）时不动媒体位', () {
      final existing = BookType.audio;
      expect(
        BookTypePolicy.mergeBookType(existing, BookType.notShelf),
        existing,
      );
    });

    test('mergeWebInfo：详情 JSON type=64 覆盖入架文本位 → 漫画路由', () {
      const book = Book(
        bookUrl: 'https://ex.com/b',
        name: '二合一书',
        bookType: BookType.text,
      );
      final merged = BookMetadataPolicy.mergeWebInfo(
        book,
        const Book(name: '二合一书', bookType: 64),
      );
      expect(merged.bookType & BookTypePolicy.typeMask, BookType.image);
      expect(
        BookOpenUtils.routeForTypeBits(merged.bookType),
        AppRoutes.readerComic,
      );
    });

    test('mergeWebInfo：详情缺 type 键保留现有媒体位', () {
      const book = Book(
        bookUrl: 'https://ex.com/b',
        name: '漫画书',
        bookType: BookType.image,
      );
      final merged = BookMetadataPolicy.mergeWebInfo(
        book,
        const Book(name: '漫画书'),
      );
      expect(merged.bookType, BookType.image);
    });
  });

  group('mergeDbBook（P2-11 §198 originBookUrl 空白值语义）', () {
    test('DB 值纯空白时让位路由有效值（不压过）', () {
      final route = const Book(
        bookUrl: 'https://ex.com/b',
        name: '书',
        originBookUrl: 'https://current-source.com/page',
      );
      final db = const Book(
        bookUrl: 'https://ex.com/b',
        name: '书',
        originBookUrl: '   \n\t  ',
      );
      final merged = BookMetadataPolicy.mergeDbBook(route, db);
      expect(merged.originBookUrl, 'https://current-source.com/page');
    });

    test('DB 值非空白时仍覆盖路由值（DB 权威语义不变）', () {
      final route = const Book(
        bookUrl: 'https://ex.com/b',
        name: '书',
        originBookUrl: 'https://stale-route.com/page',
      );
      final db = const Book(
        bookUrl: 'https://ex.com/b',
        name: '书',
        originBookUrl: 'https://db.com/page',
      );
      final merged = BookMetadataPolicy.mergeDbBook(route, db);
      expect(merged.originBookUrl, 'https://db.com/page');
    });

    test('DB 值空白含非空白字符时按原值取用（不 trim 后值）', () {
      final route = const Book(
        bookUrl: 'https://ex.com/b',
        name: '书',
        originBookUrl: 'https://stale-route.com/page',
      );
      final db = const Book(
        bookUrl: 'https://ex.com/b',
        name: '书',
        originBookUrl: '  https://db.com/page  ',
      );
      final merged = BookMetadataPolicy.mergeDbBook(route, db);
      expect(merged.originBookUrl, '  https://db.com/page  ');
    });

    test('DB 与路由皆空时结果为空（行为不变）', () {
      final route = const Book(bookUrl: 'https://ex.com/b', name: '书');
      final db = const Book(
        bookUrl: 'https://ex.com/b',
        name: '书',
        originBookUrl: '  ',
      );
      final merged = BookMetadataPolicy.mergeDbBook(route, db);
      expect(merged.originBookUrl, '');
    });
  });

  group('parseComicImageUrls 复合 URL', () {
    test('双引号 src 含 JSON headers 完整抽出（不截断在第一个引号）', () {
      const html =
          r'''<img src="https://cdn.example.com/a.webp,{"headers":{"Referer":"https://site.com/"}}">''';
      final urls = parseComicImageUrls(html);
      expect(urls, hasLength(1));
      expect(
        urls.first,
        r'https://cdn.example.com/a.webp,{"headers":{"Referer":"https://site.com/"}}',
      );
      expect(urls.first, isNot(contains(RegExp(r',\s*\{$'))));
      expect(urls.first.endsWith('}'), isTrue);
    });

    test('单引号复合 URL 完整抽出', () {
      const html =
          r'''<img src='https://cdn.example.com/b.jpg,{"headers":{"User-Agent":"X"}}'>''';
      final urls = parseComicImageUrls(html);
      expect(urls, hasLength(1));
      expect(urls.first, startsWith('https://cdn.example.com/b.jpg,{'));
      expect(urls.first, contains('"User-Agent"'));
    });

    test('普通 src 不受影响', () {
      const html = '<img src="https://cdn.example.com/plain.png">';
      expect(parseComicImageUrls(html), ['https://cdn.example.com/plain.png']);
    });

    test('必应漫画样例：纯 img HTML 判定为图片主导正文', () {
      const html = '''
<img src="https://www.jjmhw6.top/static/upload/book/714/30286/1135571.jpg">
<img src="https://www.jjmhw6.top/static/upload/book/714/30286/1135572.jpg">
<img src="https://www.jjmhw6.top/static/upload/book/714/30286/1135573.jpg">
''';
      expect(isImageDominantContent(html), isTrue);
      expect(parseComicImageUrls(html), hasLength(3));
    });

    test('图文混排不判定为图片主导', () {
      const html =
          '<p>这是一段足够长的小说正文，用来避免被误判成纯图片章节。</p><img src="https://cdn.example.com/a.jpg">';
      expect(isImageDominantContent(html), isFalse);
    });

    test('旧截断正则会失败的样例：复合 URL 不被切成 url,{', () {
      const truncatedBad = 'https://cdn.example.com/a.webp,{';
      const html =
          r'''<p><img src="https://cdn.example.com/a.webp,{"headers":{"Referer":"https://x/"}}"></p>''';
      final urls = parseComicImageUrls(html);
      expect(urls.first, isNot(equals(truncatedBad)));
      expect(isCompositeImageUrl(urls.first), isTrue);
    });

    test('行解析兜底识别复合图片 URL', () {
      const line =
          r'https://cdn.example.com/pic/1.webp,{"headers":{"Referer":"https://x/"}}';
      expect(looksLikeImageUrl(line), isTrue);
      expect(parseComicImageUrls(line), [line]);
    });

    test('m3u8/视频 URL 不判定为图片', () {
      expect(
        looksLikeImageUrl('https://vip.ffzy-plays.com/2025/49109/index.m3u8'),
        isFalse,
      );
      expect(isImageDominantContent('https://cdn.example/v.m3u8'), isFalse);
    });
  });

  group('looksLikeImageBytes 魔数', () {
    test('识别 JPEG/PNG/GIF/WEBP，拒绝密文', () {
      expect(looksLikeImageBytes([0xFF, 0xD8, 0xFF, 0xE0]), isTrue);
      expect(looksLikeImageBytes([0x89, 0x50, 0x4E, 0x47]), isTrue);
      expect(looksLikeImageBytes([0x47, 0x49, 0x46, 0x38]), isTrue);
      expect(
        looksLikeImageBytes([
          0x52,
          0x49,
          0x46,
          0x46,
          0,
          0,
          0,
          0,
          0x57,
          0x45,
          0x42,
          0x50,
        ]),
        isTrue,
      );
      expect(looksLikeImageBytes([0x01, 0x02, 0x03, 0x04]), isFalse);
      expect(looksLikeImageBytes([]), isFalse);
    });
  });
}
