import 'dart:typed_data';

import '../../domain/contracts/book_image_repository.dart';

/// 原Mock图片缓存移到单一仓储，读写仍复制字节。— Codex + Bridge
class MockBookImageRepository implements BookImageRepository {
  final Map<String, List<int>> _imageCache = {};

  /// [P4-2a | 2026-09-29] mock 图片磁盘缓存写侧：存入内存 Map（模拟 Rust
  /// MD5 文件落盘），恒返回 true（对齐 Rust 侧写成功语义）。
  @override
  Future<bool> saveImageCache({
    required String bookUrl,
    required String url,
    required List<int> bytes,
  }) async {
    _imageCache['$bookUrl\u0000$url'] = List<int>.of(bytes);
    return true;
  }

  /// [P4-2a | 2026-09-29] mock 图片磁盘缓存读侧：命中返回字节副本，
  /// 未命中返回 null（对齐 Rust 侧本地优先语义）。
  @override
  Future<List<int>?> getImageCache(String bookUrl, String url) async {
    final hit = _imageCache['$bookUrl\u0000$url'];
    return hit == null ? null : List<int>.of(hit);
  }

  @override
  Future<Uint8List> fetchImageWithDecode(String url, String sourceJson) async =>
      Uint8List(0);
}
