import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../domain/contracts/book_image_repository.dart';
import '../../domain/contracts/local_book_service.dart';
import '../../utils/comic_image_utils.dart';

/// FFI 图片解码结果缓存（预加载与正式渲染共用）— Reasonix + UI
class ComicImageDecodeCache {
  ComicImageDecodeCache._();

  static final Map<String, Uint8List> _cache = {};

  static String keyOf(String bookSourceUrl, String url) =>
      '$bookSourceUrl\u0000$url';

  static Uint8List? get(String bookSourceUrl, String url) =>
      _cache[keyOf(bookSourceUrl, url)];

  static void put(String bookSourceUrl, String url, Uint8List bytes) {
    // 拒绝缓存非图片字节（imageDecode 失败回退密文时勿污染缓存）— Reasonix + UI
    if (!looksLikeImageBytes(bytes)) return;
    _cache[keyOf(bookSourceUrl, url)] = bytes;
  }

  /// 预加载：调用 FFI 并写入缓存（已命中则跳过）
  static Future<void> preload({
    required BookImageRepository images,
    required String url,
    required String sourceJson,
    required String bookSourceUrl,
  }) async {
    if (_cache.containsKey(keyOf(bookSourceUrl, url))) return;
    final bytes = await images.fetchImageWithDecode(url, sourceJson);
    if (bytes.isEmpty) return;
    if (!looksLikeImageBytes(bytes)) return;
    put(bookSourceUrl, url, bytes);
  }

  /// 本地 cbz 页预加载（[cbz 批 D | 2026-10-03]）：调用
  /// [LocalBookService.cbzReadPage] 并写入缓存（已命中则跳过）；与 本地CBZ图片项
  /// 正式渲染共用同一缓存键（[cacheKey] = 活跃 bookUrl + 条目名）。
  /// — 全栈工程师 + UI
  static Future<void> preloadCbz({
    required LocalBookService localBooks,
    required String path,
    required String cacheKey,
    required String entry,
  }) async {
    if (_cache.containsKey(keyOf(cacheKey, entry))) return;
    final bytes = await localBooks.cbzReadPage(path: path, entry: entry);
    if (bytes.isEmpty) return;
    if (!looksLikeImageBytes(bytes)) return;
    put(cacheKey, entry, bytes);
  }

  /// 测试用：清空缓存
  @visibleForTesting
  static void clearForTest() => _cache.clear();
}
