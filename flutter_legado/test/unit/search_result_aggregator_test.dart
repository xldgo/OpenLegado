import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/services/search_result_aggregator.dart';
import 'package:flutter_legado/src/models/models.dart';

SearchResult result(
  String name,
  String author,
  String origin, {
  String? kind,
  bool read = false,
}) => SearchResult(
  book: Book(
    name: name,
    author: author,
    origin: origin,
    kind: kind,
    bookUrl: '$origin/book',
  ),
  sourceName: origin,
  hasReadRecord: read,
);

void main() {
  test('固定跨端夹具在任意批次切分下保留字段和结果顺序', () {
    final fixture = jsonDecode(
      File(
        '../rust/legado-ffi/tests/fixtures/search_aggregate/cross_source_merge.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final entry
        in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
      final books = (entry['books'] as List).cast<Map<String, dynamic>>();
      final expected = (entry['expected'] as List).cast<Map<String, dynamic>>();
      for (final size in [1, 2, books.length + 1]) {
        final aggregator = SearchResultAggregator(entry['key'] as String);
        for (var from = 0; from < books.length; from += size) {
          final end = (from + size).clamp(0, books.length);
          aggregator.addAll(
            books
                .sublist(from, end)
                .map(
                  (book) => SearchResult.fromSearchBook(
                    SearchBook.fromJson(book),
                    hasReadRecord: book['hasReadRecord'] == true,
                  ),
                ),
          );
          aggregator.snapshot(keepOther: entry['keep_other'] as bool);
        }
        // 空关键词不发起流式搜索，只校验一次性入口原样返回。
        final actual = (entry['key'] as String).isEmpty
            ? applyPrecisionSearch(
                books
                    .map(
                      (book) => SearchResult.fromSearchBook(
                        SearchBook.fromJson(book),
                        hasReadRecord: book['hasReadRecord'] == true,
                      ),
                    )
                    .toList(),
                '',
                keepOther: entry['keep_other'] as bool,
              )
            : aggregator.snapshot(keepOther: entry['keep_other'] as bool);
        expect(
          actual.length,
          expected.length,
          reason: '${entry["id"]} 批次$size',
        );
        for (var i = 0; i < expected.length; i++) {
          final a = actual[i];
          final e = expected[i];
          expect(
            [
              a.book.name,
              a.book.author,
              a.book.origin,
              a.sourceName,
              a.book.bookUrl,
              a.book.kind,
              a.hasReadRecord,
              a.origins.toList(),
            ],
            [
              e['name'],
              e['author'],
              e['origin'],
              e['originName'],
              e['bookUrl'],
              e['kind'],
              e['hasReadRecord'] == true,
              e['origins'],
            ],
            reason: '${entry["id"]} 第$i条 批次$size',
          );
        }
      }
    }
  });

  test('四桶优先级与桶内来源数降序、首次到达平局保持', () {
    final aggregator = SearchResultAggregator('目标');
    aggregator.addAll([
      result('其他', '作者', 'a'),
      result('包含目标', '作者', 'b'),
      result('标签', '作者', 'c', kind: '目标'),
      result('目标', '作者', 'd'),
      result('包含目标', '作者', 'e'),
      result('另含目标', '作者', 'f'),
      result('第三目标', '作者', 'g'),
    ]);
    expect(aggregator.snapshot().map((r) => r.book.name), [
      '目标',
      '标签',
      '包含目标',
      '另含目标',
      '第三目标',
      '其他',
    ]);
  });

  test('原始三元组首到去重，重复记录不改变分桶或补读过标记', () {
    final aggregator = SearchResultAggregator('目标');
    aggregator.addAll([result('甲', '作者', 'a', kind: '目标')]);
    aggregator.addAll([result('甲', '作者', 'a', kind: '其他', read: true)]);
    expect(aggregator.snapshot(), hasLength(1));
    expect(aggregator.snapshot().single.book.kind, '目标');
    expect(aggregator.snapshot().single.hasReadRecord, isFalse);
  });

  test('清洗后双键归并但保留首条元数据，来源有序和已读跨源 OR', () {
    final aggregator = SearchResultAggregator('书');
    aggregator.addAll([result('书', '作者：甲', 'first')]);
    aggregator.addAll([result('书', '甲', 'second', read: true)]);
    final merged = aggregator.snapshot().single;
    expect(merged.book.name, '书');
    expect(merged.book.author, '甲');
    expect(merged.book.bookUrl, 'first/book');
    expect(merged.sourceName, 'first');
    expect(merged.origins.toList(), ['first', 'second']);
    expect(merged.hasReadRecord, isTrue);
  });

  test('追加同书来源只改变新快照，不修改此前展示快照', () {
    final aggregator = SearchResultAggregator('书');
    aggregator.addAll([result('书', '甲', 'a')]);
    final before = aggregator.snapshot();
    aggregator.addAll([result('书', '甲', 'b')]);
    expect(before.single.origins.toList(), ['a']);
    expect(aggregator.snapshot().single.origins.toList(), ['a', 'b']);
    before.clear();
    expect(aggregator.snapshot(), hasLength(1));
  });

  test('精确快照隐藏 other 后可再次显示，不删除底层桶', () {
    final aggregator = SearchResultAggregator('目标');
    aggregator.addAll([result('目标', '甲', 'a'), result('其他', '乙', 'b')]);
    expect(aggregator.snapshot(keepOther: false).map((r) => r.book.name), [
      '目标',
    ]);
    expect(aggregator.snapshot().map((r) => r.book.name), ['目标', '其他']);
  });

  test('新查询重置桶、预去重及平局顺序，续页只追加', () {
    final aggregator = SearchResultAggregator('甲');
    final first = result('甲', '作者', 'a');
    final second = result('乙', '作者', 'b');
    aggregator.addAll([first]);
    aggregator.addAll([first, second]);
    expect(aggregator.snapshot(), hasLength(2));
    aggregator.reset(keyword: '乙');
    expect(aggregator.snapshot(), isEmpty);
    aggregator.addAll([first, second]);
    expect(aggregator.snapshot().map((r) => r.book.name), ['乙', '甲']);
  });

  test('空关键词一次性入口原样返回列表，不清洗不去重', () {
    final values = [result(' 甲 ', '作者：乙', 'a'), result(' 甲 ', '作者：乙', 'a')];
    expect(applyPrecisionSearch(values, '', keepOther: false), same(values));
    expect(values.first.book.name, ' 甲 ');
  });
}
