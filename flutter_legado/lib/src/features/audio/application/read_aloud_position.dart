import 'package:flutter/foundation.dart';

/// 朗读位置只使用章节原文的 UTF-16 坐标，不使用页号或显示文本累加值。
@immutable
class ReadAloudPosition {
  const ReadAloudPosition({
    required this.bookUrl,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.paragraphStart,
    required this.paragraphEnd,
    required this.offset,
    required this.session,
  });

  final String bookUrl;
  final int chapterIndex;
  final int paragraphIndex;
  final int paragraphStart;
  final int paragraphEnd;
  final int offset;
  final int session;

  @override
  bool operator ==(Object other) =>
      other is ReadAloudPosition &&
      bookUrl == other.bookUrl &&
      chapterIndex == other.chapterIndex &&
      paragraphIndex == other.paragraphIndex &&
      paragraphStart == other.paragraphStart &&
      paragraphEnd == other.paragraphEnd &&
      offset == other.offset &&
      session == other.session;

  @override
  int get hashCode => Object.hash(
    bookUrl,
    chapterIndex,
    paragraphIndex,
    paragraphStart,
    paragraphEnd,
    offset,
    session,
  );
}
