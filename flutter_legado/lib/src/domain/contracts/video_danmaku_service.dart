import '../../models/video_danmaku_item.dart';

/// 弹幕增强能力，无记录或解析失败沿用null降级。— Codex + Bridge
abstract interface class VideoDanmakuService {
  Future<String?> getVideoDanmaku({
    required String bookUrl,
    required int chapterIndex,
  });
  Future<List<VideoDanmakuItem>?> parseVideoDanmaku({required String raw});
}
