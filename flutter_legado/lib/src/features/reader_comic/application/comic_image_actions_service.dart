import 'dart:convert';
import 'dart:typed_data';

import '../../../data/services/comic_image_decode_cache.dart';
import '../../../domain/contracts/book_image_repository.dart';
import '../../../domain/contracts/local_book_service.dart';
import '../../../models/models.dart';
import 'manga_page_image_resolver.dart';

/// 在点击时固定图片所属书籍与书源，不随稍后的切章变化。— Codex + UI
class ComicPageImage {
  const ComicPageImage({
    required this.bookUrl,
    required this.url,
    this.book,
    this.source,
  });
  final String bookUrl;
  final String url;
  final Book? book;
  final BookSource? source;
}

/// 平台IO端口；应用编排不依赖文件选择器、分享插件或页面。— Codex + UI
abstract interface class ComicImageActionsPlatform {
  bool get useMediaStoreDownloads;
  Future<String?> saveDownloads(String name, Uint8List bytes);
  Future<Uri?> chooseFile(String name, Uint8List bytes);
  Future<String> writeDocuments(String name, Uint8List bytes);
  Future<void> shareImage(String name, Uint8List bytes);
  Future<void> copyLink(String url);
}

/// 复用原字节来源及平台保存策略，结果文案交由页面显示。— Codex + UI
class ComicImageActionsService {
  ComicImageActionsService({
    required this._images,
    required this._localBooks,
    required this._platform,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final BookImageRepository _images;
  final LocalBookService _localBooks;
  final ComicImageActionsPlatform _platform;
  final DateTime Function() _now;

  Future<MangaPageImageBytes?> _resolve(ComicPageImage page) {
    final cbz = page.url.startsWith('cbz://');
    return resolveMangaPageImageBytes(
      images: _images,
      localBooks: _localBooks,
      bookUrl: page.bookUrl,
      url: page.url,
      sourceJson: page.source == null
          ? null
          : jsonEncode(page.source!.toJson()),
      cbzPath: cbz ? page.book?.bookUrl : null,
      memoryCached: ComicImageDecodeCache.get(
        cbz ? page.bookUrl : (page.book?.origin ?? ''),
        page.url,
      ),
    );
  }

  String _name(MangaPageImageBytes data) =>
      'manga-${_now().millisecondsSinceEpoch}${data.suffix}';

  Future<String> save(ComicPageImage page) async {
    final data = await _resolve(page);
    if (data == null) return '无法获取图片数据';
    final name = _name(data);
    try {
      if (_platform.useMediaStoreDownloads) {
        final saved = await _platform.saveDownloads(name, data.bytes);
        if (saved != null) return '已保存: $saved';
      } else {
        final path = await _platform.chooseFile(name, data.bytes);
        if (path != null) {
          return '已保存: ${path.scheme == 'file' ? path.toFilePath() : path.toString()}';
        }
      }
      // 保留取消文件选择、通道失败时回退文档目录的既有行为。
      final path = await _platform.writeDocuments(name, data.bytes);
      return '已保存到文档目录: $path';
    } catch (error) {
      return '保存图片失败: $error';
    }
  }

  Future<String?> share(ComicPageImage page) async {
    final data = await _resolve(page);
    if (data == null) return '无法获取图片数据';
    try {
      await _platform.shareImage(_name(data), data.bytes);
      return null;
    } catch (error) {
      return '分享失败: $error';
    }
  }

  Future<String> copy(ComicPageImage page) async {
    try {
      await _platform.copyLink(page.url);
      return '已复制图片链接';
    } catch (_) {
      return '复制失败';
    }
  }
}
