import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_legado/src/domain/contracts/book_image_repository.dart';

/// 既有图片场景共用窄仓储替身，解码回调仅属于测试数据。— Codex + UI
final class TestBookImageRepository implements BookImageRepository {
  TestBookImageRepository({
    required this.delegate,
    required this.fetch,
    this.read,
  });
  final BookImageRepository delegate;
  final Future<String> Function(String, String) fetch;
  final Future<List<int>?> Function(String, String)? read;
  @override
  Future<bool> saveImageCache({
    required String bookUrl,
    required String url,
    required List<int> bytes,
  }) => delegate.saveImageCache(bookUrl: bookUrl, url: url, bytes: bytes);
  @override
  Future<List<int>?> getImageCache(String bookUrl, String url) =>
      read?.call(bookUrl, url) ?? delegate.getImageCache(bookUrl, url);
  @override
  Future<Uint8List> fetchImageWithDecode(String url, String sourceJson) async {
    final map =
        jsonDecode(await fetch(url, sourceJson)) as Map<String, dynamic>;
    return base64Decode(map['base64'] as String);
  }
}
