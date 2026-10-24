import '../highlight/reader_highlight_resources.dart';
import '../../../domain/models/highlight_rule.dart';

import 'package:flutter/widgets.dart';

import 'chapter_layout.dart';
import 'flutter_text_shaper.dart';
import 'paragraph_config.dart';
import '../widgets/reader_page_chrome.dart';
import 'text_layout_environment.dart';
import '../../../domain/models/reader_layout_diagnostics.dart';

/// 标题文字与正文原文分开，样式、分段及几何在排版入口一次冻结。— Codex + UI
final class ReaderTitleLayout {
  final String text;
  final ReaderPageChromeConfig chrome;
  final bool isVolume;
  const ReaderTitleLayout({
    required this.text,
    required this.chrome,
    this.isVolume = false,
  });

  Object get geometryKey => (
    text,
    isVolume,
    chrome.titleMode,
    chrome.titleSize,
    chrome.titleSizeRelative,
    chrome.titleFontWeight,
    chrome.titleLineHeight,
    chrome.titleFontFamily,
    chrome.titleTopSpacing,
    chrome.titleBottomSpacing,
    chrome.titleSegmentType,
    chrome.titleSegmentPosition,
    chrome.titleSegmentDelimiter,
    chrome.titleSubtitleScale,
    chrome.titleSegmentSpacing,
  );

  List<({String text, double scale})> segments() {
    final result = <({String text, double scale})>[];
    for (final line
        in text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
      var pieces = <String>[line];
      if (chrome.titleSegmentType == 1) {
        // 上游位置是UTF-16偏移；落在字形簇内部时移到下一个合法边界。
        final map = TextClusterMap(line);
        final boundaries = map.sourceOffsets.where(
          (v) => v >= chrome.titleSegmentPosition && v < line.length,
        );
        if (boundaries.isNotEmpty && boundaries.first > 0) {
          pieces = [
            line.substring(0, boundaries.first),
            line.substring(boundaries.first),
          ];
        }
      } else if (chrome.titleSegmentType == 2 || chrome.titleSegmentType == 3) {
        final pattern = chrome.titleSegmentType == 3
            ? chrome.titleSegmentDelimiter
            : chrome.titleSegmentDelimiter
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .map(RegExp.escape)
                  .join('|');
        if (pattern.isNotEmpty) {
          try {
            pieces = line
                .split(RegExp('(?<=$pattern)'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          } on FormatException {
            /* 错误导入规则不能让章节无法阅读。 */
          }
        }
      }
      for (var i = 0; i < pieces.length; i++) {
        result.add((
          text: pieces[i],
          scale: i == 0 ? 1 : chrome.titleSubtitleScale,
        ));
      }
    }
    return result;
  }

  MeasuredReaderTitle measure(
    ParagraphConfig body,
    TextLayoutEnvironment environment,
    double width, {
    required bool emptyBody,
    ReaderLayoutDiagnostics? diagnostics,
    List<HighlightMatch> highlights = const [],
    ReaderHighlightResources? resources,
  }) {
    if (chrome.titleMode == 2 && !isVolume && !emptyBody) {
      return MeasuredReaderTitle.empty;
    }
    final parts = segments();
    if (parts.isEmpty) return MeasuredReaderTitle.empty;
    final fontSize =
        (chrome.titleSizeRelative
                ? body.fontSize + chrome.titleSize
                : chrome.titleSize.toDouble())
            .clamp(1.0, 1000.0);
    final titleConfig = body.copyWith(
      fontSize: fontSize,
      lineHeight: chrome.titleLineHeight,
      fontFamily: effectiveTitleFontFamily(chrome, body.fontFamily),
      fontWeight: FontWeight
          .values[((chrome.titleFontWeight / 100).round() - 1).clamp(0, 8)],
      letterSpacing: body.letterSpacing / body.fontSize * fontSize,
      indent: 0,
      indentCount: 0,
      justify: false,
      hangingPunctuation: false,
    );
    final baseShaper = FlutterTextShaper(
      titleConfig,
      environment,
      diagnostics,
      resources: resources,
    );
    final shapers = <FlutterTextShaper>{baseShaper};
    final h = baseShaper.height;
    final blocks = <Map<String, Object?>>[];
    final paragraphs = <SourceParagraph>[];
    final styles = <TextStyle>[];
    var sourceCursor = 0;
    for (final part in parts) {
      final shaper = part.scale == 1
          ? baseShaper
          : FlutterTextShaper(
              titleConfig.copyWith(
                fontSize: fontSize * part.scale,
                letterSpacing: titleConfig.letterSpacing * part.scale,
              ),
              environment,
              diagnostics,
              resources: resources,
            );
      shapers.add(shaper);
      final paragraph = SourceParagraph(part.text, 0, part.text.length);
      final sourceStart = text.indexOf(part.text, sourceCursor);
      sourceCursor = sourceStart + part.text.length;
      final localMatches = [
        for (final m in highlights)
          if (m.start < sourceCursor && m.end > sourceStart)
            HighlightMatch(
              start: m.start - sourceStart,
              end: m.end - sourceStart,
              style: m.style,
            ),
      ];
      final measuredBlock = shaper.measure(
        paragraph,
        0,
        null,
        width,
        highlights: localMatches,
      );
      final measured = measuredBlock['value'] as Map<String, Object?>?;
      final map = TextClusterMap(part.text);
      final widths = measured?['clusterWidthsPx'] as List<double>?;
      blocks.add({
        'type': 'inlineParagraph',
        'emphasized': true,
        'alignment': chrome.titleMode == 1 || isVolume || emptyBody
            ? 'center'
            : 'start',
        'indentCharacters': 0,
        'indentWidthPx': 0,
        'lineHeightPx': shaper.height,
        'baselineOffsetPx': shaper.baseline,
        'lineSpacingMultiplier': chrome.titleLineHeight,
        'baseTextSizePx': environment.textScaler.scale(shaper.config.fontSize),
        'letterSpacingPx': shaper.spacing,
        'titleSpacingScale': shaper.height / h,
        'items': measured == null
            ? measuredBlock['items']
            : [
                for (var i = 0; i < map.clusters.length; i++)
                  {
                    'type': 'text',
                    'value': map.clusters[i],
                    'widthPx': widths![i],
                    'style': measured['style'],
                    'chapterPosition': map.sourceOffsets[i],
                  },
              ],
      });
      paragraphs.add(paragraph);
      styles.add(shaper.style);
    }
    return MeasuredReaderTitle(blocks, paragraphs, styles, {
      'titleTopSpacingPx': chrome.titleTopSpacing,
      'titleBottomSpacingPx': chrome.titleBottomSpacing,
      'titleParagraphSpacingPx': h * body.paragraphSpacing / 10,
      'titleSegmentSpacingPx': h * chrome.titleSegmentSpacing,
      'titlePageCenterVertical': emptyBody,
    }, shapers.fold(0, (sum, shaper) => sum + shaper.measurementCount));
  }
}

final class MeasuredReaderTitle {
  final List<Map<String, Object?>> blocks;
  final List<SourceParagraph> paragraphs;
  final List<TextStyle> styles;
  final Map<String, Object?> config;
  final int measurementCount;
  const MeasuredReaderTitle(
    this.blocks,
    this.paragraphs,
    this.styles,
    this.config, [
    this.measurementCount = 0,
  ]);
  static const empty = MeasuredReaderTitle([], [], [], {});
}
