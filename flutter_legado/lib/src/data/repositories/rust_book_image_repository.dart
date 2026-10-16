import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/book_image_repository.dart';
import '../bridge/rust_json_decode.dart';

/// 图像传输编码在数据层消化，缓存仍按原契约降级。— Codex + Bridge
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
        bytesBase64: base64Encode(bytes),
      );
    } catch (e) {
      debugPrint('[RustApi] saveImageCache 失败（降级在线加载）：$e');
      return false;
    }
  }

  /// [P4-2a | 2026-09-29] 接通 get_image_cache FFI（契约 §2.46 image_cache）：
  /// 命中 → base64 解码返回图片字节；未命中/读失败/FFI 异常统一降级
  /// `null`（调用方回落网络加载，对齐原版 mangaImagePath 本地优先语义）。
  @override
  Future<List<int>?> getImageCache(String bookUrl, String url) async {
    try {
      final b64 = await bridge.getImageCache(bookUrl: bookUrl, url: url);
      if (b64 == null || b64.isEmpty) return null;
      return base64Decode(b64);
    } catch (e) {
      debugPrint('[RustApi] getImageCache 失败（降级在线加载）：$e');
      return null;
    }
  }

  @override
  Future<Uint8List> fetchImageWithDecode(String url, String sourceJson) async {
    final map = decodeRustJsonMap(
      await bridge.fetchImageWithDecode(url: url, sourceJson: sourceJson),
      'fetchImageWithDecode',
    );
    if (map['base64'] is! String || map['len'] is! int) {
      throw const FormatException('图片解码响应无效');
    }
    final bytes = base64Decode(map['base64'] as String);
    if (bytes.length != map['len']) {
      throw const FormatException('图片字节长度不一致');
    }
    return bytes;
  }
}
