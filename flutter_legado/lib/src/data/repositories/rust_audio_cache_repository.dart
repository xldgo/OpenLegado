import '../bridge/rust_errors.dart';

import 'package:flutter/foundation.dart';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/audio_cache_repository.dart';

/// 保留原缓存读面四项及降级语义。— Codex + Bridge
final class RustAudioCacheRepository implements AudioCacheRepository {
  const RustAudioCacheRepository();

  /// [B1 | 2026-10-04] 接通 audio_cache_query FFI（契约 §2.47）：
  /// 查询失败/FFI 异常统一降级 `false`（按未缓存处理，播放链回落在线取流，
  /// 缓存是加速器不是数据源）。
  @override
  Future<bool> audioCacheQuery({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
  }) async {
    try {
      return await rustFuture(
        () => bridge.audioCacheQuery(
          bookUrl: bookUrl,
          chapterIndex: chapterIndex,
          chapterUrl: chapterUrl,
          chapterTitle: chapterTitle,
        ),
        operation: 'audioCacheQuery',
      );
    } catch (e) {
      debugPrint('[RustApi] audioCacheQuery 失败（降级未缓存）：$e');
      return false;
    }
  }

  /// [B1 | 2026-10-04] 接通 audio_cache_list FFI（契约 §2.47）：
  /// 返回已缓存章节下标（`Int32List` 即 `List<int>`，升序去重）；
  /// 失败/FFI 异常统一降级空数组（按无缓存处理）。
  @override
  Future<List<int>> audioCacheList({required String bookUrl}) async {
    try {
      return await rustFuture(
        () => bridge.audioCacheList(bookUrl: bookUrl),
        operation: 'audioCacheList',
      );
    } catch (e) {
      debugPrint('[RustApi] audioCacheList 失败（降级空列表）：$e');
      return const <int>[];
    }
  }

  /// [B1 | 2026-10-04] 接通 audio_cache_clear_chapter FFI（契约 §2.47）：
  /// 返回实际删除文件数（含 `.complete` 标记）；失败/FFI 异常统一降级 `0`
  /// （幂等语义下与「已清理」同义）。
  @override
  Future<int> audioCacheClearChapter({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
  }) async {
    try {
      return await rustFuture(
        () => bridge.audioCacheClearChapter(
          bookUrl: bookUrl,
          chapterIndex: chapterIndex,
          chapterUrl: chapterUrl,
          chapterTitle: chapterTitle,
        ),
        operation: 'audioCacheClearChapter',
      );
    } catch (e) {
      debugPrint('[RustApi] audioCacheClearChapter 失败（降级 0）：$e');
      return 0;
    }
  }

  /// [B1 | 2026-10-04] 接通 audio_cache_clear_book FFI（契约 §2.47）：
  /// 返回实际删除文件数；失败/FFI 异常统一降级 `0`（幂等语义下与「已清理」同义）。
  @override
  Future<int> audioCacheClearBook({required String bookUrl}) async {
    try {
      return await rustFuture(
        () => bridge.audioCacheClearBook(bookUrl: bookUrl),
        operation: 'audioCacheClearBook',
      );
    } catch (e) {
      debugPrint('[RustApi] audioCacheClearBook 失败（降级 0）：$e');
      return 0;
    }
  }
}
