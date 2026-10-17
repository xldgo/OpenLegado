import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

/// 只读集合共用边界，渲染与选区不能改写 Rust 已定稿数据。
abstract class ReaderReadonlyList<E> extends ListBase<E> {
  @override
  set length(int value) => throw UnsupportedError('阅读布局只读');
  @override
  void operator []=(int index, E value) => throw UnsupportedError('阅读布局只读');
}

/// 一批页面共享数值缓冲、正文和样式；纯数据层不依赖 Flutter。
class ReaderGlyphColumns {
  final Float32List _geometry;
  final Uint32List _positions;
  final String _text;
  final List<Map<String, dynamic>> _styles;
  final Map<int, Map<String, dynamic>> _extras;
  final int estimatedBytes;
  ReaderGlyphColumns._(
    this._geometry,
    this._positions,
    this._text,
    this._styles,
    this._extras,
    this.estimatedBytes,
  );

  factory ReaderGlyphColumns.decode(Object? value, Object? styles) {
    if (value is! Map<String, dynamic> ||
        value['count'] is! int ||
        (value['count'] as int) < 0 ||
        value['text'] is! String ||
        (value['geometry'] is! String && value['geometry'] is! Uint8List) ||
        (value['positions'] is! String && value['positions'] is! Uint8List) ||
        value['extras'] is! Map<String, dynamic> ||
        styles is! List ||
        styles.any((style) => style is! Map<String, dynamic>)) {
      throw const FormatException('阅读布局字形缓冲无效');
    }
    final count = value['count'] as int;
    final geometryBytes = value['geometry'] is Uint8List
        ? value['geometry'] as Uint8List
        : base64Decode(value['geometry'] as String);
    final positionBytes = value['positions'] is Uint8List
        ? value['positions'] as Uint8List
        : base64Decode(value['positions'] as String);
    if (geometryBytes.length != count * 20 ||
        positionBytes.length != count * 16) {
      throw const FormatException('阅读布局字形缓冲长度无效');
    }
    final geometry = _floats(geometryBytes);
    final positions = _integers(positionBytes);
    final text = value['text'] as String;
    var start = 0;
    for (var i = 0; i < count; i++) {
      final g = i * 5;
      final p = i * 4;
      for (var j = 0; j < 5; j++) {
        if (!geometry[g + j].isFinite) {
          throw const FormatException('阅读布局文字几何无效');
        }
      }
      final end = positions[p + 3];
      if (geometry[g + 2] < geometry[g] ||
          geometry[g + 3] < geometry[g + 1] ||
          positions[p] > 0x7fffffff ||
          positions[p + 1] > 0x7fffffff ||
          positions[p + 2] >= styles.length ||
          end < start ||
          end > text.length ||
          _splitsSurrogate(text, end)) {
        throw const FormatException('阅读布局文字范围或样式无效');
      }
      start = end;
    }
    if (start != text.length) {
      throw const FormatException('阅读布局文字长度不匹配');
    }
    final extras = <int, Map<String, dynamic>>{};
    for (final entry in (value['extras'] as Map<String, dynamic>).entries) {
      final index = int.tryParse(entry.key);
      if (index == null ||
          index < 0 ||
          index >= count ||
          entry.key != index.toString() ||
          entry.value is! Map<String, dynamic>) {
        throw const FormatException('阅读布局文字附加字段索引无效');
      }
      final fields = entry.value as Map<String, dynamic>;
      _validateExtras(fields);
      extras[index] = Map.unmodifiable(fields);
    }
    final immutableStyles = List<Map<String, dynamic>>.unmodifiable(
      styles.map((style) => Map<String, dynamic>.unmodifiable(style as Map)),
    );
    // 容量预算包含实际缓冲字节及字符串/低频载荷估算，不代表 VM 堆或进程 RSS。
    final estimate =
        geometryBytes.length +
        positionBytes.length +
        text.length * 2 +
        jsonEncode(styles).length * 2 +
        jsonEncode(value['extras']).length * 2 +
        128 * (styles.length + extras.length) +
        128;
    return ReaderGlyphColumns._(
      geometry,
      positions,
      text,
      immutableStyles,
      Map.unmodifiable(extras),
      estimate,
    );
  }

  int get count => _positions.length ~/ 4;
  double coordinate(int index, int axis) => _geometry[index * 5 + axis];
  int position(int index, int field) => _positions[index * 4 + field];
  String text(int index) => _text.substring(
    index == 0 ? 0 : position(index - 1, 3),
    position(index, 3),
  );
  Map<String, dynamic> style(int index) => _styles[position(index, 2)];
  Map<String, dynamic> extras(int index) => _extras[index] ?? const {};

  static bool _splitsSurrogate(String text, int end) =>
      end > 0 &&
      end < text.length &&
      text.codeUnitAt(end - 1) >= 0xd800 &&
      text.codeUnitAt(end - 1) <= 0xdbff &&
      text.codeUnitAt(end) >= 0xdc00 &&
      text.codeUnitAt(end) <= 0xdfff;
  static Float32List _floats(Uint8List bytes) {
    if (Endian.host == Endian.little && bytes.offsetInBytes % 4 == 0) {
      return Float32List.view(
        bytes.buffer,
        bytes.offsetInBytes,
        bytes.length ~/ 4,
      );
    }
    final data = ByteData.sublistView(bytes);
    return Float32List.fromList([
      for (var i = 0; i < bytes.length; i += 4)
        data.getFloat32(i, Endian.little),
    ]);
  }

