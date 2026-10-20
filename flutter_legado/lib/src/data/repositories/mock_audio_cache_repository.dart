import '../../domain/contracts/audio_cache_repository.dart';

/// 下载与读面共用的Mock缓存事实。— Codex + Bridge
final class MockAudioCacheStore {
  final Map<String, Set<int>> indexes = {};
  final Map<String, Map<int, String>> playUrls = {};
}

final class MockAudioCacheRepository implements AudioCacheRepository {
  MockAudioCacheRepository({required this._store});
  final MockAudioCacheStore _store;

  /// [B1 | 2026-10-04] mock 音频缓存查询：按内存态判定（无缓存 → false，
  /// 播放链回落在线取流）。键以章节下标简化（真实键规则在 Rust 侧）。
  @override
  Future<bool> audioCacheQuery({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
  }) async => _store.indexes[bookUrl]?.contains(chapterIndex) ?? false;

  /// [B1 | 2026-10-04] mock 音频缓存列举：内存态已缓存章节下标升序。
  @override
  Future<List<int>> audioCacheList({required String bookUrl}) async =>
      (_store.indexes[bookUrl]?.toList() ?? <int>[])..sort();

  /// [B1 | 2026-10-04] mock 音频单章清理：返回删除数据文件数（0/1，幂等）。
  @override
  Future<int> audioCacheClearChapter({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
  }) async {
    final indexes = _store.indexes[bookUrl];
    final removed = indexes?.remove(chapterIndex) ?? false;
    _store.playUrls[bookUrl]?.remove(chapterIndex);
    return removed ? 1 : 0;
  }

  /// [B1 | 2026-10-04] mock 音频整书清理：返回删除数据文件数（幂等）。
  @override
  Future<int> audioCacheClearBook({required String bookUrl}) async {
    final count = _store.indexes.remove(bookUrl)?.length ?? 0;
    _store.playUrls.remove(bookUrl);
    return count;
  }
}
