import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'text_layout_environment.dart';
import 'line_text_span.dart';
import 'reader_layout_element.dart';

TextStyle _effectiveReaderStyle(BuildContext context, TextStyle style) {
  final defaults = DefaultTextStyle.of(context);
  var effective = style.inherit ? defaults.style.merge(style) : style;
  if (MediaQuery.boldTextOf(context)) {
    effective = effective.copyWith(fontWeight: FontWeight.bold);
  }
  return effective;
}

/// 无布局字形的原生文本统一字体回退高度；正式正文直接使用布局边界。
@immutable
class _ReaderSelectionGeometry {
  const _ReaderSelectionGeometry({required this.ascent, required this.descent});

  final double ascent;
  final double descent;

  static _ReaderSelectionGeometry? _measure(
    InlineSpan text, {
    required TextScaler textScaler,
    required TextDirection textDirection,
    Locale? locale,
    TextHeightBehavior? textHeightBehavior,
  }) {
    final plainText = text.toPlainText();
    if (plainText.isEmpty) return null;
    final painter = TextPainter(
      text: text,
      textScaler: textScaler,
      textDirection: textDirection,
      locale: locale,
      textHeightBehavior: textHeightBehavior,
      maxLines: 1,
    )..layout();
    try {
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: plainText.length),
      );
      if (boxes.isEmpty) return null;
      var top = boxes.first.top;
      var bottom = boxes.first.bottom;
      for (final box in boxes.skip(1)) {
        if (box.top < top) top = box.top;
        if (box.bottom > bottom) bottom = box.bottom;
      }
      final baseline = painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      return _ReaderSelectionGeometry(
        ascent: baseline - top,
        descent: bottom - baseline,
      );
    } finally {
      painter.dispose();
    }
  }
}

/// 单行正文继承阅读主题、文字缩放及原生选区的注册与配色。
class ReaderLineText extends StatelessWidget {
  final String data;
  final TextStyle style;
  final TextLayoutEnvironment? environment;
  final double spaceExpansion;
  final List<ReaderGlyph> glyphs;

  const ReaderLineText(
    this.data, {
    super.key,
    required this.style,
    this.environment,
    this.spaceExpansion = 0,
    this.glyphs = const [],
  });

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultTextStyle.of(context);
    return ReaderSelectableText(
      text: readerLineSpan(
        data,
        _effectiveReaderStyle(context, style),
        spaceExpansion,
      ),
      glyphs: glyphs,
      glyphStyle: _effectiveReaderStyle(context, style),
      textAlign: defaults.textAlign ?? TextAlign.start,
      softWrap: defaults.softWrap,
      maxLines: 1,
      overflow: TextOverflow.visible,
      textScaler: environment?.textScaler ?? MediaQuery.textScalerOf(context),
      textDirection: environment?.direction,
      locale: environment?.locale,
      textWidthBasis: defaults.textWidthBasis,
      textHeightBehavior:
          environment?.heightBehavior ??
          defaults.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      selectionRegistrar: SelectionContainer.maybeOf(context),
      selectionColor:
          DefaultSelectionStyle.of(context).selectionColor ??
          DefaultSelectionStyle.defaultColor,
    );
  }
}

/// 阅读正文沿用原生选区，跨行共用字形高度并保留排版留白。
class ReaderSelectableText extends RichText {
  final List<ReaderGlyph> glyphs;
  final TextStyle? glyphStyle;

  ReaderSelectableText({
    super.key,
    required InlineSpan text,
    super.textAlign,
    super.textDirection,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines = 1,
    super.locale,
    super.strutStyle,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionRegistrar,
    super.selectionColor,
    this.glyphs = const [],
    this.glyphStyle,
  }) : super(
         text: glyphs.isEmpty
             ? text
             : TextSpan(
                 text: text.toPlainText(),
                 style: glyphStyle?.copyWith(color: const Color(0x00000000)),
               ),
       );

  _ReaderSelectionGeometry? _geometry(BuildContext context) => glyphs.isNotEmpty
      ? null
      : _ReaderSelectionGeometry._measure(
          text,
          textScaler: textScaler,
          textDirection: textDirection ?? Directionality.of(context),
          locale: locale ?? Localizations.maybeLocaleOf(context),
          textHeightBehavior: textHeightBehavior,
        );

  @override
  RenderParagraph createRenderObject(BuildContext context) =>
      _ReaderRenderParagraph(
        text,
        _geometry(context),
        glyphs: glyphs,
        glyphStyle: glyphStyle,
        textAlign: textAlign,
        textDirection: textDirection ?? Directionality.of(context),
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        locale: locale ?? Localizations.maybeLocaleOf(context),
        strutStyle: strutStyle,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        registrar: selectionRegistrar,
        selectionColor: selectionColor,
        devicePixelRatio:
            MediaQuery.maybeDevicePixelRatioOf(context) ??
            View.of(context).devicePixelRatio,
      );

  @override
  void updateRenderObject(BuildContext context, RenderParagraph renderObject) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _ReaderRenderParagraph).selectionGeometry = _geometry(
      context,
    );
    renderObject.updateGlyphs(glyphs, glyphStyle);
  }
}

class _ReaderRenderParagraph extends RenderParagraph {
  _ReaderRenderParagraph(
    super.text,
    this._selectionGeometry, {
    this.glyphs = const [],
    this.glyphStyle,
    super.textAlign,
    required super.textDirection,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.locale,
    super.strutStyle,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.registrar,
    super.selectionColor,
    super.devicePixelRatio,
  });

  _ReaderSelectionGeometry? _selectionGeometry;
  List<ReaderGlyph> glyphs;
  TextStyle? glyphStyle;
  final List<(TextPainter, Offset)> _runs = [];

