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

/// 搜索入口参数，不再用字符串和Map分别表示查询、单源与分组。— Codex + UI
class SearchRouteArgs {
  const SearchRouteArgs({this.query, this.sourceUrls, this.groups});
  final String? query;
  final List<String>? sourceUrls;
  final List<String>? groups;
}

class ContentSearchRouteArgs {
  const ContentSearchRouteArgs({required this.book, this.query});
  final Book book;
  final String? query;
}

class BrowserRouteArgs {
  const BrowserRouteArgs({this.url, this.html, this.title});
  final String? url;
  final String? html;
  final String? title;
}

class AutoTaskRouteArgs {
  const AutoTaskRouteArgs({this.editTaskId, this.newTask});
  final String? editTaskId;
  // 任务本身沿用既有JSON契约，不把动态字段扩散为路由参数。
  final Map<String, dynamic>? newTask;
}
