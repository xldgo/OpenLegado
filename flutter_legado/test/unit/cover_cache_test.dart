import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/services/cover_cache.dart';

class _LocalHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousHttp = HttpOverrides.current;
  setUpAll(() => HttpOverrides.global = _LocalHttp());
  tearDownAll(() => HttpOverrides.global = previousHttp);
  late Directory parent;
  late CoverCache cache;
  late Uint8List bytes;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp('legado-cover-cache-');
    cache = CoverCache(
      directory: () async => Directory('${parent.path}/covers'),
    );
    bytes = await File('assets/images/default_book_cover.jpg').readAsBytes();
  });
  tearDown(() async {
    await cache.dispose();
    await parent.delete(recursive: true);
  });

  Future<Uint8List> load(String url, String key) async =>
      (await cache.manager.getSingleFile(url, key: key)).readAsBytes();

  Future<Uint8List> render(CachedNetworkImageProvider provider) async {
    final ready = Completer<Uint8List>();
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) async {
        try {
          final pixels = await info.image.toByteData();
          if (!ready.isCompleted) ready.complete(pixels!.buffer.asUint8List());
        } finally {
          info.dispose();
        }
      },
      onError: (Object error, StackTrace? stack) {
        if (!ready.isCompleted) ready.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    try {
      return await ready.future;
    } finally {
      stream.removeListener(listener);
      await provider.evict();
    }
  }

  test('图片组件复用专属缓存，正常释放重建后仍命中磁盘，清理后重新下载', () async {
    var requests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      request.response.headers.set(
        HttpHeaders.cacheControlHeader,
        'max-age=3600',
      );
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.add(bytes);
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final url = 'http://127.0.0.1:${server.port}/cover.jpg';
    final pixels = await render(
      CachedNetworkImageProvider(
        url,
        cacheManager: cache.manager,
        cacheKey: 'source+url',
      ),
    );
    expect(pixels, isNotEmpty);
    expect(await load(url, 'source+url'), bytes);
    expect(requests, 1);
    expect(await cache.getSize(), bytes.length);
    await cache.dispose();
    cache = CoverCache(
      directory: () async => Directory('${parent.path}/covers'),
    );
    expect(
      await render(
        CachedNetworkImageProvider(
          url,
          cacheManager: cache.manager,
          cacheKey: 'source+url',
        ),
      ),
      pixels,
    );
    expect(requests, 1);
    await cache.clear();
    expect(await cache.getSize(), 0);
    expect(await load(url, 'source+url'), bytes);
    expect(requests, 2);
  });

  test('解密文件持久化，清理不影响漫画、本地原件或全局图片缓存', () async {
    final comic = File('${parent.path}/comic/image.jpg');
    await comic.parent.create(recursive: true);
    await comic.writeAsBytes(bytes);
    final local = File('${parent.path}/local-cover.jpg');
    await local.writeAsBytes(bytes);
    await cache.writeDecoded('source+url', bytes);
    expect(await cache.readDecoded('source+url'), bytes);
    expect(await cache.getSize(), bytes.length);
    cache.rememberDecoded('key', bytes);
    final image = MemoryImage(bytes);
    final ready = Completer<void>();
    final stream = image.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      info.dispose();
      if (!ready.isCompleted) ready.complete();
    });
    stream.addListener(listener);
    await ready.future;
    stream.removeListener(listener);
    expect(PaintingBinding.instance.imageCache.containsKey(image), isTrue);
    await cache.clear();
    expect(cache.decodedCount, 0);
    expect(await cache.readDecoded('source+url'), isNull);
    expect(await cache.getSize(), 0);
    expect(await comic.readAsBytes(), bytes);
    expect(await local.readAsBytes(), bytes);
    expect(PaintingBinding.instance.imageCache.containsKey(image), isTrue);
    await image.evict();
    // 用户明确允许清理后的加载继续写入，不能把清理当成禁用缓存。
    await cache.writeDecoded('finished-later', bytes);
    expect(await cache.readDecoded('finished-later'), bytes);
  });

  test('清理已有缓存不取消正在加载的HTTP，完成后允许正常回填', () async {
    await cache.writeDecoded('existing', bytes);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final started = Completer<void>();
    final release = Completer<void>();
    server.listen((request) async {
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.headers.set(
        HttpHeaders.cacheControlHeader,
        'max-age=3600',
      );
      started.complete();
      await release.future;
      request.response.add(bytes);
      await request.response.close();
    });
    addTearDown(() async {
      if (!release.isCompleted) release.complete();
      await server.close(force: true);
    });
    final url = 'http://127.0.0.1:${server.port}/slow.jpg';
    final request = load(url, 'slow');
    await started.future;
    final clear = cache.clear();
    expect(identical(clear, cache.clear()), isTrue);
    await clear.timeout(const Duration(seconds: 5));
    expect(await cache.getSize(), 0);
    expect(await cache.readDecoded('existing'), isNull);
    release.complete();
    expect(await request, bytes);
    expect(await cache.getSize(), bytes.length);
  });

  test('保留图片库过期缓存先展示再更新的流语义', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    final refreshed = Uint8List.fromList([...bytes, 1]);
    server.listen((request) async {
      requests++;
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.headers.set(
        HttpHeaders.cacheControlHeader,
        'max-age=3600',
      );
      request.response.add(refreshed);
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final url = 'http://127.0.0.1:${server.port}/stale.jpg';
    await cache.manager.putFile(
      url,
      bytes,
      key: 'stable-key',
      maxAge: const Duration(seconds: -1),
    );
    final files = <Uint8List>[];
    await for (final event in cache.manager.getFileStream(
      url,
      key: 'stable-key',
    )) {
      if (event is FileInfo) files.add(await event.file.readAsBytes());
    }
    expect(files, [bytes, refreshed]);
    expect(requests, 1);
  });

  test('统计与清理错误向上传播，失败后可以重试', () async {
    var fails = true;
    final failing = CoverCache(
      directory: () async {
        if (fails) throw const FileSystemException('测试目录读取失败');
        return Directory('${parent.path}/retry');
      },
    );
    await expectLater(failing.getSize(), throwsA(isA<FileSystemException>()));
    await expectLater(failing.clear(), throwsA(isA<FileSystemException>()));
    fails = false;
    await failing.clear();
    expect(await failing.getSize(), 0);
    await failing.writeDecoded('key', bytes);
    expect(await failing.getSize(), bytes.length);
    await failing.dispose();
    await expectLater(failing.getSize(), throwsStateError);
  });
}
