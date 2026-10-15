import 'dart:convert';

import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_highlight_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_highlight_rule_repository.dart';
import 'package:flutter_legado/src/domain/models/book_highlight.dart';
import 'package:flutter_legado/src/domain/models/highlight_rule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const highlights = RustHighlightRepository();
  const rules = RustHighlightRuleRepository();
  const highlight = {
    'time': 17,
    'bookUrl': 'book://1',
    'chapterUrl': 'chapter://2',
    'bookName': '小说',
    'bookAuthor': '作者',
    'chapterIndex': 2,
    'chapterPos': 12,
    'chapterPosEnd': 19,
    'layoutTitleLength': 0,
    'chapterName': '第三章',
    'bookText': '选中的😀正文',
    'style': '{"type":"background","color":"#FFFFE082"}',
    'note': '笔记',
  };
  const rule = {
    'id': 9,
    'name': '术语',
    'pattern': '修炼',
    'isRegex': false,
    'applyToTitle': true,
    'scope': '小说',
    'isEnabled': false,
    'style': '{"textColor":-65536}',
    'sortOrder': 27,
    'timeoutMillisecond': 150,
  };

  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('按书、章、关键词和全部查询保留原参数、顺序及标注完整字段', () async {
    final payload = jsonEncode([
      highlight,
      {...highlight, 'time': 11},
    ]);
    when(() => bridge.crateFfiFfiHighlightListByBook(bookUrl: 'book://1'))
        .thenAnswer((_) async => payload);
    when(
      () => bridge.crateFfiFfiHighlightListByChapter(
        bookUrl: 'book://1',
        chapterIndex: 2,
      ),
    ).thenAnswer((_) async => payload);
    when(() => bridge.crateFfiFfiHighlightSearch(keyword: '正文'))
        .thenAnswer((_) async => payload);
    when(() => bridge.crateFfiFfiHighlightListAll())
        .thenAnswer((_) async => payload);
    for (final items in [
      await highlights.highlightListByBook(bookUrl: 'book://1'),
      await highlights.highlightListByChapter(
        bookUrl: 'book://1',
        chapterIndex: 2,
      ),
      await highlights.highlightSearch(keyword: '正文'),
      await highlights.highlightListAll(),
    ]) {
      expect(items.map((value) => value.time), [17, 11]);
      expect(items.first.toJson(), highlight);
    }
    verify(() => bridge.crateFfiFfiHighlightListByBook(bookUrl: 'book://1'))
        .called(1);
    verify(
      () => bridge.crateFfiFfiHighlightListByChapter(
        bookUrl: 'book://1',
        chapterIndex: 2,
      ),
    ).called(1);
    verify(() => bridge.crateFfiFfiHighlightSearch(keyword: '正文')).called(1);
    verify(() => bridge.crateFfiFfiHighlightListAll()).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('标注保存编码原文范围、样式和笔记，返回实际主键', () async {
    when(
      () => bridge.crateFfiFfiHighlightAdd(
        highlightJson: any(named: 'highlightJson'),
      ),
    ).thenAnswer((_) async => 21);
    expect(
      await highlights.highlightAdd(BookHighlight.fromJson(highlight)),
      21,
    );
    final encoded =
        verify(
              () => bridge.crateFfiFfiHighlightAdd(
                highlightJson: captureAny(named: 'highlightJson'),
              ),
            ).captured.single
            as String;
    expect(jsonDecode(encoded), highlight);
  });

  test('删除保留false和数量，不另外清空或重读列表', () async {
    when(() => bridge.crateFfiFfiHighlightDelete(time: 17))
        .thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiHighlightDeleteByBook(bookUrl: 'book://1'))
        .thenAnswer((_) async => 3);
    when(() => bridge.crateFfiFfiHighlightRuleDelete(id: 9))
        .thenAnswer((_) async => false);
    expect(await highlights.highlightDelete(time: 17), isFalse);
    expect(await highlights.highlightDeleteByBook(bookUrl: 'book://1'), 3);
    expect(await rules.highlightRuleDelete(id: 9), isFalse);
    verify(() => bridge.crateFfiFfiHighlightDelete(time: 17)).called(1);
    verify(() => bridge.crateFfiFfiHighlightDeleteByBook(bookUrl: 'book://1'))
        .called(1);
    verify(() => bridge.crateFfiFfiHighlightRuleDelete(id: 9)).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('规则列表及书籍适用查询保留顺序、排序和超时，启停后保存不丢字段', () async {
    when(() => bridge.crateFfiFfiHighlightRuleList()).thenAnswer(
      (_) async => jsonEncode([
        rule,
        {...rule, 'id': 4},
      ]),
    );
    when(
      () => bridge.crateFfiFfiHighlightRuleFindEnabled(
        bookName: '小说',
        origin: '书源',
      ),
    ).thenAnswer((_) async => jsonEncode([rule]));
    when(
      () =>
          bridge.crateFfiFfiHighlightRuleSave(ruleJson: any(named: 'ruleJson')),
    ).thenAnswer((_) async => 9);
    final all = await rules.highlightRuleList();
    expect(all.map((value) => value.id), [9, 4]);
    expect(all.first.toJson(), rule);
    final enabled = await rules.highlightRuleFindEnabled(
      bookName: '小说',
      origin: '书源',
    );
    expect(enabled.single.toJson(), rule);
    expect(
      await rules.highlightRuleSave(all.first.copyWith(isEnabled: true)),
      9,
    );
    final encoded =
        verify(
              () => bridge.crateFfiFfiHighlightRuleSave(
                ruleJson: captureAny(named: 'ruleJson'),
              ),
            ).captured.single
            as String;
    expect(jsonDecode(encoded), {...rule, 'isEnabled': true});
    verify(
      () => bridge.crateFfiFfiHighlightRuleFindEnabled(
        bookName: '小说',
        origin: '书源',
      ),
    ).called(1);
  });

  test('缺省值沿用Rust模型，未知标题长度保持-1', () {
    final item = BookHighlight.fromJson({'time': 17});
    expect(item.layoutTitleLength, -1);
    expect(item.note, '');
    final configured = HighlightRule.fromJson({});
    expect(configured.sortOrder, 0);
    expect(configured.timeoutMillisecond, 3000);
    expect(configured.isEnabled, isTrue);
    expect(configured.copyWith(name: '修改').timeoutMillisecond, 3000);
  });

  test('合法空数组保留空结果', () async {
    when(() => bridge.crateFfiFfiHighlightListAll())
        .thenAnswer((_) async => '[]');
    when(() => bridge.crateFfiFfiHighlightRuleList())
        .thenAnswer((_) async => '[]');
    expect(await highlights.highlightListAll(), isEmpty);
    expect(await rules.highlightRuleList(), isEmpty);
  });

  for (final payload in ['invalid', '{}', 'null', '[null]', '[1]']) {
    test('查询拒绝损坏JSON或条目：$payload', () async {
      when(() => bridge.crateFfiFfiHighlightListAll())
          .thenAnswer((_) async => payload);
      when(() => bridge.crateFfiFfiHighlightRuleList())
          .thenAnswer((_) async => payload);
      await expectLater(highlights.highlightListAll(), throwsFormatException);
      await expectLater(rules.highlightRuleList(), throwsFormatException);
    });
  }

  test('拒绝字段类型错误，不当作无标注或无规则', () async {
    when(() => bridge.crateFfiFfiHighlightListAll()).thenAnswer(
      (_) async => jsonEncode([
        {...highlight, 'chapterPos': '12'},
      ]),
    );
    when(() => bridge.crateFfiFfiHighlightRuleList()).thenAnswer(
      (_) async => jsonEncode([
        {...rule, 'sortOrder': '27'},
      ]),
    );
    await expectLater(highlights.highlightListAll(), throwsFormatException);
    await expectLater(rules.highlightRuleList(), throwsFormatException);
  });

  test('保存未返回有效主键时失败', () async {
    when(
      () => bridge.crateFfiFfiHighlightAdd(
        highlightJson: any(named: 'highlightJson'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () =>
          bridge.crateFfiFfiHighlightRuleSave(ruleJson: any(named: 'ruleJson')),
    ).thenAnswer((_) async => 0);
    await expectLater(
      highlights.highlightAdd(const BookHighlight()),
      throwsStateError,
    );
    await expectLater(
      rules.highlightRuleSave(const HighlightRule()),
      throwsStateError,
    );
  });

  test('读取、保存和删除异常原样传出', () async {
    final error = StateError('数据库不可用');
    when(() => bridge.crateFfiFfiHighlightListAll()).thenThrow(error);
    when(
      () => bridge.crateFfiFfiHighlightAdd(
        highlightJson: any(named: 'highlightJson'),
      ),
    ).thenThrow(error);
    when(
      () =>
          bridge.crateFfiFfiHighlightRuleSave(ruleJson: any(named: 'ruleJson')),
    ).thenThrow(error);
    when(() => bridge.crateFfiFfiHighlightRuleDelete(id: 9)).thenThrow(error);
    await expectLater(
      () => highlights.highlightListAll(),
      throwsA(same(error)),
    );
    await expectLater(
      () => highlights.highlightAdd(const BookHighlight()),
      throwsA(same(error)),
    );
    await expectLater(
      () => rules.highlightRuleSave(const HighlightRule()),
      throwsA(same(error)),
    );
    await expectLater(
      () => rules.highlightRuleDelete(id: 9),
      throwsA(same(error)),
    );
  });
}
