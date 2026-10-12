import 'package:flutter/widgets.dart';

/// 测量、绘制和原生选区共用同一文本跨度，词间扩展不增加原文字符。
TextSpan readerLineSpan(String text, TextStyle style, double spaceExpansion) {
  if (spaceExpansion == 0) return TextSpan(text: text, style: style);
  final children = <InlineSpan>[];
  var start = 0;
  for (final match in RegExp(r' +').allMatches(text)) {
    if (match.start > start) {
      children.add(TextSpan(text: text.substring(start, match.start)));
    }
    children.add(
      TextSpan(
        text: match.group(0),
        style: TextStyle(
          letterSpacing: (style.letterSpacing ?? 0) + spaceExpansion,
        ),
      ),
    );
    start = match.end;
  }
  if (start < text.length) children.add(TextSpan(text: text.substring(start)));
  return TextSpan(style: style, children: children);
}
