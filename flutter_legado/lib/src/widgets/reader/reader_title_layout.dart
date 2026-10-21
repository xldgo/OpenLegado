import 'package:flutter/widgets.dart';

import 'reader_page_chrome.dart';
import 'text_layout_environment.dart';

/// 标题测量与绘制共用的最终样式，禁止滚动和预览另造默认值。— Codex + UI
final class ReaderTitleLayout {
  final ReaderPageChromeConfig chrome;
  final TextLayoutEnvironment environment;
  final TextStyle style;
  final TextAlign alignment;

  ReaderTitleLayout({
    required this.chrome,
    required this.environment,
    required double bodySize,
    required Color color,
    String? bodyFont,
    double letterSpacingEm = 0,
    FontStyle? fontStyle,
  }) : alignment = chrome.titleMode == 1 ? TextAlign.center : TextAlign.start,
       style = environment.baseStyle.merge(
         TextStyle(
           fontSize:
               (chrome.titleSizeRelative
                       ? bodySize + chrome.titleSize
                       : chrome.titleSize.toDouble())
                   .clamp(1, 1000),
           fontFamily: effectiveTitleFontFamily(chrome, bodyFont),
           fontWeight:
               FontWeight.values[((chrome.titleFontWeight / 100).round() - 1)
                   .clamp(0, 8)],
           fontStyle: fontStyle ?? FontStyle.normal,
           height: chrome.titleLineHeight,
           letterSpacing:
               letterSpacingEm *
               (chrome.titleSizeRelative
                       ? bodySize + chrome.titleSize
                       : chrome.titleSize.toDouble())
                   .clamp(1, 1000),
           color: color,
         ),
       );

  bool get visible => chrome.titleMode != 2;
  double measure(String text, double width) {
    if (!visible || text.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: alignment,
      textDirection: environment.direction,
      textScaler: environment.textScaler,
      locale: environment.locale,
      textHeightBehavior: environment.heightBehavior,
    )..layout(maxWidth: width);
    final height =
        painter.height + chrome.titleTopSpacing + chrome.titleBottomSpacing;
    painter.dispose();
    return height;
  }

  Widget build(String text) => !visible || text.isEmpty
      ? const SizedBox.shrink()
      : SelectionContainer.disabled(
          child: Padding(
            padding: EdgeInsets.only(
              top: chrome.titleTopSpacing.toDouble(),
              bottom: chrome.titleBottomSpacing.toDouble(),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                text,
                style: style,
                textAlign: alignment,
                textDirection: environment.direction,
                textScaler: environment.textScaler,
                locale: environment.locale,
                textHeightBehavior: environment.heightBehavior,
              ),
            ),
          ),
        );
}
