import 'dart:typed_data';

/// 图片字节与磁盘缓存的统一访问；缓存失败允许回退在线。— Codex + Bridge
abstract interface class BookImageRepository {
  Future<bool> saveImageCache({
    required String bookUrl,
    required String url,
    required List<int> bytes,
  });
  Future<List<int>?> getImageCache(String bookUrl, String url);
  Future<Uint8List> fetchImageWithDecode(String url, String sourceJson);
}
