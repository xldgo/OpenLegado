import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../bridge/media_dto_mapping.dart';
import '../../domain/contracts/tts_cache_repository.dart';

/// Rust 统一拥有缓存目录与活动文件保护。— Codex + Bridge
final class RustTtsCacheRepository implements TtsCacheRepository {
  @override
  bool get supportsAudioFiles => true;
  const RustTtsCacheRepository();
  @override
  Future<void> record(String path, TtsCacheContext context) => rustFuture(
    () => bridge.ttsCacheRecord(
      audioPath: path,
      context: ttsCacheContextToDto(context),
    ),
    operation: 'ttsCacheRecord',
  );
  @override
  Future<List<TtsCacheEntry>> list() async => (await rustFuture(
    () => bridge.ttsCacheList(),
    operation: 'ttsCacheList',
  )).map(ttsCacheEntryFromDto).toList(growable: false);

  @override
  Future<TtsCacheClearResult> clear({
    String? name,
    int? beforeTimestampMs,
    String? keepBookUrl,
    int? keepChapterIndex,
  }) async {
    return ttsCacheClearResultFromDto(
      await rustFuture(
        () => bridge.ttsCacheClear(
          name: name,
          beforeTimestampMs: beforeTimestampMs == null
              ? null
              : BigInt.from(beforeTimestampMs),
          keepBookUrl: keepBookUrl,
          keepChapterIndex: keepChapterIndex,
        ),
        operation: 'ttsCacheClear',
      ),
    );
  }
}
