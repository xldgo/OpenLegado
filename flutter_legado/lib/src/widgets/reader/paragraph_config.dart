import 'package:flutter/widgets.dart';

import 'text_layout_environment.dart';

/// 段落样式配置
@immutable
class ParagraphConfig {
  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final double indent;
  final bool justify;
  final Color backgroundColor;
  final Color textColor;

  // [UI-fix v2.0.2 | 2026-08-06] 字距与字体接入排版配置（阅读配置面板
  // 字距调节/字体选择；测量与渲染同参，保证分页一致性） — Qoder
  final double letterSpacing;
  final String? fontFamily;

  // [UI-fix v2.0.4 | 2026-08-08] 界面面板对齐原版 ReadStyleDialog：
  // 缩进字符数档位（0-3，对标原版 tvTextIndent "　".repeat(index)）与
  // 文字字重（textBold 映射 FontWeight，测量与渲染同参避免分页偏差） — Qoder
  final int indentCount;
  final FontWeight? fontWeight;

  // [C3 斜体 | Qoder UI] 文字斜体（参考版行内面板「斜体」开关；与 fontWeight
  // 同样注入测量与渲染两侧，保持测量/渲染同源同参）
  final FontStyle? fontStyle;

  /// 沿用阅读设置开关名称；开启时使用中文断行器，关闭时按簇宽断行。
  final bool useZhLayout;

  // [UI-fix v2.0.5 | 2026-08-10] 段首标点悬挂开关（对标原版
  // hangingPunctuation：段首引号悬挂进缩进区，默认 false 对齐原版）— Reasonix
  final bool hangingPunctuation;

  // [UI_SYNC_REFACTOR S4 修 | 2026-09-06] 渲染同参测量：渲染侧 Text 继承
  // DefaultTextStyle（主题字体回退链）并应用 MediaQuery 文字缩放，测量侧
  // TextPainter 此前两者皆缺 → 系统字体缩放/主题字体下测量偏窄 → 行尾吞字。
  // 由分页调用点注入（引擎不依赖 context，测试可空缺=不缩放不合并）— Qoder
  final TextStyle? baseStyle;
  final TextScaler? textScaler;
  final TextLayoutEnvironment? textEnvironment;

  const ParagraphConfig({
    this.fontSize = 16.0,
    this.lineHeight = 1.6,
    this.paragraphSpacing = 8.0,
    this.indent = 0.0,
    this.justify = true,
    // [A-4 | 2026-09-20 用户裁决] 原死默认 Colors.white/Colors.black（调用方
    // 恒以 state 派生色覆写，默认值从未被生产路径依赖）改为必填：漏传颜色
    // 直接编译错误，杜绝隐性主题回退（DARK_THEME 台账 C3 项闭环）。
    required this.backgroundColor,
    required this.textColor,
    this.letterSpacing = 0.0,
    this.fontFamily,
    this.indentCount = 2,
    this.fontWeight,
    this.fontStyle,
    this.useZhLayout = true,
    this.hangingPunctuation = false,
    this.baseStyle,
    this.textScaler,
    this.textEnvironment,
  });

  ParagraphConfig copyWith({
    double? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    double? indent,
    bool? justify,
    Color? backgroundColor,
    Color? textColor,
    double? letterSpacing,
    String? fontFamily,
    int? indentCount,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    bool? useZhLayout,
    bool? hangingPunctuation,
    TextStyle? baseStyle,
    TextScaler? textScaler,
    TextLayoutEnvironment? textEnvironment,
  }) {
    return ParagraphConfig(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      indent: indent ?? this.indent,
      justify: justify ?? this.justify,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      fontFamily: fontFamily ?? this.fontFamily,
      indentCount: indentCount ?? this.indentCount,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      useZhLayout: useZhLayout ?? this.useZhLayout,
      hangingPunctuation: hangingPunctuation ?? this.hangingPunctuation,
      baseStyle: baseStyle ?? this.baseStyle,
      textScaler: textScaler ?? this.textScaler,
      textEnvironment: textEnvironment ?? this.textEnvironment,
    );
  }
}
