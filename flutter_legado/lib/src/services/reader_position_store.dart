import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 带坐标版本的原文锚点；旧页码只用于核对历史数据库进度是否已被替换。
class ReaderSourceAnchor {
  final String chapterId;
  final int chapterIndex;
  final int sourceOffset;
  final int legacyPageIndex;

  const ReaderSourceAnchor({
    required this.chapterId,
    required this.chapterIndex,
    required this.sourceOffset,
    required this.legacyPageIndex,
  });

  Map<String, Object> toJson() => {
    'version': 2,
    'coordinate': 'utf16',
    'chapterId': chapterId,
    'chapterIndex': chapterIndex,
    'sourceOffset': sourceOffset,
    'legacyPageIndex': legacyPageIndex,
  };

  static ReaderSourceAnchor? fromJson(Object? raw) {
    if (raw case {
      'version': 2,
      'coordinate': 'utf16',
      'chapterId': String id,
      'chapterIndex': int index,
      'sourceOffset': int offset,
      'legacyPageIndex': int page,
    }) {
      if (index >= 0 && offset >= 0 && page >= 0) {
        return ReaderSourceAnchor(
          chapterId: id,
          chapterIndex: index,
          sourceOffset: offset,
          legacyPageIndex: page,
        );
      }
    }
    return null;
  }
}

/// 保留旧数据库字段与云端协议；新增记录以原文位置为权威，避免误读历史页码。
class ReaderPositionStore {
  static String keyFor(String bookUrl) => 'reader_source_anchor_v2:$bookUrl';

  Future<ReaderSourceAnchor?> read(
    String bookUrl, {
    required int chapterIndex,
    required int legacyPageIndex,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(bookUrl));
    if (raw == null) return null;
    try {
      final anchor = ReaderSourceAnchor.fromJson(jsonDecode(raw));
      // 目录跳转或外部进度改变后，旧锚点不应盖过新的进度。
      return anchor?.chapterIndex == chapterIndex &&
              anchor?.legacyPageIndex == legacyPageIndex
          ? anchor
          : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(String bookUrl, ReaderSourceAnchor anchor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFor(bookUrl), jsonEncode(anchor.toJson()));
  }
}
