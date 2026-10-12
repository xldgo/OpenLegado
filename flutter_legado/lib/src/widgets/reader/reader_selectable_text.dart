import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'text_layout_environment.dart';
import 'line_text_span.dart';

TextStyle _effectiveReaderStyle(BuildContext context, TextStyle style) {
  final defaults = DefaultTextStyle.of(context);
  var effective = style.inherit ? defaults.style.merge(style) : style;
  if (MediaQuery.boldTextOf(context)) {
    effective = effective.copyWith(fontWeight: FontWeight.bold);
  }
  return effective;
}

/// 当前页共用字形边界；行距由排版决定，不计入选中背景。
@immutable
class ReaderSelectionGeometry {
  const ReaderSelectionGeometry({required this.ascent, required this.descent});

  final double ascent;
  final double descent;

  static ReaderSelectionGeometry? forText(
    BuildContext context,
    String text,
    TextStyle style,
  ) => _measure(
    TextSpan(text: text, style: _effectiveReaderStyle(context, style)),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
    locale: Localizations.maybeLocaleOf(context),
    textHeightBehavior:
        DefaultTextStyle.of(context).textHeightBehavior ??
        DefaultTextHeightBehavior.maybeOf(context),
  );

  static ReaderSelectionGeometry? _measure(
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
      return ReaderSelectionGeometry(
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
  final ReaderSelectionGeometry? selectionGeometry;
  final TextLayoutEnvironment? environment;
  final double spaceExpansion;

  const ReaderLineText(
    this.data, {
    super.key,
    required this.style,
    this.selectionGeometry,
    this.environment,
    this.spaceExpansion = 0,
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
      selectionGeometry: selectionGeometry,
      textAlign: defaults.textAlign ?? TextAlign.start,
      softWrap: defaults.softWrap,
      maxLines: 1,
      overflow: TextOverflow.clip,
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
  final ReaderSelectionGeometry? selectionGeometry;

  ReaderSelectableText({
    super.key,
    required super.text,
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
    this.selectionGeometry,
  });

  ReaderSelectionGeometry? _geometry(BuildContext context) =>
      selectionGeometry ??
      ReaderSelectionGeometry._measure(
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
  }
}

class _ReaderRenderParagraph extends RenderParagraph {
  _ReaderRenderParagraph(
    super.text,
    this._selectionGeometry, {
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

  ReaderSelectionGeometry? _selectionGeometry;

  set selectionGeometry(ReaderSelectionGeometry? value) {
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
