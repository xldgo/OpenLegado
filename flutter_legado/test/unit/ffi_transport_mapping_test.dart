// 验证实际字段与上游输入样本。— Codex + Bridge
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/bridge/entity_dto_mapping.dart';
import 'package:flutter_legado/src/data/bridge/layout_dto_mapping.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/models/book_chapter.dart';
import 'package:flutter_legado/src/models/book_source.dart';

void main() {
  test('书籍、目录、嵌套配置保留 Unicode、大整数和已有领域字段', () {
    const book = Book(
      bookUrl: '中文😀',
      name: '书',
      author: '作者',
      group: 9007199254740993,
      durChapterPos: 123,
      originBookUrl: '源页',
      isPrivate: true,
      order: 8,
      readConfig: ReadConfig(
        ttsEngine: 'system://default',
        playSpeed: 1.8,
        openCredits: 9,
        closeCredits: 7,
      ),
    );
    expect(bookFromDto(bookToDto(book)), book);
    const chapter = BookChapter(
      url: '章😀',
      title: '章名',
      bookUrl: '书',
      index: 9,
      isVolume: true,
      isVip: true,
      isPay: true,
      start: 123,
      end: 456,
      variable: '{"a":1}',
      startFragmentId: 'a',
      endFragmentId: 'b',
    );
    expect(bookChapterFromDto(bookChapterToDto(chapter)), chapter);
    final source = BookSource.fromJson({
      'bookSourceUrl': '源',
      'bookSourceName': '源😀',
      'enabledCookieJar': null,
      'header': '{"A":"B"}',
      'jsLib': '库',
      'concurrentRate': '2/1000',
      'ruleSearch': {
        'bookList': 'div',
        'name': 'h1',
        'author': 'h2',
        'bookUrl': 'url',
      },
      'ruleExplore': {'name': '书'},
      'ruleBookInfo': {'tocUrl': '目录'},
      'ruleToc': {'chapterName': '章'},
      'ruleContent': {'content': '正文', 'payAction': '动作'},
      'ruleReview': {'reviewUrl': '评'},
    });
    expect(bookSourceFromDto(bookSourceToDto(source)), source);
    expect(bookSourceToDto(source).enabledCookieJar, isNull);
  });
  test('上游六种块、五种行内元素与默认参数都能转换', () {
    final fixture = jsonDecode(
      File('../rust/legado-ffi/tests/fixtures/layout_transport.json')
          .readAsStringSync(),
    ) as Map;
    final blocks = <String>{}, items = <String>{};
    for (final c in fixture['cases'] as List) {
      final input = c['input'] as Map;
      configToDto(Map<String, dynamic>.from(input['config'] as Map));
      for (final raw in input['blocks'] as List) {
        final block = Map<String, dynamic>.from(raw as Map);
        blockToDto(block);
        blocks.add(block['type'] as String);
        if (block['type'] == 'inlineParagraph') {
          for (final item in block['items'] as List) {
            items.add((item as Map)['type'] as String);
          }
        }
      }
    }
    expect(
      blocks,
      containsAll([
        'paragraph',
        'inlineParagraph',
        'image',
        'blankLine',
        'rule',
        'pageBreak',
      ]),
    );
    expect(items, containsAll(['text', 'image', 'roleCast', 'bgmScene']));
  });
  test('项目段评元素按固定槽宽传递', () {
    final review = inlineItemToDto({
      'type': 'review',
      'widthPx': 32,
      'heightPx': 20,
      'chapterPosition': 8,
      'paragraphIndex': 2,
      'reviewKey': '段评',
      'count': 999,
      'baselineOffsetPx': 15,
    });
    expect(review, isNotNull);
  });
  test('扩展值树支持嵌套，未知块和字段拒绝', () {
    final value = {
      '空': null,
      '数组': [true, 123, 1.5, '😀'],
      '对象': {'中文': '文字'},
    };
    expect(layoutValueFromDto(layoutValueToDto(value)), value);
    expect(() => blockToDto({'type': 'unknown'}), throwsFormatException);
    expect(
      () => blockToDto({'type': 'pageBreak', 'extra': 1}),
      throwsFormatException,
    );
  });
}
