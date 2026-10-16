import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/video_danmaku_service.dart';
import '../../models/video_danmaku_item.dart';

/// 查询与XML解析仍委托Rust，失败沿用增强层降级。— Codex + Bridge
final class RustVideoDanmakuService implements VideoDanmakuService {
  const RustVideoDanmakuService();

  /// 查询某章弹幕数据（只读、幂等；降级路径返回 null）
  ///
  /// 直通 FFI：Rust 侧已完成「章节 variable inline → 大数据文件」归一
  /// （`DanmakuSource` 三态），Dart 侧无需解析，原样透传 `String?`。
  /// FFI 不可用/调用异常统一降级 `null`（弹幕是增强层不是数据源，
  /// 对齐 §2.46 口径）；Rust 侧本身也已对内部失败降级 `null`。
  @override
  Future<String?> getVideoDanmaku({
    required String bookUrl,
    required int chapterIndex,
  }) async {
    try {
      return await bridge.getVideoDanmaku(
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
      );
    } catch (e) {
      debugPrint('[RustApi] getVideoDanmaku 失败（降级 null）：$e');
      return null;
    }
  }

  // ========== 视频弹幕解析（契约 §2.50，V-B2） ==========

  /// 解析 B 站弹幕 XML（Rust 纯函数；降级路径返回 null）
  ///
  /// 直通 FFI 后仅做 JSON 解码 + 模型映射，不含 XML 语义逻辑（p 属性、
  /// 类型过滤、实体解码均在 Rust）。FFI 不可用 / 返回 null / JSON 形状
  /// 异常统一降级 `null`（弹幕是增强层不是数据源，对齐 §2.50 口径）。
  @override
  Future<List<VideoDanmakuItem>?> parseVideoDanmaku({
    required String raw,
  }) async {
    try {
      final json = await bridge.parseVideoDanmaku(raw: raw);
      if (json == null) return null;
      final decoded = jsonDecode(json);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(VideoDanmakuItem.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[RustApi] parseVideoDanmaku 失败（降级 null）：$e');
      return null;
    }
  }
}
