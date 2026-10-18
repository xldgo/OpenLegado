import '../../models/book.dart';

/// 路由参数只依赖领域模型，不导入目标页面。— Codex + UI
/// 书籍信息页路由参数：Book 对象 + 是否进入即自动开读
///
/// [A4 对齐 B | 2026-09-21 裁决] 书架未读书单击 = 详情页 + 立即自动开读
///（等价重构版 `BookInfoPage(openReaderImmediately: true)`）。长按封面/书名
/// 及其余入口仍直接传 [Book]（走既有分支，行为不变）。
class BookInfoArgs {
  /// 书籍对象
  final Book book;

  /// 目录就绪后自动跳转阅读器（默认 false）
  final bool openReaderImmediately;

  const BookInfoArgs({required this.book, this.openReaderImmediately = false});
}

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
