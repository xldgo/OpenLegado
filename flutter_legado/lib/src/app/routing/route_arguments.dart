import '../../models/book.dart';

/// [V-B3] 悬浮窗回全屏的路由参数（app.dart 从原生交回状态组装）
class VideoScreenArgs {
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

  const VideoScreenArgs({
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
