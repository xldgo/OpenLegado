import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/audio_cache_download_service.dart';
import '../../domain/models/audio_media.dart';
import '../bridge/rust_json_decode.dart';

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
    final map = decodeRustJsonMap(
      await bridge.audioCacheDownload(
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
        chapterUrl: chapterUrl,
        chapterTitle: chapterTitle,
        playUrl: playUrl,
      ),
      'audioCacheDownload',
    );
    final status = switch (map['status']) {
      'installed' => AudioCacheDownloadStatus.installed,
      'already_cached' => AudioCacheDownloadStatus.alreadyCached,
      _ => throw const FormatException('音频缓存安装状态无效'),
    };
    if (map['path'] is! String ||
        map['sizeBytes'] is! int ||
        map['extension'] is! String) {
      throw const FormatException('音频缓存安装字段无效');
    }
    return AudioCacheDownloadResult(
      status: status,
      path: map['path'] as String,
      sizeBytes: map['sizeBytes'] as int,
      extension: map['extension'] as String,
    );
  }

  @override
  Future<bool> audioCacheCancel() => bridge.audioCacheCancel();
}
