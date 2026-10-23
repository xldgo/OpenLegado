import 'dart:convert';
import 'dart:io';

import 'package:flutter_legado/src/domain/contracts/search_aggregation_service.dart';
import 'package:flutter_legado/src/models/models.dart';

/// 录制的输入/输出快照只用于编排测试，不实现聚合或清洗算法。
class FixtureSearchAggregationService implements SearchAggregationService {
  @override
  SearchAggregationSession open(String keyword) =>
      FixtureSearchAggregationSession(keyword);
}

class FixtureSearchAggregationSession implements SearchAggregationSession {
  FixtureSearchAggregationSession(this.keyword);
  final String keyword;
  final inputs = <SearchResult>[];
  static final cases = (jsonDecode(
    File('test/fixtures/search_aggregation_cases.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();
  static Map<String, Object?> encode(SearchResult r) => {
    'book': r.book.toJson(),
    'sourceName': r.sourceName,
    'origins': r.origins.toList(),
    'hasReadRecord': r.hasReadRecord,
  };
  @override
  Future<void> addAll(List<SearchResult> books) async {
    inputs.addAll(books);
  }

  @override
  Future<List<SearchResult>> snapshot({bool keepOther = true}) async {
    if (inputs.isEmpty) return [];
    final key = jsonEncode(inputs.map(encode).toList());
    final matching = cases.where(
      (c) =>
          c['keyword'] == keyword &&
          c['keepOther'] == keepOther &&
          jsonEncode(c['inputs']) == key,
    );
    if (matching.isEmpty) {
      throw StateError(
        '缺少搜索聚合夹具: $keyword / ${inputs.map((r) => r.book.name).toList()} / keepOther=$keepOther',
      );
    }
    return [
      for (final r in matching.first['output'] as List)
        SearchResult(
          book: Book.fromJson(r['book'] as Map<String, dynamic>),
          sourceName: r['sourceName'] as String,
          origins: (r['origins'] as List).cast<String>().toSet(),
          hasReadRecord: r['hasReadRecord'] as bool,
        ),
    ];
  }

  @override
  Future<void> close() async {}
}
