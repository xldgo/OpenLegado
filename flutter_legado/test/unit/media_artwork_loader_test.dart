import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/models/book_source.dart';
import 'package:flutter_legado/src/services/media_artwork_loader.dart';
import 'package:flutter_legado/src/services/cover_decode_loader.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';

class _CoverApi extends MockBookApi {
  _CoverApi(this.bytes);
  final Uint8List bytes;
  final requests = <({String url, String source})>[];
  @override
  Future<String> fetchImageWithDecode(String url, String sourceJson) async {
    requests.add((url: url, source: sourceJson));
    return jsonEncode({'base64': base64Encode(bytes), 'len': bytes.length});
  }
}

Future<Uint8List> imageBytes(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xFF2255AA), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('大图在解码时缩为384px内，保留纵横比和有界传输大小', (tester) async {
    await tester.runAsync(() async {
      final bytes = await MediaArtworkLoader.thumbnail(
        MemoryImage(await imageBytes(1200, 2400)),
      );
      expect(bytes, isNotNull);
      expect(bytes!.length, lessThanOrEqualTo(MediaArtworkLoader.maxBytes));
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 192);
      expect(frame.image.height, 384);
      frame.image.dispose();
      codec.dispose();
    });
  });

  testWidgets('本地文件、自定义封面优先、缓存和隐私默认封面', (tester) async {
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('media-artwork-');
      try {
        final file = File('${directory.path}/cover.png');
        await file.writeAsBytes(await imageBytes(40, 80));
        final book = Book(
          bookUrl: 'book',
          coverUrl: '/does-not-exist.jpg',
          customCoverUrl: file.uri.toString(),
        );
        final loader = MediaArtworkLoader(api: MockBookApi());
        final first = await loader.load(book);
        expect(first, isNotNull);
        expect(identical(await loader.load(book), first), isTrue);
        expect(await loader.load(book, hidden: true), isNot(equals(first)));
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });

  testWidgets('已解密封面复用既有缓存，不重新发请求', (tester) async {
    await tester.runAsync(() async {
      final bytes = await imageBytes(20, 30);
      CoverDecodeLoader.putCached(
        'source',
        'https://example.invalid/a.jpg',
        bytes,
      );
      final loader = MediaArtworkLoader(api: MockBookApi());
      final result = await loader.load(
        const Book(origin: 'source', coverUrl: 'https://example.invalid/a.jpg'),
      );
      expect(result, isNotNull);
      final codec = await ui.instantiateImageCodec(result!);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 20);
      expect(frame.image.height, 30);
      frame.image.dispose();
      codec.dispose();
    });
  });

  testWidgets('损坏或缺失封面回退默认，同一请求并发只生成一份缩略图', (tester) async {
    await tester.runAsync(() async {
      final loader = MediaArtworkLoader(api: MockBookApi());
      const book = Book(coverUrl: '/does-not-exist.png');
      final results = await Future.wait([loader.load(book), loader.load(book)]);
      expect(results.first, isNotNull);
      expect(identical(results.first, results.last), isTrue);
      expect(await loader.load(null), isNotNull);
    });
  });

  testWidgets('复合请求头和书源解密均复用既有图片接口，不向原生传URL', (tester) async {
    await tester.runAsync(() async {
      final api = _CoverApi(await imageBytes(24, 36));
      await api.bookSourceRepository.addBookSource(
        const BookSource(
          bookSourceUrl: 'artwork-source',
          bookSourceName: '测试',
          coverDecodeJs: 'result',
        ),
      );
      CoverDecodeLoader.invalidateSourceRegistry();
      try {
        final loader = MediaArtworkLoader(api: api);
        const composite =
            'https://example.invalid/header.jpg,{"headers":{"Referer":"fixture"}}';
        expect(await loader.load(const Book(coverUrl: composite)), isNotNull);
        expect(api.requests.single.url, composite);
        expect(
          await loader.load(
            const Book(
              origin: 'artwork-source',
              coverUrl: 'https://example.invalid/encrypted.jpg',
            ),
          ),
          isNotNull,
        );
        expect(api.requests, hasLength(2));
        final source = jsonDecode(api.requests.last.source) as Map;
        expect((source['ruleContent'] as Map)['imageDecode'], 'result');
      } finally {
        CoverDecodeLoader.invalidateSourceRegistry();
      }
    });
  });
}
