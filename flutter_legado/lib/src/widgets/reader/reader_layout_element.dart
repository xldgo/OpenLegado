import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../services/reader_layout_data.dart';

/// 上游通用页面元素；资源和样式载荷保持原样，几何只读取 Rust 的结果。
enum ReaderElementKind {
  text,
  image,
  roleCast,
  bgmScene,
  review,
  rule,
  blankLine,
  paragraphMarker,
}

@immutable
class ReaderLayoutElement {
  final ReaderElementKind kind;
  final Rect? _bounds;
  final Map<String, dynamic> data;
  const ReaderLayoutElement(this.kind, Rect bounds, this.data)
    : _bounds = bounds;
  const ReaderLayoutElement._glyph(this.data)
    : kind = ReaderElementKind.text,
      _bounds = null;

  double _coordinate(int axis) {
    final value = data;
    if (value is ReaderGlyphData) return value.coordinate(axis);
    return switch (axis) {
      0 => _bounds!.left,
      1 => _bounds!.top,
      2 => _bounds!.right,
      _ => _bounds!.bottom,
    };
  }

  double get left => _coordinate(0);
  double get top => _coordinate(1);
  double get right => _coordinate(2);
  double get bottom => _coordinate(3);
  Rect get bounds => _bounds ?? Rect.fromLTRB(left, top, right, bottom);

  factory ReaderLayoutElement.fromJson(Map<String, dynamic> json) {
    if (json is ReaderGlyphData) return ReaderLayoutElement._glyph(json);
    final kind = ReaderElementKind.values.byName(json['type'] as String);
    final box = json['bounds'] as Map<String, dynamic>;
    double coordinate(String key) {
      final value = (box[key] as num).toDouble();
      if (!value.isFinite) throw const FormatException('布局元素坐标无效');
      return value;
    }

    final rect = Rect.fromLTRB(
      coordinate('left'),
      coordinate('top'),
      coordinate('right'),
      coordinate('bottom'),
    );
    if (rect.width < 0 || rect.height < 0) {
      throw const FormatException('布局元素尺寸无效');
    }
    return ReaderLayoutElement(kind, rect, UnmodifiableMapView(json));
  }

  int get sourceOffset => (data['chapterPosition'] as int?) ?? 0;
  int get paragraphIndex => (data['paragraphIndex'] as int?) ?? 0;
  String get text => (data['value'] as String?) ?? '';
  double get baseline =>
      (data['baselinePx'] as num?)?.toDouble() ?? bounds.bottom;
}

/// 通用元素和行字形引用同一份页面载荷，不保留逐字 Rect 或第二套字段。
class ReaderLayoutElementList extends ReaderReadonlyList<ReaderLayoutElement> {
  final ReaderElementDataList data;
  ReaderLayoutElementList(this.data) {
    for (final value in data) {
      if (value is! ReaderGlyphData) ReaderLayoutElement.fromJson(value);
    }
  }
  @override
  int get length => data.length;
  @override
  ReaderLayoutElement operator [](int index) =>
      ReaderLayoutElement.fromJson(data[index]);
}

class ReaderLineElements extends ReaderReadonlyList<ReaderLayoutElement> {
  final List<ReaderLayoutElement> elements;
  final Uint32List _indices;
  ReaderLineElements(this.elements, List<int> indices)
    : _indices = Uint32List.fromList(indices);
  @override
  int get length => _indices.length;
  @override
  ReaderLayoutElement operator [](int index) => elements[_indices[index]];
}

class ReaderLineWords extends ReaderReadonlyList<String> {
  final ReaderLineElements elements;
  ReaderLineWords(this.elements);
  @override
  int get length => elements.length;
  @override
  String operator [](int index) => elements[index].text;
}

class ReaderLineGlyphs extends ReaderReadonlyList<ReaderGlyph> {
  final ReaderLineElements elements;
  final int sourceStart;
  final Offset origin;
  ReaderLineGlyphs(this.elements, this.sourceStart, this.origin);
  @override
  int get length => elements.length;
  @override
  ReaderGlyph operator [](int index) =>
      ReaderGlyph(elements[index], sourceStart, origin);
}

/// 原文范围和最终字形位置共同用于绘制、命中测试及原生选区。
@immutable
class ReaderGlyph {
  final ReaderLayoutElement element;
  final int sourceStart;
  final Offset origin;
  const ReaderGlyph(this.element, this.sourceStart, this.origin);
  String get text => element.text;
  int get start => element.sourceOffset - sourceStart;
  int get end => start + text.length;
  Rect get bounds => Rect.fromLTRB(
    element.left - origin.dx,
    element.top - origin.dy,
    element.right - origin.dx,
    element.bottom - origin.dy,
  );
  double get baseline => element.baseline - origin.dy;
  Map<String, dynamic> get style =>
      (element.data['style'] as Map<String, dynamic>?) ?? const {};
}
