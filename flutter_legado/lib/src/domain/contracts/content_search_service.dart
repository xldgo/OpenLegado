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

abstract interface class ContentSearchService {
  /// 无效正则/空查询返回null；传输和执行错误仍上抛。
  Future<ContentSearchMatcher?> open(String query, {required bool useRegex});
}

abstract interface class ContentSearchMatcher {
  Future<List<ContentSearchHit>> search(String content);
  void close();
}
