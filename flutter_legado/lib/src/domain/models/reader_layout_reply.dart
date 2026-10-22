import 'dart:convert';

import 'reader_layout_data.dart';

class ReaderLayoutReply {
  final Object sessionId;
  final List<Map<String, dynamic>> pages;
  final int rustMicroseconds;
  ReaderLayoutReply._(this.sessionId, this.pages, this.rustMicroseconds);

  ReaderLayoutReply.empty(this.sessionId)
    : pages = const [],
      rustMicroseconds = 0;

  factory ReaderLayoutReply.decode(String encoded) =>
      ReaderLayoutReply.fromMap(jsonDecode(encoded));

  factory ReaderLayoutReply.fromMap(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['schemaVersion'] != 1 ||
        value['sessionId'] == null ||
        (value['sessionId'] is String &&
            (value['sessionId'] as String).isEmpty) ||
        value['pages'] is! List ||
        value['rustMicros'] is! int ||
        (value['rustMicros'] as int) < 0) {
      throw const FormatException('阅读布局返回协议无效');
    }
    final columns = ReaderGlyphColumns.decode(
      value['glyphs'],
      value['textStyles'],
    );
    final pages = <Map<String, dynamic>>[];
    for (final page in value['pages'] as List) {
      if (page is! Map<String, dynamic>) {
        throw const FormatException('阅读布局页面不是对象');
      }
      page['elements'] = ReaderElementDataList.decode(
        page['elements'],
        columns,
      );
      pages.add(Map.unmodifiable(page));
    }
    return ReaderLayoutReply._(
      value['sessionId'] as Object,
      List.unmodifiable(pages),
      value['rustMicros'] as int,
    );
  }
}
