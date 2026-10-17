import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/data/services/comic_image_decode_cache.dart';
import 'package:flutter_legado/src/domain/contracts/book_image_repository.dart';
import 'package:flutter_legado/src/domain/contracts/local_book_service.dart';
import 'package:flutter_legado/src/features/reader_comic/application/comic_image_actions_service.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Images extends Mock implements BookImageRepository {}

class _LocalBooks extends Mock implements LocalBookService {}

class _Platform implements ComicImageActionsPlatform {
  @override
  bool useMediaStoreDownloads = false;
  String? downloadsResult;
  Uri? chosen;
  String? failure;
  final events = <String>[];
  Uint8List? bytes;
  String? name;
  @override
  Future<String?> saveDownloads(String name, Uint8List bytes) async {
    events.add('downloads');
    this.name = name;
    this.bytes = bytes;
    return downloadsResult;
  }

  @override
  Future<Uri?> chooseFile(String name, Uint8List bytes) async {
    events.add('choose');
    this.name = name;
    this.bytes = bytes;
    if (failure == 'choose') throw StateError('选择失败');
    return chosen;
  }

  @override
  Future<String> writeDocuments(String name, Uint8List bytes) async {
    events.add('documents');
    this.name = name;
    this.bytes = bytes;
    if (failure == 'documents') throw StateError('写入失败');
    return '/documents/$name';
  }

  @override
  Future<void> shareImage(String name, Uint8List bytes) async {
    events.add('share');
    this.name = name;
    this.bytes = bytes;
    if (failure == 'share') throw StateError('分享失败');
  }

  @override
  Future<void> copyLink(String url) async {
    events.add(url);
    if (failure == 'copy') throw StateError('复制失败');
  }
}

void main() {
  late _Images images;
  late _LocalBooks local;
  late _Platform platform;
  late ComicImageActionsService service;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABh6FO1AAAAABJRU5ErkJggg==',
  );
  const page = ComicPageImage(
    bookUrl: 'book',
    url: 'https://img/a.png',
    book: Book(bookUrl: 'book', origin: 'source'),
    source: BookSource(bookSourceUrl: 'source'),
  );
  setUp(() {
    ComicImageDecodeCache.clearForTest();
    images = _Images();
    local = _LocalBooks();
    platform = _Platform();
    when(() => images.getImageCache(any(), any())).thenAnswer((_) async => png);
    service = ComicImageActionsService(
      images: images,
      localBooks: local,
      platform: platform,
      now: () => DateTime.fromMillisecondsSinceEpoch(123),
    );
  });
  tearDown(ComicImageDecodeCache.clearForTest);

  test('Android直写下载目录，不打开文件选择器', () async {
    platform.useMediaStoreDownloads = true;
    platform.downloadsResult = 'Download/legado/manga.png';
    expect(await service.save(page), '已保存: Download/legado/manga.png');
    expect(platform.events, ['downloads']);
    expect(platform.bytes, png);
    expect(platform.name, 'manga-123.png');
  });
  test('下载通道返回空时写文档目录，不切换到文件选择器', () async {
    platform.useMediaStoreDownloads = true;
    expect(await service.save(page), '已保存到文档目录: /documents/manga-123.png');
    expect(platform.events, ['downloads', 'documents']);
  });
  test('其他平台传完整图片给文件选择器，保留content URI', () async {
    platform.chosen = Uri.parse('content://downloads/image');
    expect(await service.save(page), '已保存: content://downloads/image');
    expect(platform.events, ['choose']);
    expect(platform.bytes, png);
  });
  test('文件URI转成本地路径，不重复写入插件已保存的位置', () async {
    platform.chosen = Uri.file('E:/images/comic.png', windows: true);
    expect(await service.save(page), '已保存: ${platform.chosen!.toFilePath()}');
    expect(platform.events, ['choose']);
  });
  test('取消文件选择保留文档目录回退', () async {
    expect(await service.save(page), contains('已保存到文档目录:'));
    expect(platform.events, ['choose', 'documents']);
  });
  test('保存失败返回原提示，不宣称保存成功', () async {
    platform.failure = 'documents';
    expect(await service.save(page), contains('保存图片失败:'));
    platform.failure = 'choose';
    platform.events.clear();
    expect(await service.save(page), contains('保存图片失败:'));
    expect(platform.events, ['choose']);
  });
  test('分享复用字节和后缀，成功不产生额外提示，失败返回提示', () async {
    expect(await service.share(page), null);
    expect(platform.events, ['share']);
    expect(platform.bytes, png);
    expect(platform.name, 'manga-123.png');
    platform.failure = 'share';
    expect(await service.share(page), contains('分享失败:'));
  });
  test('复制链接不解析图片，失败沿用提示', () async {
    expect(await service.copy(page), '已复制图片链接');
    expect(platform.events, [page.url]);
    verifyZeroInteractions(images);
    platform.failure = 'copy';
    expect(await service.copy(page), '复制失败');
  });
  test('内存命中不读磁盘，缺图时不调用平台', () async {
    ComicImageDecodeCache.put('source', page.url, png);
    await service.share(page);
    verifyZeroInteractions(images);
    ComicImageDecodeCache.clearForTest();
    platform.events.clear();
    when(() => images.getImageCache(any(), any()))
        .thenAnswer((_) async => null);
    when(() => images.fetchImageWithDecode(any(), any()))
        .thenAnswer((_) async => Uint8List(0));
    expect(await service.save(page), '无法获取图片数据');
    expect(await service.share(page), '无法获取图片数据');
    expect(platform.events, isEmpty);
  });
  test('CBZ使用发起时书籍路径，不走网络或磁盘缓存', () async {
    when(() => local.cbzReadPage(path: 'old.cbz', entry: 'cbz://001.png'))
        .thenAnswer((_) async => png);
    const cbz = ComicPageImage(
      bookUrl: 'old.cbz',
      url: 'cbz://001.png',
      book: Book(bookUrl: 'old.cbz'),
    );
    expect(await service.share(cbz), null);
    verify(() => local.cbzReadPage(path: 'old.cbz', entry: 'cbz://001.png'))
        .called(1);
    verifyZeroInteractions(images);
    expect(platform.bytes, png);
  });
}
