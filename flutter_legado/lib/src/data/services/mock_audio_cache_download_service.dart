import '../../domain/contracts/audio_cache_download_service.dart';
import '../../domain/models/audio_media.dart';
import '../repositories/mock_audio_cache_repository.dart';

/// 复用同一Mock状态，保留幂等安装和无在途取消。— Codex + Bridge
final class MockAudioCacheDownloadService implements AudioCacheDownloadService {
  MockAudioCacheDownloadService({required this._store});
  final MockAudioCacheStore _store;

  /// [B2 | 2026-10-03] mock 单章预下载：内存态记录（已缓存 → already_cached；
  /// 否则 installed），JSON 形状与 Rust 侧一致。mock 无网络/无字节。
  @override
  Future<AudioCacheDownloadResult> audioCacheDownload({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
    required String playUrl,
  }) async {
    final indexes = _store.indexes.putIfAbsent(bookUrl, () => <int>{});
    final playUrls = _store.playUrls.putIfAbsent(
      bookUrl,
      () => <int, String>{},
    );
    if (indexes.contains(chapterIndex)) {
      return AudioCacheDownloadResult(
        status: AudioCacheDownloadStatus.alreadyCached,
        path: '',
        sizeBytes: 0,
        extension: _mockExtension(playUrl),
      );
    }
    indexes.add(chapterIndex);
    playUrls[chapterIndex] = playUrl;
    return AudioCacheDownloadResult(
      status: AudioCacheDownloadStatus.installed,
      path: '',
      sizeBytes: 0,
      extension: _mockExtension(playUrl),
    );
  }

  /// [B2 | 2026-10-03] mock 取消：无在途下载 → false（同步语义等价）。
  @override
  Future<bool> audioCacheCancel() async => false;

  /// mock 扩展名探测（对齐原版三级探测的 URL 后缀分支，仅用于 JSON 形状）
  static String _mockExtension(String playUrl) {
    final path = playUrl.split('?').first.split('#').first;
    final dot = path.lastIndexOf('.');
    if (dot >= 0) {
      final ext = path.substring(dot + 1).toLowerCase();
      const whitelist = {
        'mp3',
        'm4a',
        'm4b',
        'aac',
        'ogg',
        'oga',
        'opus',
        'wav',
        'flac',
        'webm',
        'amr',
        '3gp',
      };
      if (whitelist.contains(ext)) return ext;
    }
    return 'audio';
  }
}
