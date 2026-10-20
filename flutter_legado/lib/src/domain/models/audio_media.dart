/// 音频取址和缓存安装结果，不携带播放器状态。— Codex + Bridge
final class AudioChapterMedia {
  const AudioChapterMedia({
    required this.mediaUrl,
    this.chapterIndex = 0,
    this.title = '',
    this.url = '',
    this.resourceUrl,
    this.isVolume = false,
    this.fromCache = false,
    this.lyric,
    this.sourceUrl = '',
  });
  final int chapterIndex;
  final String title;
  final String mediaUrl;
  final String url;
  final String? resourceUrl;
  final bool isVolume;
  final bool fromCache;
  final String? lyric;
  final String sourceUrl;

  factory AudioChapterMedia.fromJson(Map<String, dynamic> map) =>
      AudioChapterMedia(
        mediaUrl: map['mediaUrl'] as String,
        chapterIndex: map['chapterIndex'] as int? ?? 0,
        title: map['title'] as String? ?? '',
        url: map['url'] as String? ?? '',
        resourceUrl: map['resourceUrl'] as String?,
        isVolume: map['isVolume'] as bool? ?? false,
        fromCache: map['fromCache'] as bool? ?? false,
        lyric: map['lyric'] as String?,
        sourceUrl: map['sourceUrl'] as String? ?? '',
      );
}

enum AudioCacheDownloadStatus { installed, alreadyCached }

final class AudioCacheDownloadResult {
  const AudioCacheDownloadResult({
    required this.status,
    required this.path,
    required this.sizeBytes,
    required this.extension,
  });
  final AudioCacheDownloadStatus status;
  final String path;
  final int sizeBytes;
  final String extension;
}