  static Uint32List _integers(Uint8List bytes) {
    if (Endian.host == Endian.little && bytes.offsetInBytes % 4 == 0) {
      return Uint32List.view(
        bytes.buffer,
        bytes.offsetInBytes,
        bytes.length ~/ 4,
      );
    }
    final data = ByteData.sublistView(bytes);
    return Uint32List.fromList([
      for (var i = 0; i < bytes.length; i += 4)
        data.getUint32(i, Endian.little),
    ]);
  }

  static void _validateExtras(Map<String, dynamic> fields) {
    for (final entry in fields.entries) {
      final valid = switch (entry.key) {
        'selected' ||
        'emphasized' ||
        'readAloud' ||
        'searchResult' ||
        'continuesBackgroundRun' => entry.value is bool,
        'link' || 'markingId' => entry.value == null || entry.value is String,
        'backgroundFrameTopPx' ||
        'backgroundFrameBottomPx' ||
        'backgroundFrameLeftPx' ||
        'backgroundFrameRightPx' =>
          entry.value is num && (entry.value as num).isFinite,
        'emphasisUnderline' => true,
        _ => false,
      };
      if (!valid) throw const FormatException('阅读布局文字附加字段无效');
    }
  }
}

/// 文字 Map 仅是共享缓冲上的短期视图，几何可直接读取，不生成持久字段表。
class ReaderGlyphData extends MapBase<String, dynamic> {
  final ReaderGlyphColumns columns;
  final int index;
  ReaderGlyphData(this.columns, this.index);
  double coordinate(int axis) => columns.coordinate(index, axis);
  static const defaults = <String, dynamic>{
    'selected': false,
    'emphasized': false,
    'readAloud': false,
    'searchResult': false,
    'continuesBackgroundRun': false,
    'link': null,
    'markingId': null,
    'emphasisUnderline': null,
    'backgroundFrameTopPx': 0.0,
    'backgroundFrameBottomPx': 0.0,
    'backgroundFrameLeftPx': 0.0,
    'backgroundFrameRightPx': 0.0,
  };
  @override
  Iterable<String> get keys => const [
    'type',
    'bounds',
    'baselinePx',
    'value',
    'chapterPosition',
    'paragraphIndex',
    'style',
    ...[
      'selected',
      'emphasized',
      'readAloud',
      'searchResult',
      'continuesBackgroundRun',
      'link',
      'markingId',
      'emphasisUnderline',
      'backgroundFrameTopPx',
      'backgroundFrameBottomPx',
      'backgroundFrameLeftPx',
      'backgroundFrameRightPx',
    ],
  ];
  @override
  dynamic operator [](Object? key) => switch (key) {
    'type' => 'text',
    'bounds' => Map<String, dynamic>.unmodifiable({
      'left': coordinate(0),
      'top': coordinate(1),
      'right': coordinate(2),
      'bottom': coordinate(3),
    }),
    'baselinePx' => coordinate(4),
    'value' => columns.text(index),
    'chapterPosition' => columns.position(index, 0),
    'paragraphIndex' => columns.position(index, 1),
    'style' => columns.style(index),
    _ =>
      columns.extras(index).containsKey(key)
          ? columns.extras(index)[key]
          : defaults[key],
  };
  @override
  void operator []=(String key, dynamic value) =>
      throw UnsupportedError('阅读字形只读');
  @override
  void clear() => throw UnsupportedError('阅读字形只读');
  @override
  dynamic remove(Object? key) => throw UnsupportedError('阅读字形只读');
}

/// 页面只保存字形编号，通用非文字元素保持原载荷与次序。
class ReaderElementDataList extends ReaderReadonlyList<Map<String, dynamic>> {
  final ReaderGlyphColumns columns;
  final Uint32List _indices;
  final Map<int, Map<String, dynamic>> _other;
  final int estimatedBytes;
  ReaderElementDataList._(
    this.columns,
    this._indices,
    this._other,
    this.estimatedBytes,
  );
  factory ReaderElementDataList.decode(
    Object? value,
    ReaderGlyphColumns columns,
  ) {
    if (value is! List) throw const FormatException('阅读布局元素集合无效');
    final indices = Uint32List(value.length);
    final other = <int, Map<String, dynamic>>{};
    var estimate = indices.lengthInBytes + 64;
    for (var i = 0; i < value.length; i++) {
      final element = value[i];
      if (element is int && element >= 0 && element < columns.count) {
        indices[i] = element;
      } else if (element is Map<String, dynamic> && element['type'] != 'text') {
        indices[i] = 0xffffffff;
        other[i] = Map.unmodifiable(element);
        estimate += jsonEncode(element).length * 2 + 128;
      } else {
        throw const FormatException('阅读布局元素引用无效');
      }
    }
    return ReaderElementDataList._(
      columns,
      indices,
      Map.unmodifiable(other),
      estimate,
    );
  }
  @override
  int get length => _indices.length;
  @override
  Map<String, dynamic> operator [](int index) {
    RangeError.checkValidIndex(index, this);
    return _other[index] ?? ReaderGlyphData(columns, _indices[index]);
  }
}
