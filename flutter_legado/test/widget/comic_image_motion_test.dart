import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/reader_comic/presentation/views/comic_image_item.dart';
import 'package:flutter_legado/src/data/services/comic_image_decode_cache.dart';
import 'package:flutter_legado/src/domain/contracts/book_image_repository.dart';
import 'package:flutter_legado/src/domain/contracts/local_book_service.dart';
import 'package:flutter_legado/src/domain/contracts/network_service.dart';
import 'package:flutter_legado/src/models/models.dart';

const _url = 'https://motion.test/page.png';
const _source = 'https://motion.test';
final _bytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGP4z8AARAwQCgAf7gP9i18U1AAAAABJRU5ErkJggg==',
);

class _Images extends Fake implements BookImageRepository {
  final pending = Completer<Uint8List>();
  List<int>? disk;
  int fetches = 0;
  @override
  Future<List<int>?> getImageCache(String book, String url) async => disk;
  @override
  Future<Uint8List> fetchImageWithDecode(String url, String json) {
    fetches++;
    return pending.future;
  }

  @override
  Future<bool> saveImageCache({
    required String bookUrl,
    required String url,
    required List<int> bytes,
  }) async => true;
}

class _Local extends Fake implements LocalBookService {}

class _Network extends Fake implements NetworkService {}

Widget _host(
  _Images images, {
  bool reduced = false,
  bool disabled = false,
  VoidCallback? error,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: ComicImageItem(
        url: _url,
        book: const Book(bookUrl: 'book'),
        source: BookSource.fromJson({
          'bookSourceUrl': _source,
          'bookSourceName': '测试',
        }),
        bookUrl: 'book',
        images: images,
        localBooks: _Local(),
        network: _Network(),
        failed: false,
        headers: const {},
        fit: BoxFit.contain,
        colorFilter: null,
        enableEInk: false,
        eInkThreshold: 128,
        disableCrossFade: disabled,
        onError: error ?? () {},
        onRetry: () {},
        onLongPress: () {},
      ),
    ),
  ),
);

Future<void> _decode(WidgetTester tester) async {
  for (var round = 0; round < 30; round++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    if (tester
        .widgetList<RawImage>(find.byType(RawImage))
        .any((image) => image.image != null)) {
      return;
    }
  }
  fail('真实图片解码没有产生首帧');
}

void main() {
  setUp(() {
    ComicImageDecodeCache.clearForTest();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  testWidgets('加载占位不淡化，新图片实际首帧出现后才淡入，重挂内存缓存直接显示', (tester) async {
    final images = _Images();
    var errors = 0;
    await tester.pumpWidget(_host(images, error: () => errors++));
    await tester.pump();
    expect(images.fetches, 1);
    expect(find.byKey(const ValueKey('mangaImageFade')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    images.pending.complete(_bytes);
    await tester.pump();
    await _decode(tester);
    final fade = find.byKey(const ValueKey('mangaImageFade'));
    expect(fade, findsOneWidget);
    expect(tester.widget<FadeTransition>(fade).opacity.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_host(images));
    await _decode(tester);
    expect(find.byKey(const ValueKey('mangaImageFade')), findsNothing);
    expect(images.fetches, 1);
    expect(errors, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('磁盘缓存无需重复淡入或请求网络', (tester) async {
    final images = _Images()..disk = _bytes;
    await tester.pumpWidget(_host(images));
    await _decode(tester);
    expect(find.byKey(const ValueKey('mangaImageFade')), findsNothing);
    expect(images.fetches, 0);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final disabled in [true, false]) {
    testWidgets('${disabled ? '关闭漫画淡入' : '系统减少动态效果'}时图片直接呈现', (tester) async {
      final images = _Images();
      await tester.pumpWidget(
        _host(images, disabled: disabled, reduced: !disabled),
      );
      await tester.pump();
      images.pending.complete(_bytes);
      await tester.pump();
      await _decode(tester);
      final fade = find.byKey(const ValueKey('mangaImageFade'));
      if (disabled) {
        expect(fade, findsNothing);
      } else {
        expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
