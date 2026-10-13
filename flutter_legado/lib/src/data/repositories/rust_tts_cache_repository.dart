import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/tts_cache_repository.dart';

/// Rust 统一拥有缓存目录与活动文件保护。— Codex + Bridge
final class RustTtsCacheRepository implements TtsCacheRepository {
  @override
  bool get supportsAudioFiles => true;
  const RustTtsCacheRepository();
  @override
  Future<void> record(String path, TtsCacheContext context) =>
      bridge.ttsCacheRecord(
        audioPath: path,
        contextJson: jsonEncode(context.toJson()),
      );
  @override
  Future<List<TtsCacheEntry>> list() async {
    final values = jsonDecode(await bridge.ttsCacheList()) as List;
    return values
        .map((v) {
          final j = Map<String, dynamic>.from(v as Map);
          return TtsCacheEntry(
            name: j['name'] as String,
            sizeBytes: j['sizeBytes'] as int,
            modifiedAtMs: j['modifiedAtMs'] as int,
            protected: j['protected'] as bool,
            contexts: (j['contexts'] as List)
                .map(
                  (c) => TtsCacheContext.fromJson(
                    Map<String, dynamic>.from(c as Map),
                  ),
                )
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<TtsCacheClearResult> clear({
    String? name,
    int? beforeTimestampMs,
    String? keepBookUrl,
    int? keepChapterIndex,
  }) async {
    final j = jsonDecode(
      await bridge.ttsCacheClear(
        name: name,
        beforeTimestampMs: beforeTimestampMs == null
            ? null
            : BigInt.from(beforeTimestampMs),
        keepBookUrl: keepBookUrl,
        keepChapterIndex: keepChapterIndex,
      ),
    ) as Map<String, dynamic>;
    return TtsCacheClearResult(
      removedFiles: j['removedFiles'] as int,
      removedBytes: j['removedBytes'] as int,
      skippedFiles: j['skippedFiles'] as int,
    );
  }
}
