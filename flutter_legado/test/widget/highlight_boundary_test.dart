import 'package:flutter_legado/src/data/repositories/mock_highlight_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_highlight_rule_repository.dart';
import 'package:flutter_legado/src/domain/models/book_highlight.dart';
import 'package:flutter_legado/src/domain/models/highlight_rule.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/highlight_repository_provider.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/screens/highlight_rules_screen.dart';
import 'package:flutter_legado/src/screens/toc_screen.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('规则编辑与启停保留原排序和超时，独立仓储无需根接口', (tester) async {
    var nextId = 10;
    final repository = MockHighlightRuleRepository(nextId: () => nextId++);
    await repository.highlightRuleSave(
      const HighlightRule(
        id: 9,
        name: '可编辑规则',
        pattern: '词',
        isEnabled: false,
        sortOrder: 27,
        timeoutMillisecond: 150,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWith((_) => throw StateError('不应创建根接口')),
          highlightRuleRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: HighlightRulesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('可编辑规则'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '修改名称');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final edited = (await repository.highlightRuleList()).single;
    expect(edited.name, '修改名称');
    expect(edited.id, 9);
    expect(edited.isEnabled, isFalse);
    expect(edited.sortOrder, 27);
    expect(edited.timeoutMillisecond, 150);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final enabled = (await repository.highlightRuleList()).single;
    expect(enabled.isEnabled, isTrue);
    expect(enabled.sortOrder, 27);
    expect(enabled.timeoutMillisecond, 150);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除返回false展示错误且保留规则', (tester) async {
    final repository = HighlightRuleRepositoryMock();
    when(() => repository.highlightRuleList()).thenAnswer(
      (_) async => [const HighlightRule(id: 9, name: '保留规则', pattern: '词')],
    );
    when(() => repository.highlightRuleDelete(id: 9))
        .thenAnswer((_) async => false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWith((_) => throw StateError('不应创建根接口')),
          highlightRuleRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: HighlightRulesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Symbols.delete_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(find.text('保留规则'), findsOneWidget);
    expect(find.textContaining('删除高亮规则失败'), findsOneWidget);
    verify(() => repository.highlightRuleList()).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('目录标注加载后按笔记搜索，点击仍返回对应章节', (tester) async {
    final repository = MockHighlightRepository();
    await repository.highlightAdd(
      const BookHighlight(
        time: 1,
        bookUrl: 'local://novel',
        chapterIndex: 2,
        chapterName: '第三章',
        bookText: '标注原文',
        note: '目标笔记',
      ),
    );
    await repository.highlightAdd(
      const BookHighlight(
        time: 2,
        bookUrl: 'local://novel',
        chapterIndex: 3,
        chapterName: '第四章',
        bookText: '另一处原文',
        note: '其他笔记',
      ),
    );
    int? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWithValue(MockBookApi()),
          highlightRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<int>(
                    MaterialPageRoute(
                      builder: (_) => const TocScreen(
                        book: Book(
                          bookUrl: 'local://novel',
                          origin: BookType.localTag,
                          name: '标注书',
                          author: '作者',
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('打开目录'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标注'));
    await tester.pumpAndSettle();
    expect(find.text('标注原文'), findsOneWidget);
    expect(find.text('另一处原文'), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.search_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '目标笔记');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('标注原文'), findsOneWidget);
    expect(find.text('另一处原文'), findsNothing);
    await tester.tap(find.text('标注原文'));
    await tester.pumpAndSettle();
    expect(result, 2);
    expect(find.text('打开目录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
