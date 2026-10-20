import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/audio_cache_download_service.dart';
import '../../domain/models/audio_media.dart';
import '../../bridge/media_dto.dart' as dto;

/// 下载与取消直接使用既有Rust任务，不吞掉写入失败。— Codex + Bridge
final class RustAudioCacheDownloadService implements AudioCacheDownloadService {
  const RustAudioCacheDownloadService();
  @override
  Future<AudioCacheDownloadResult> audioCacheDownload({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
    required String playUrl,
  }) async {
    final value = await rustFuture(
      () => bridge.audioCacheDownload(
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
        chapterUrl: chapterUrl,
        chapterTitle: chapterTitle,
        playUrl: playUrl,
      ),
      operation: 'audioCacheDownload',
    );
    return AudioCacheDownloadResult(
      status: switch (value.status) {
        dto.AudioCacheDownloadStatusDto.installed =>
          AudioCacheDownloadStatus.installed,
        dto.AudioCacheDownloadStatusDto.alreadyCached =>
          AudioCacheDownloadStatus.alreadyCached,
      },
      path: value.path,
      sizeBytes: value.sizeBytes.toInt(),
      extension: value.extension_,
    );
  }

  @override
  Future<bool> audioCacheCancel() => rustFuture(
    () => bridge.audioCacheCancel(),
    operation: 'audioCacheCancel',
  );
}
