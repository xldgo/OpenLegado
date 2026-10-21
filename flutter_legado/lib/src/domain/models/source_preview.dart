/// 确认页预览条目：原始 JSON 原文 + Rust 归一化后的展示字段。
///
/// [SOURCE-PARSE-FFI-20261022] 展示字段不再由 Dart 自行解释：由 Rust
/// `sourcePreviewFields`（与导入同一 `parse_source_array`）产出，保证
/// 「预览显示可导入」与「确认导入实际结果」口径一致。
/// [raw] 保留原文，仅用于展示原始 JSON 与应用导入选项。
class SourcePreview {
  /// 原始 JSON（确认导入时 jsonEncode 后直传 importBookSources）
  final Map<String, dynamic> raw;

  /// Rust 归一化后的展示字段
  final String bookSourceUrl;
  final String bookSourceName;
  final String? bookSourceComment;
  final int lastUpdateTime;

  const SourcePreview({
    required this.raw,
    required this.bookSourceUrl,
    required this.bookSourceName,
    this.bookSourceComment,
    this.lastUpdateTime = 0,
  });

  /// 用 Rust 归一化字段 + 原始 Map 构造。
  factory SourcePreview.fromNormalized(
    Map<String, dynamic> raw,
    Map<String, dynamic> normalized,
  ) {
    final time = normalized['lastUpdateTime'];
    return SourcePreview(
      raw: raw,
      bookSourceUrl: normalized['bookSourceUrl']?.toString() ?? '',
      bookSourceName: normalized['bookSourceName']?.toString() ?? '',
      bookSourceComment: normalized['bookSourceComment']?.toString(),
      lastUpdateTime: time is int ? time : 0,
    );
  }
}
