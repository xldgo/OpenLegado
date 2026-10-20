/// 正文搜索与结果高亮共享的UTF-16命中区间。— Codex + UI
List<({int start, int end})> findContentHits(
  String content,
  String query, {
  required bool useRegex,
  int maxHits = 50,
}) {
  final hits = <({int start, int end})>[];
  if (query.isEmpty) return hits;
  if (useRegex) {
    try {
      for (final m in RegExp(query).allMatches(content)) {
        hits.add((start: m.start, end: m.end));
        if (hits.length >= maxHits) break;
      }
    } catch (_) {
      return hits;
    }
    return hits;
  }
  final lower = content.toLowerCase();
  final lowerQuery = query.toLowerCase();
  var from = 0;
  var found = lower.indexOf(lowerQuery, from);
  while (found != -1) {
    hits.add((start: found, end: found + query.length));
    if (hits.length >= maxHits) break;
    from = found + query.length;
    found = lower.indexOf(lowerQuery, from);
  }
  return hits;
}
