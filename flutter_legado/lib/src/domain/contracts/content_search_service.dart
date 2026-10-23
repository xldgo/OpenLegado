/// 正文命中与摘要位置均为UTF-16；UI不重新执行正则。— Codex + Bridge
final class ContentSearchHit {
  const ContentSearchHit({
    required this.sourceStart,
    required this.sourceEnd,
    required this.snippet,
    required this.highlightStart,
    required this.highlightEnd,
  });
  final int sourceStart, sourceEnd;
  final String snippet;
  final int highlightStart, highlightEnd;
}

enum ContentSearchScope { current, cached, network }

/// 每次事件只携带一章的新增结果，不重复返回历史命中。— Codex + Bridge
final class ContentSearchBatch {
  const ContentSearchBatch({
    this.chapterIndex,
    this.chapterTitle = '',
    this.hits = const [],
    required this.scanned,
    required this.total,
    this.error,
    this.limitReached = false,
  });
  final int? chapterIndex;
  final String chapterTitle;
  final List<ContentSearchHit> hits;
  final int scanned, total;
  final String? error;
  final bool limitReached;
}

abstract interface class ContentSearchService {
  /// 订阅取消必须结束本次原生任务，不影响其他执行实例。
  Stream<ContentSearchBatch> search({
    required String bookUrl,
    required String query,
    required bool useRegex,
    required bool useReplace,
    required ContentSearchScope scope,
    required int currentChapterIndex,
  });
}
