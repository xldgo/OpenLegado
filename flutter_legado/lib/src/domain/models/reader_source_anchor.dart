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

