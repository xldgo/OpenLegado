import 'package:flutter/foundation.dart';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/book_image_repository.dart';

/// 字节直接跨桥接传输，缓存仍按原契约降级。— Codex + Bridge
final class RustBookImageRepository implements BookImageRepository {
  const RustBookImageRepository();
  @override
  Future<bool> saveImageCache({
    required String bookUrl,
    required String url,
    required List<int> bytes,
  }) async {
    try {
      return await bridge.saveImageCache(
        bookUrl: bookUrl,
        url: url,
        bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      );
    } catch (e) {
      debugPrint('[RustApi] saveImageCache 失败（降级在线加载）：$e');
      return false;
    }
  }

  @override
  Future<List<int>?> getImageCache(String bookUrl, String url) async {
    try {
      final bytes = await bridge.getImageCache(bookUrl: bookUrl, url: url);
      return bytes == null || bytes.isEmpty ? null : bytes;
    } catch (e) {
      debugPrint('[RustApi] getImageCache 失败（降级在线加载）：$e');
      return null;
    }
  }

  @override
  Future<Uint8List> fetchImageWithDecode(String url, String sourceJson) async =>
      bridge.fetchImageWithDecode(url: url, sourceJson: sourceJson);
}
