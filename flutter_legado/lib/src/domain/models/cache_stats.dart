/// 章节缓存统计快照，不包含图片、音频及字体文件。— Codex + Bridge
final class CacheStats {
  const CacheStats({
    required this.totalSize,
    required this.bookCount,
    required this.chapterCount,
  });

  final int totalSize;
  final int bookCount;
  final int chapterCount;
}
