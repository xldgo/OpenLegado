import 'package:material_ui/material_ui.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../models/models.dart';
import '../../../domain/models/page_turn_mode.dart';

export '../../../domain/models/page_turn_mode.dart';

part 'reader_state.freezed.dart';

/// 阅读背景预设
class ReaderBackground {
  static const white = Color(0xFFFFFFFF);
  static const green = Color(0xFFCCEBCC);
  static const brown = Color(0xFFD4A574);
  static const dark = Color(0xFF1A1A1A);
  static const eyeProtect = Color(0xFFE8E0C8);

  static const List<Color> presets = [white, green, brown, eyeProtect, dark];
  static const List<String> labels = ['白色', '绿色', '棕色', '护眼', '夜间'];
}

/// 阅读背景解析：自定义色优先，其次为预设，未选择时跟随主题明暗。
/// 默认深色与夜间预设在软件深色模式下共同遵循 [themeAmoled]。
/// 浅色预设和自定义色不受纯黑开关影响，越界索引按未设置处理。
Color resolveReaderBackground({
  required Brightness themeBrightness,
  bool themeAmoled = false,
  int? storedBgIndex,
  Color? customBgColor,
}) {
  if (customBgColor != null) return customBgColor;
  if (storedBgIndex != null &&
      storedBgIndex >= 0 &&
      storedBgIndex < ReaderBackground.presets.length) {
    final preset = ReaderBackground.presets[storedBgIndex];
    if (preset != ReaderBackground.dark) return preset;
    return themeBrightness == Brightness.dark && themeAmoled
        ? const Color(0xFF000000)
        : preset;
  }
  return themeBrightness == Brightness.dark
      ? (themeAmoled ? const Color(0xFF000000) : ReaderBackground.dark)
      : ReaderBackground.white;
}

/// [M1 深色态默认修复] 主题模式 → 有效亮度（system 取平台亮度）
Brightness themeBrightnessFor(ThemeMode mode, Brightness platformBrightness) {
  switch (mode) {
    case ThemeMode.light:
      return Brightness.light;
    case ThemeMode.dark:
      return Brightness.dark;
    case ThemeMode.system:
      return platformBrightness;
  }
}

/// 阅读器 UI 状态（immutable）
///
/// 职责边界说明（对齐 UI_RESTRUCTURE_PLAN.md §3.2 铁律）：
/// - [currentBook] / [chapters] / [chapterContent]：Rust API 返回的纯数据
/// - [isLoading] / [error]：API 调用状态
/// - [showControls]：工具栏显隐（UI 交互状态）
/// - [fontSize] / [lineHeight] / [backgroundColor] / [pageTurnMode]：阅读设置
///
/// 文本解析/净化/替换全部由 Rust 在 getChapterContent 内部完成，
/// UI 侧拿到的 [chapterContent] 已是最终渲染文本。
@freezed
abstract class ReaderState with _$ReaderState {
  const factory ReaderState({
    /// 当前阅读的书籍
    Book? currentBook,

    /// 章节目录列表（Rust 返回，已排序）
    @Default([]) List<BookChapter> chapters,

    /// 当前章节索引
    @Default(0) int currentChapterIndex,

    /// 当前章节内阅读位置
    @Default(0) int currentChapterPos,

    /// 当前章节正文（Rust 已完成净化/替换的最终文本）
    @Default('') String chapterContent,

    /// 是否正在加载
    @Default(false) bool isLoading,

    /// 错误信息（null 表示无错误）
    String? error,

    /// 工具栏是否显示
    @Default(false) bool showControls,

    // ===== 阅读设置 =====

    /// 字体大小
    /// [C2 R1] 默认字号对齐参考（参考 ~20-22sp/行 ~14 字；原版 ReadBookConfig
    /// textSize=20sp）：18.0 → 20.0
    @Default(20.0) double fontSize,

    /// 行高倍数
    /// [C2 R2] 默认行距对齐参考（参考 ~1.7，原版 lineSpacingExtra=12）：1.6 → 1.7
    @Default(1.7) double lineHeight,

    /// 背景色
    @Default(ReaderBackground.white) Color backgroundColor,

    /// 当前阅读样式的文字色；空值根据背景亮度自动选择。
    Color? foregroundColor,

    /// 阅读模式的有效亮度，与应用主题和背景颜色分别表达。
    Brightness? readingBrightness,

    /// 翻页模式
    @Default(PageTurnMode.cover) PageTurnMode pageTurnMode,

    // ===== 跨章节连续分页 =====

    /// 全局页索引（跨章节连续编号，从 0 开始）
    @Default(0) int globalPageIndex,

    /// 全局总页数（所有章节页数之和）
    @Default(0) int totalPages,
  }) = _ReaderState;
}

/// 阅读器状态派生属性扩展
extension ReaderStateDerived on ReaderState {
  /// 是否存在上一章
  bool get hasPreviousChapter => currentChapterIndex > 0;

  /// 是否存在下一章
  bool get hasNextChapter => currentChapterIndex < chapters.length - 1;

  /// 当前章节对象
  BookChapter? get currentChapter {
    if (chapters.isEmpty) return null;
    if (currentChapterIndex >= chapters.length) return null;
    return chapters[currentChapterIndex];
  }

  /// 阅读进度（0.0 ~ 1.0）
  double get readingProgress {
    if (chapters.isEmpty) return 0;
    return (currentChapterIndex + 1) / chapters.length;
  }

  /// 是否为夜间（深色）背景
  ///
  /// 按实际背景亮度判断，覆盖上游灰色夜间模板和自定义颜色。
  bool get isDarkBackground => backgroundColor.computeLuminance() < 0.5;

  bool get isNightMode => readingBrightness == null
      ? isDarkBackground
      : readingBrightness == Brightness.dark;

  /// 正文文字颜色（根据背景自动适配）
  Color get textColor =>
      foregroundColor ??
      (isDarkBackground ? const Color(0xFFCCCCCC) : const Color(0xFF333333));
}