  void updateGlyphs(List<ReaderGlyph> value, TextStyle? style) {
    if (identical(glyphs, value) && glyphStyle == style) return;
    glyphs = value;
    glyphStyle = style;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    for (final run in _runs) {
      run.$1.dispose();
    }
    _runs.clear();
    if (glyphs.isEmpty) return;
    var index = 0;
    while (index < glyphs.length) {
      final from = index;
      final gap = index + 1 < glyphs.length
          ? glyphs[index + 1].bounds.left - glyphs[index].bounds.right
          : 0.0;
      index++;
      while (index < glyphs.length &&
          mapEquals(glyphs[index].style, glyphs[from].style) &&
          glyphs[index].text != ' ' &&
          glyphs[index - 1].text != ' ' &&
          (glyphs[index].baseline - glyphs[from].baseline).abs() < .001 &&
          (glyphs[index].bounds.left - glyphs[index - 1].bounds.right - gap)
                  .abs() <
              .001) {
        index++;
      }
      final style = glyphStyle ?? const TextStyle();
      final scale =
          textScaler.scale(style.fontSize ?? 16) / (style.fontSize ?? 16);
      final painter = TextPainter(
        text: TextSpan(
          text: glyphs.sublist(from, index).map((g) => g.text).join(),
          style: style.copyWith(letterSpacing: gap / scale),
        ),
        textDirection: textDirection,
        textScaler: textScaler,
        locale: locale,
        textHeightBehavior: textHeightBehavior,
        maxLines: 1,
      )..layout();
      _runs.add((
        painter,
        Offset(
          glyphs[from].bounds.left - gap / 2,
          glyphs[from].baseline -
              painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
        ),
      ));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // 父类保留原生选区、语义和手柄；透明正文不参与第二次落位。
    super.paint(context, offset);
    for (final (painter, position) in _runs) {
      painter.paint(context.canvas, offset + position);
    }
  }

  @override
  TextPosition getPositionForOffset(Offset offset) {
    if (glyphs.isEmpty) return super.getPositionForOffset(offset);
    for (final glyph in glyphs) {
      if (offset.dx < glyph.bounds.center.dx) {
        return TextPosition(offset: glyph.start);
      }
      if (offset.dx < glyph.bounds.right) {
        return TextPosition(offset: glyph.end);
      }
    }
    return TextPosition(offset: glyphs.last.end);
  }

  @override
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    if (glyphs.isEmpty) {
      return super.getOffsetForCaret(position, caretPrototype);
    }
    for (final glyph in glyphs) {
      if (position.offset < glyph.end) {
        return Offset(glyph.bounds.left, glyph.bounds.top);
      }
    }
    return Offset(glyphs.last.bounds.right, glyphs.last.bounds.top);
  }

  @override
  double getFullHeightForCaret(TextPosition position) => glyphs.isEmpty
      ? super.getFullHeightForCaret(position)
      : glyphs.first.bounds.height;

  @override
  void dispose() {
    for (final run in _runs) {
      run.$1.dispose();
    }
    _runs.clear();
    super.dispose();
  }

  set selectionGeometry(_ReaderSelectionGeometry? value) {
    if (identical(value, _selectionGeometry)) return;
    _selectionGeometry = value;
    // 同步原生手柄与选区几何缓存，而不仅是重画选中背景。
    markNeedsLayout();
  }

  @override
  List<ui.TextBox> getBoxesForSelection(
    TextSelection selection, {
    ui.BoxHeightStyle boxHeightStyle = ui.BoxHeightStyle.tight,
    ui.BoxWidthStyle boxWidthStyle = ui.BoxWidthStyle.tight,
  }) {
    if (glyphs.isNotEmpty) {
      final boxes = <ui.TextBox>[];
      for (var i = 0; i < glyphs.length; i++) {
        final glyph = glyphs[i];
        if (glyph.end <= selection.start || glyph.start >= selection.end) {
          continue;
        }
        final right = i + 1 < glyphs.length
            ? glyphs[i + 1].bounds.left
            : glyph.bounds.right;
        // 字形盒已包含主字体度量、基线和行内布局，不再按回退文字扩大选区。
        // 与命中、手柄和分页共用边界，行距与段距留白不参与高亮。— Codex + UI
        final top = glyph.bounds.top;
        final bottom = glyph.bounds.bottom;
        if (boxes.isNotEmpty &&
            (boxes.last.right - glyph.bounds.left).abs() < .001 &&
            (boxes.last.top - top).abs() < .001 &&
            (boxes.last.bottom - bottom).abs() < .001) {
          final last = boxes.removeLast();
          boxes.add(
            ui.TextBox.fromLTRBD(last.left, top, right, bottom, textDirection),
          );
        } else {
          boxes.add(
            ui.TextBox.fromLTRBD(
              glyph.bounds.left,
              top,
              right,
              bottom,
              textDirection,
            ),
          );
        }
      }
      return boxes;
    }
    final boxes = super.getBoxesForSelection(
      selection,
      boxHeightStyle: boxHeightStyle,
      boxWidthStyle: boxWidthStyle,
    );
    final geometry = _selectionGeometry;
    if (boxHeightStyle != ui.BoxHeightStyle.tight ||
        geometry == null ||
        boxes.isEmpty) {
      return boxes;
    }
    final baseline = computeDistanceToActualBaseline(TextBaseline.alphabetic);
    return [
      for (final box in boxes)
        ui.TextBox.fromLTRBD(
          box.left,
          baseline - geometry.ascent,
          box.right,
          baseline + geometry.descent,
          box.direction,
        ),
    ];
  }
}
