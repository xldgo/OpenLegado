import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'chapter_layout.dart';
import 'layout_diagnostics.dart';
import 'paragraph_config.dart';
import 'text_layout_environment.dart';

/// 平台适配器只产出字形簇和字体度量；断点、对齐和分页由 Rust 决定。
class FlutterTextShaper {
  final ParagraphConfig config;
  final TextLayoutEnvironment environment;
  final ReaderLayoutDiagnostics? diagnostics;
  int measurementCount = 0;
  late final TextStyle style = environment.baseStyle.merge(
    TextStyle(
      fontSize: config.fontSize,
      // 行距由分页器推进，文字仅测量自然字体行盒。
      height: kTextHeightNone,
      letterSpacing: 0,
      fontFamily: config.fontFamily,
      fontWeight: config.fontWeight,
      fontStyle: config.fontStyle,
    ),
  );

  FlutterTextShaper(this.config, this.environment, this.diagnostics);

  TextPainter _measure(String text, {double maxWidth = double.infinity}) {
    measurementCount++;
    if (diagnostics != null) diagnostics!.measurementCalls++;
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: environment.direction,
      textScaler: environment.textScaler,
      locale: environment.locale,
      textHeightBehavior: environment.heightBehavior,
    )..layout(maxWidth: maxWidth);
  }

  late final Map<String, Object?> metrics = _metrics();
  Map<String, Object?> _metrics() {
    final timer = diagnostics?.beginMeasurement();
    // 基础行盒跟随主字体；主字体不含中文时，“一Mg”会引入回退字体并抬高全章行距。
    // 行度量保留小数，不能改用已取整的height或preferredLineHeight，否则页尾可能差一行。
    // 行距由Rust单独推进，绘制按同一ascent基线落位。— Codex + UI
    final painter = _measure(' ');
    final line = painter.computeLineMetrics().single;
    final baseline = line.ascent;
    final height = line.ascent + line.descent;
    painter.dispose();
    final indentPainter = _measure('\u3000' * math.max(1, config.indentCount));
    final indent = config.indent > 0 && config.indentCount > 0
        ? indentPainter.width
        : 0.0;
    indentPainter.dispose();
    if (timer != null) {
      diagnostics!.measurementMicroseconds += timer.elapsedMicroseconds;
    }
    return {
      'lineHeightPx': height,
      'baselineOffsetPx': baseline,
      'indentWidthPx': indent,
    };
  }

  double get height => (metrics['lineHeightPx'] as num).toDouble();

  /// 在布局入口统一换算，避免段评或滚动再次解释设置单位。— Codex + UI
  double get paragraphSpacingPx => height * config.paragraphSpacing / 10;
  double get baseline => (metrics['baselineOffsetPx'] as num).toDouble();
  double get spacing =>
      config.letterSpacing *
      environment.textScaler.scale(config.fontSize) /
      config.fontSize;

  Map<String, Object?> measure(
    SourceParagraph paragraph,
    int index,
    InlineReview? review,
    double width,
  ) {
    final timer = diagnostics?.beginMeasurement();
    final map = TextClusterMap(paragraph.text);
    // 测量分成有限宽的塑形行，避免超长单行的逐簇盒查询退化为平方扫描。
    final painter = _measure(paragraph.text, maxWidth: width);
    final widths = <double>[];
    for (var i = 0; i < map.clusters.length; i++) {
      final boxes = painter.getBoxesForSelection(
        TextSelection(
          baseOffset: map.sourceOffsets[i],
          extentOffset: map.sourceOffsets[i + 1],
        ),
      );
      widths.add(boxes.fold(0.0, (sum, box) => sum + box.right - box.left));
    }
    painter.dispose();
    if (timer != null) {
      diagnostics!.measurementMicroseconds += timer.elapsedMicroseconds;
    }
    final styleJson = <String, Object?>{
      'colorArgb': config.textColor.toARGB32().toSigned(32),
      'fontSizePx': environment.textScaler.scale(config.fontSize),
      'fontFamily':
          config.fontFamily ?? environment.baseStyle.fontFamily ?? 'sans-serif',
      'fontWeight':
          (config.fontWeight ?? style.fontWeight ?? FontWeight.normal).value,
      'italic': config.fontStyle == FontStyle.italic,
    };
    var indent = (metrics['indentWidthPx'] as num).toDouble();
    // 已授权的段首引号悬挂仅改变几何输入，绝不插入缩进字符。
    if (config.hangingPunctuation &&
        environment.direction == TextDirection.ltr &&
        const {
          '"',
          "'",
          '“',
          '‘',
          '「',
          '『',
          '﹁',
          '﹃',
        }.contains(map.clusters.first)) {
      indent -= math.min(indent, widths.first);
    }
    final common = <String, Object?>{
      'indentCharacters': 0,
      'indentWidthPx': indent,
      'alignment': config.justify ? 'justify' : 'start',
      'lineHeightPx': height,
      'lineSpacingMultiplier': config.lineHeight,
      'baselineOffsetPx': baseline,
      'letterSpacingPx': spacing,
    };
    if (review == null || review.count <= 0) {
      return {
        'type': 'paragraph',
        'value': {
          ...common,
          'text': paragraph.text,
          'clusters': map.clusters,
          'clusterWidthsPx': widths,
          'chapterPosition': paragraph.startIndex,
          'style': styleJson,
        },
      };
    }
    return {
      'type': 'inlineParagraph',
      ...common,
      'baseTextSizePx': environment.textScaler.scale(config.fontSize),
      'justifyAtWordBoundaries': true,
      'items': [
        for (var i = 0; i < map.clusters.length; i++)
          {
            'type': 'text',
            'value': map.clusters[i],
            'widthPx': widths[i],
            'style': styleJson,
            'chapterPosition': paragraph.startIndex + map.sourceOffsets[i],
          },
        {
          'type': 'review',
          'widthPx': review.size.width,
          'heightPx': review.size.height,
          'compactWidthPx': review.compactSize.width,
          'compactHeightPx': review.compactSize.height,
          'baselineOffsetPx': review.baseline,
          'chapterPosition': review.sourceAnchor,
          'paragraphIndex': index,
          'reviewKey': review.reviewKey.toString(),
          'count': review.count,
        },
      ],
    };
  }
}
