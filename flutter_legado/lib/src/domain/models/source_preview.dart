/// 确认页预览条目：保留原始 JSON Map，仅轻量提取展示字段
///
/// 第三方书源常带不稳定类型字段（如 `"lastUpdateTime": "1785432524399"`
/// 字符串数字、`"isVolume": "false"` 字符串布尔），严格的 freezed
/// `BookSource.fromJson` 会抛 TypeError 导致整批书源被丢弃。
/// 因此预览阶段不做类型化解析：展示字段用 `?.toString()` 宽容读取，
/// 原始 [raw] Map 在确认导入时 jsonEncode 直传 Rust 侧宽松反序列化兜底。
class SourcePreview {
  /// 原始 JSON（确认导入时 jsonEncode 后直传 importBookSources）
  final Map<String, dynamic> raw;

  /// 展示字段（轻量提取，仅供确认页列表显示与状态判定）
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

  /// 从原始 JSON Map 轻量构造预览条目（不做严格类型化解析）
  factory SourcePreview.fromRaw(Map<String, dynamic> raw) {
    return SourcePreview(
      raw: raw,
      bookSourceUrl: raw['bookSourceUrl']?.toString() ?? '',
      bookSourceName: raw['bookSourceName']?.toString() ?? '',
      bookSourceComment: raw['bookSourceComment']?.toString(),
      lastUpdateTime: _parseIntLenient(raw['lastUpdateTime']),
    );
  }
}

/// 宽容解析整数：支持数字与字符串数字（第三方书源 lastUpdateTime
/// 常为字符串），无法解析时返回 0
int _parseIntLenient(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}
