import '../../../models/book.dart';

/// 视频会话输入，不依赖Widget或路由。— Codex + UI
class VideoPlaybackRequest {
  final String videoUrl;
  final String title;
  final Book? book;
  final String? presetUrl;
  final Map<String, String> presetHeaders;
  final String? presetMpdPath;
  final int initialResumeMs;
  final int? initialChapterIndex;
  final double initialSpeed;
  final bool initialPlaying;

  const VideoPlaybackRequest({
    this.videoUrl = '',
    this.title = '视频播放',
    this.book,
    this.presetUrl,
    this.presetHeaders = const {},
    this.presetMpdPath,
    this.initialResumeMs = 0,
    this.initialChapterIndex,
    this.initialSpeed = 1.0,
    this.initialPlaying = true,
  });
}
