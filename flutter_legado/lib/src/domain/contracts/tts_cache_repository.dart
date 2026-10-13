/// 朗读缓存索引与文件租约，不承担播放或合成。— Codex + Bridge
abstract interface class TtsAudioLease {
  Future<void> release();
}

final class TtsCacheContext {
  const TtsCacheContext({
    required this.bookUrl,
    required this.bookName,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.paragraphIndex,
    required this.text,
  });
  final String bookUrl, bookName, chapterTitle, text;
  final int chapterIndex, paragraphIndex;
  Map<String, Object> toJson() => {
    'bookUrl': bookUrl,
    'bookName': bookName,
    'chapterIndex': chapterIndex,
    'chapterTitle': chapterTitle,
    'paragraphIndex': paragraphIndex,
    'text': text,
  };
  factory TtsCacheContext.fromJson(Map<String, dynamic> j) => TtsCacheContext(
    bookUrl: j['bookUrl'] as String,
    bookName: j['bookName'] as String,
    chapterIndex: j['chapterIndex'] as int,
    chapterTitle: j['chapterTitle'] as String,
    paragraphIndex: j['paragraphIndex'] as int,
    text: j['text'] as String,
  );
}

final class TtsCacheEntry {
  const TtsCacheEntry({
    required this.name,
    required this.sizeBytes,
    required this.modifiedAtMs,
    required this.protected,
    required this.contexts,
  });
  final String name;
  final int sizeBytes, modifiedAtMs;
  final bool protected;
  final List<TtsCacheContext> contexts;
}

final class TtsCacheClearResult {
  const TtsCacheClearResult({
    this.removedFiles = 0,
    this.removedBytes = 0,
    this.skippedFiles = 0,
  });
  final int removedFiles, removedBytes, skippedFiles;
}

abstract interface class TtsCacheRepository {
  bool get supportsAudioFiles;
  Future<void> record(String path, TtsCacheContext context);
  Future<List<TtsCacheEntry>> list();
  Future<TtsCacheClearResult> clear({
    String? name,
    int? beforeTimestampMs,
    String? keepBookUrl,
    int? keepChapterIndex,
  });
}
