import 'dart:convert';

// 共享规则模型保留既有持久化字段。— Codex + Bridge
/// 高亮规则类型化模型（字段名与 Rust HighlightRule serde 契约一致）
///
/// 对标 Android 原版 data class HighlightRule：
/// 保留样式、作用范围、排序和超时，不依赖页面或Provider。
final class HighlightRule {
  const HighlightRule({
    this.id = 0,
    this.name = '',
    this.pattern = '',
    this.isRegex = false,
    this.applyToTitle = false,
    this.scope,
    this.isEnabled = true,
    this.style = '',
    this.sortOrder = 0,
    this.timeoutMillisecond = 3000,
  });

  final int id;
  final String name;
  final String pattern;
  final bool isRegex;
  final bool applyToTitle;
  final String? scope;
  final bool isEnabled;
  final String style;
  final int sortOrder;
  final int timeoutMillisecond;

  /// 缺省字段沿用Rust默认值，类型错误由仓储报告。
  factory HighlightRule.fromJson(Map<String, dynamic> json) {
    return HighlightRule(
      id: json['id'] as int? ?? 0,
      name: (json['name'] as String?) ?? '',
      pattern: (json['pattern'] as String?) ?? '',
      isRegex: (json['isRegex'] as bool?) ?? false,
      applyToTitle: (json['applyToTitle'] as bool?) ?? false,
      scope: json['scope'] as String?,
      isEnabled: (json['isEnabled'] as bool?) ?? true,
      style: (json['style'] as String?) ?? '',
      sortOrder: json['sortOrder'] as int? ?? 0,
      timeoutMillisecond: json['timeoutMillisecond'] as int? ?? 3000,
    );
  }

  /// 序列化为 Rust 侧契约 JSON（保存用）
  Map<String, dynamic> toJson() => {
    if (id > 0) 'id': id,
    'name': name,
    'pattern': pattern,
    'isRegex': isRegex,
    'applyToTitle': applyToTitle,
    'scope': scope,
    'isEnabled': isEnabled,
    'style': style,
    'sortOrder': sortOrder,
    'timeoutMillisecond': timeoutMillisecond,
  };

  /// 规则显示名（对标 Kotlin getDisplayName：name 为空时回退 pattern）
  String get displayName => name.isNotEmpty ? name : pattern;

  /// 从 style JSON 解析 textColor（ARGB int），非法/缺失返回 null
  int? get styleTextColor {
    if (style.isEmpty) return null;
    try {
      final decoded = jsonDecode(style);
      if (decoded is Map<String, dynamic>) {
        final v = decoded['textColor'];
        if (v is num) return v.toInt();
      }
    } catch (_) {
      // 非法 style 静默回退默认色（UI 层 debugPrint 留痕由调用方决定）
    }
    return null;
  }

  HighlightRule copyWith({
    int? id,
    String? name,
    String? pattern,
    bool? isRegex,
    bool? applyToTitle,
    String? scope,
    bool? isEnabled,
    String? style,
    int? sortOrder,
    int? timeoutMillisecond,
  }) {
    return HighlightRule(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      isRegex: isRegex ?? this.isRegex,
      applyToTitle: applyToTitle ?? this.applyToTitle,
      scope: scope ?? this.scope,
      isEnabled: isEnabled ?? this.isEnabled,
      style: style ?? this.style,
      sortOrder: sortOrder ?? this.sortOrder,
      timeoutMillisecond: timeoutMillisecond ?? this.timeoutMillisecond,
    );
  }
}
