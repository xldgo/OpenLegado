import '../../models/search_result.dart';

/// 当前查询的纯增量聚合；每条输入只做一次去重、清洗与归并。— Codex + Bridge
final class SearchResultAggregator {
  SearchResultAggregator([this._keyword = '']);

  String _keyword;
  final _bucketEqual = <String, _AggregateGroup>{};
  final _bucketTags = <String, _AggregateGroup>{};
  final _bucketContains = <String, _AggregateGroup>{};
  final _bucketOther = <String, _AggregateGroup>{};
  final _seenKeys = <String>{};
  int _groupSeq = 0;

  /// 新关键词、清空或重开才重置；同查询下一页继续追加。
  void reset({String keyword = ''}) {
    _keyword = keyword;
    _bucketEqual.clear();
    _bucketTags.clear();
    _bucketContains.clear();
    _bucketOther.clear();
    _seenKeys.clear();
    _groupSeq = 0;
  }

  void addAll(Iterable<SearchResult> results) {
    for (final result in results) {
      // 入桶预去重使用原始三元组；不能替换为清洗后的桶内双键。
      final key =
          '${result.book.name}|${result.book.author}|${result.book.origin}';
      if (_seenKeys.add(key)) _addToBuckets(result, _keyword);
    }
  }

  /// 只排序和物化现有桶，不重新清洗或遍历之前的输入批次。
  List<SearchResult> snapshot({bool keepOther = true}) {
    final out = <SearchResult>[];
    void addSorted(Map<String, _AggregateGroup> bucket) {
      if (bucket.isEmpty) return;
      final groups = bucket.values.toList();
      groups.sort((a, b) {
        final byCount = b.result.originsCount.compareTo(a.result.originsCount);
        return byCount != 0 ? byCount : a.seq.compareTo(b.seq);
      });
      out.addAll(groups.map((group) => group.result));
    }

    addSorted(_bucketEqual);
    addSorted(_bucketTags);
    addSorted(_bucketContains);
    if (keepOther) addSorted(_bucketOther);
    return out;
  }

  void _addToBuckets(SearchResult result, String keyword) {
    final name = formatBookName(result.book.name);
    final author = formatBookAuthor(result.book.author);
    // 桶内按清洗后书名、作者归并，来源仍有序累加。
    final mapKey = '$name\u0000$author';
    final normalized =
        (name != result.book.name || author != result.book.author)
        ? result.copyWith(
            book: result.book.copyWith(name: name, author: author),
          )
        : result;
    final kind = result.book.kind ?? '';
    final bucket = name == keyword || author == keyword
        ? _bucketEqual
        : kind.contains(keyword)
        ? _bucketTags
        : name.contains(keyword) || author.contains(keyword)
        ? _bucketContains
        : _bucketOther;
    final existing = bucket[mapKey];
    if (existing == null) {
      bucket[mapKey] = _AggregateGroup(
        _groupSeq++,
        normalized.copyWith(origins: {...normalized.effectiveOrigins}),
      );
    } else {
      existing.result = existing.result.withAddedOrigin(normalized);
    }
  }
}

/// 一次性结果使用同一聚合实现；空关键词保留原列表与原始字段。
List<SearchResult> applyPrecisionSearch(
  List<SearchResult> results,
  String key, {
  bool keepOther = true,
}) {
  if (key.isEmpty) return results;
  final aggregator = SearchResultAggregator(key)..addAll(results);
  return aggregator.snapshot(keepOther: keepOther);
}

final class _AggregateGroup {
  _AggregateGroup(this.seq, this.result);
  final int seq;
  SearchResult result;
}

/// 书名清洗（对齐原版 `BookHelp.formatBookName` / `AppPattern.nameRegex`）
String formatBookName(String name) {
  return name.replaceAll(RegExp(r'\s+作\s*者.*|\s+\S+\s+著'), '').trim();
}

/// 作者清洗（对齐原版 `BookHelp.formatBookAuthor` / `AppPattern.authorRegex`）
String formatBookAuthor(String author) {
  return author.replaceAll(RegExp(r'^\s*作\s*者[:：\s]+|\s+著'), '').trim();
}
