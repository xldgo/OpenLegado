// rust_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件保留章节购买与书源回调；发现及在线查询已由独立服务负责。
// RustApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 解码辅助来自 RustApiDecode（on 约束），同一 library 内私有成员可直接访问。
part of 'rust_api.dart';

mixin RustApiDiscoveryCache on RustApiDecode implements BookApi {
  // ========== 章节购买 ==========

  /// 执行章节购买动作（契约 §2.43.2，对照 Kotlin ReadBookActivity.payAction）
  ///
  /// 解析 Rust 返回的 `{"kind": ..., "value": ...}` JSON 为元组；
  /// kind 缺失时视为 none，value 缺失时视为空串。
  /// [UI-fix v2.0.3 | 2026-08-08] — QoderCN
  @override
  Future<({String kind, String value})> chapterPayAction({
    required String bookUrl,
    required int chapterIndex,
  }) async {
    final json = await bridge.chapterPayAction(
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
    );
    final map = _decodeMap(json, 'chapterPayAction');
    return (
      kind: (map['kind'] ?? 'none').toString(),
      value: (map['value'] ?? '').toString(),
    );
  }

  @override
  Future<Map<String, dynamic>> sourceCallBackBtn({
    required String event,
    required String bookUrl,
    int? chapterIndex,
    String? result,
    int bookType = 0,
  }) async {
    final json = await bridge.sourceCallBackBtn(
      event: event,
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
      result: result,
      bookType: bookType,
    );
    return _decodeMap(json, 'sourceCallBackBtn');
  }
}
