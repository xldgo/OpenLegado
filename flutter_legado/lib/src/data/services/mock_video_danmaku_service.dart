import '../../domain/contracts/video_danmaku_service.dart';
import '../../models/video_danmaku_item.dart';

/// 沿用无弹幕占位，不在Dart复制Rust的XML解析器。— Codex + Bridge
class MockVideoDanmakuService implements VideoDanmakuService {
  const MockVideoDanmakuService();

  /// mock 查询：默认无弹幕 → null（对齐 Rust 侧「无记录降级 null」语义）
  @override
  Future<String?> getVideoDanmaku({
    required String bookUrl,
    required int chapterIndex,
  }) async => null;

  /// mock 解析：返回 null（无 Rust 纯函数，UI 降级为无弹幕；
  /// 弹幕渲染层由 widget 测试注入假 API 验证，不在 mock 复制业务逻辑）
  @override
  Future<List<VideoDanmakuItem>?> parseVideoDanmaku({
    required String raw,
  }) async => null;
}
