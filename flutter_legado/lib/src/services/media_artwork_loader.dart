import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import 'book_api.dart';
import 'cover_decode_loader.dart';

/// 系统媒体封面复用现有图片来源，只缓存有界缩略图。— Codex + UI
class MediaArtworkLoader {
  MediaArtworkLoader({required this.api});
  final BookApi api;
  static const maxDimension = 384;
  static const maxBytes = 1024 * 1024;
  static const defaultAsset = 'assets/images/default_book_cover.jpg';
  final Map<String, Uint8List> _cache = {};
  final _loading = <String, Future<Uint8List?>>{};

  static String coverUrl(Book? book) {
    final custom = book?.customCoverUrl?.trim() ?? '';
    return custom.isNotEmpty ? custom : book?.coverUrl?.trim() ?? '';
  }

  Future<Uint8List?> load(Book? book, {bool hidden = false}) {
    final url = hidden ? '' : coverUrl(book);
    final key = jsonEncode([
      url,
      hidden ? '' : book?.origin ?? '',
      CoverDecodeLoader.sourceRevision,
    ]);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return Future.value(hit);
    }
    return _loading.putIfAbsent(key, () async {
      try {
        Uint8List? bytes;
        try {
          final provider = await _source(book, url);
          bytes = await thumbnail(provider);
        } catch (_) {
          // 网络、解密或图片损坏均回退默认封面，不影响播放。
        }
        bytes ??= await thumbnail(const AssetImage(defaultAsset));
        if (bytes != null) {
          _cache[key] = bytes;
          while (_cache.length > 8) {
            _cache.remove(_cache.keys.first);
          }
        }
        return bytes;
      } catch (_) {
        return null;
      } finally {
        _loading.remove(key);
      }
    });
  }

  Future<ImageProvider> _source(Book? book, String url) async {
    if (url.isEmpty) return const AssetImage(defaultAsset);
    final uri = Uri.tryParse(url);
    if (uri?.scheme == 'file') return FileImage(File.fromUri(uri!));
    // 复合URL尾部是原始JSON，不能先要求整串都能解析成普通URI。
    final lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return FileImage(File(url));
    }
    final origin = book?.origin ?? '';
    final patched = await CoverDecodeLoader.resolvePatchedSourceJson(
      api: api,
      sourceOrigin: origin,
    );
    final cached = CoverDecodeLoader.getCached(
      origin,
      url,
      patchedSourceJson: patched ?? '',
    );
    if (cached != null) return MemoryImage(cached);
    if (CoverDecodeLoader.needsFfiDecode(
      coverUrl: url,
      patchedSourceJson: patched,
    )) {
      final bytes = await CoverDecodeLoader.load(
        api: api,
        coverUrl: url,
        patchedSourceJson: patched ?? '',
        originOrEmpty: origin,
        isCancelled: () => false,
      );
      if (bytes == null) throw StateError('媒体封面解密失败');
      return MemoryImage(bytes);
    }
    return CachedNetworkImageProvider(
      url,
      cacheKey: CoverDecodeLoader.cacheKey(
        origin,
        url,
        patchedSourceJson: patched ?? '',
      ),
    );
  }

  /// 在解码阶段限制尺寸，保持比例，不将原始大图传入平台通道。
  static Future<Uint8List?> thumbnail(ImageProvider provider) async {
    final stream = ResizeImage(
      provider,
      width: maxDimension,
      height: maxDimension,
      policy: ResizeImagePolicy.fit,
      allowUpscaling: false,
    ).resolve(ImageConfiguration.empty);
    final result = Completer<ImageInfo>();
    final listener = ImageStreamListener(
      (info, _) {
        if (!result.isCompleted) {
          result.complete(info);
        } else {
          info.dispose();
        }
      },
      onError: (Object error, StackTrace? stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    ImageInfo? info;
    try {
      info = await result.future.timeout(const Duration(seconds: 10));
      final data = await info.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || data.lengthInBytes > maxBytes) return null;
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      stream.removeListener(listener);
      info?.dispose();
    }
  }
}
