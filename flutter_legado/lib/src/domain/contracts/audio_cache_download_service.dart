import '../models/audio_media.dart';

/// 下载/取消复用Rust进程级任务，不改变取消代数和调用顺序。— Codex + Bridge
abstract interface class AudioCacheDownloadService {
  Future<AudioCacheDownloadResult> audioCacheDownload({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
    required String playUrl,
  });
  Future<bool> audioCacheCancel();
}
