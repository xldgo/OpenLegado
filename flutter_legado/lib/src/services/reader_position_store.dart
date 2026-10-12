import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 带坐标版本的原文锚点；页码不参与持久化位置的判定。
class ReaderSourceAnchor {
  final String chapterId;
  final int chapterIndex;
  final int sourceOffset;

  const ReaderSourceAnchor({
    required this.chapterId,
    required this.chapterIndex,
    required this.sourceOffset,
  });

  Map<String, Object> toJson() => {
    'version': 2,
    'coordinate': 'utf16',
    'chapterId': chapterId,
    'chapterIndex': chapterIndex,
    'sourceOffset': sourceOffset,
  };

  static ReaderSourceAnchor? fromJson(Object? raw) {
    if (raw case {
      'version': 2,
      'coordinate': 'utf16',
      'chapterId': String id,
      'chapterIndex': int index,
      'sourceOffset': int offset,
    }) {
      if (index >= 0 && offset >= 0) {
        return ReaderSourceAnchor(
          chapterId: id,
          chapterIndex: index,
          sourceOffset: offset,
        );
      }
    }
    return null;
  }
}

/// 只恢复有效原文锚点；缺失或损坏的记录从保存章节的开头继续。
class ReaderPositionStore {
  static String keyFor(String bookUrl) => 'reader_source_anchor_v2:$bookUrl';

  Future<ReaderSourceAnchor?> read(
    String bookUrl, {
    required int chapterIndex,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(bookUrl));
    if (raw == null) return null;
    try {
      final anchor = ReaderSourceAnchor.fromJson(jsonDecode(raw));
      return anchor?.chapterIndex == chapterIndex ? anchor : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(String bookUrl, ReaderSourceAnchor anchor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFor(bookUrl), jsonEncode(anchor.toJson()));
  }

  Future<void> clear(String bookUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFor(bookUrl));
  }
}
