import 'package:flutter/widgets.dart';

/// 测量使用逻辑字号，布局传输使用缩放后的字号；绘制不再二次缩放。
TextStyle highlightTextStyle(TextStyle base, Map<String, dynamic> style) {
  final path = style['fontPath'] as String?;
  final weight = (style['fontWeight'] as num?)?.toInt() ?? 400;
  return base.copyWith(
    color: style['textColor'] == null
        ? null
        : Color((style['textColor'] as num).toInt()),
    fontSize:
        ((base.fontSize ?? 16) +
                ((style['fontSizeOffset'] as num?)?.toDouble() ?? 0))
            .clamp(1.0, 1000.0),
    fontWeight: weight == 400
        ? null
        : FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
    fontStyle: style['isItalic'] == true ? FontStyle.italic : FontStyle.normal,
    fontFamily: path == null || path.isEmpty ? null : 'Highlight:$path',
  );
}

TextStyle readerGlyphTextStyle(TextStyle base, Map<String, dynamic> style) =>
    base.copyWith(
      color: style['inheritColor'] == true || style['colorArgb'] == null
          ? null
          : Color((style['colorArgb'] as num).toInt()),
      fontSize: (style['fontSizePx'] as num?)?.toDouble(),
      fontWeight: style['fontWeight'] == null
          ? null
          : FontWeight.values[((style['fontWeight'] as int) ~/ 100 - 1).clamp(
              0,
              8,
            )],
      fontStyle: style['italic'] == true ? FontStyle.italic : FontStyle.normal,
      fontFamily: style['fontFamily'] as String?,
    );
