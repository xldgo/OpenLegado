import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/reader_source_anchor.dart';

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
