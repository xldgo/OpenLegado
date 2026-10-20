import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/data/repositories/mock_highlight_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_highlight_rule_repository.dart';
import 'package:flutter_legado/src/domain/models/book_highlight.dart';
import 'package:flutter_legado/src/domain/models/highlight_rule.dart';
import 'package:flutter_legado/src/providers/highlight_repository_provider.dart';
import 'package:flutter_legado/src/features/rules/application/highlight_rules/highlight_rules_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  test('同一Mock装配共享标注增改删查，返回独立列表且不混入其他书', () async {
    final api = MockBookApi();
    final repository = api.highlightRepository;
    const item = BookHighlight(
      bookUrl: 'book://1',
      bookName: '小说',
      chapterIndex: 2,
      chapterPos: 12,
      chapterPosEnd: 15,
      chapterName: '章节名称',
      bookText: '原文',
      note: '笔记',
      layoutTitleLength: 0,
      style: '{}',
    );
    final time = await repository.highlightAdd(item);
    final other = await repository.highlightAdd(
      const BookHighlight(bookUrl: 'book://2'),
    );
    expect(time, greaterThan(0));
    expect(other, isNot(time));
    expect(
      (await api.highlightRepository.highlightListByBook(bookUrl: 'book://1'))
          .single
          .toJson(),
      {...item.toJson(), 'time': time},
    );
    final list = await repository.highlightListAll();
    list.clear();
    expect(await repository.highlightListAll(), hasLength(2));
    await repository.highlightAdd(item.copyWith(time: time, note: '修改'));
    expect(
      (await repository.highlightListByChapter(
        bookUrl: 'book://1',
        chapterIndex: 2,
      )).single.note,
      '修改',
    );
    expect(
      (await repository.highlightSearch(keyword: '章节名称')).single.time,
      time,
    );
    expect((await repository.highlightSearch(keyword: '修改')).single.time, time);
    expect(await repository.highlightDelete(time: other), isTrue);
    expect(await repository.highlightDelete(time: other), isFalse);
    expect(await repository.highlightDeleteByBook(bookUrl: 'book://1'), 1);
    expect(await repository.highlightListAll(), isEmpty);
  });

  test('Mock标注按章节与原文位置排序，时间较新不会排到较后章节', () async {
    final repository = MockHighlightRepository();
    await repository.highlightAdd(
      const BookHighlight(time: 1, bookUrl: 'book', chapterIndex: 2),
    );
    await repository.highlightAdd(
      const BookHighlight(
        time: 3,
        bookUrl: 'book',
        chapterIndex: 1,
        chapterPos: 20,
      ),
    );
    await repository.highlightAdd(
      const BookHighlight(
        time: 4,
        bookUrl: 'book',
        chapterIndex: 1,
        chapterPos: 10,
      ),
    );
    expect(
      (await repository.highlightListByBook(bookUrl: 'book'))
          .map((h) => h.time),
      [4, 3, 1],
    );
  });

  test('规则共享配置，保存启停保留排序超时，作用域过滤和删除一致', () async {
    final api = MockBookApi();
    final repository = api.highlightRuleRepository;
    final id = await repository.highlightRuleSave(
      const HighlightRule(
        name: '限定',
        pattern: '词',
        scope: '小说|书源',
        sortOrder: 10,
        timeoutMillisecond: 150,
      ),
    );
    final global = await repository.highlightRuleSave(
      const HighlightRule(name: '全局', sortOrder: 1),
    );
    final all = await api.highlightRuleRepository.highlightRuleList();
    expect(all.map((r) => r.id), [global, id]);
    expect(
      (await repository.highlightRuleFindEnabled(
        bookName: '小说',
        origin: '',
      )).map((r) => r.id),
      [global, id],
    );
    expect(
      (await repository.highlightRuleFindEnabled(
        bookName: '',
        origin: '',
      )).map((r) => r.id),
      [global],
    );
    await repository.highlightRuleSave(all.last.copyWith(isEnabled: false));
    expect(
      (await repository.highlightRuleFindEnabled(
        bookName: '小说',
        origin: '书源',
      )).single.id,
      global,
    );
    final disabled = (await repository.highlightRuleList()).last;
    expect(disabled.timeoutMillisecond, 150);
    expect(disabled.sortOrder, 10);
    expect(await repository.highlightRuleDelete(id: id), isTrue);
    expect(await repository.highlightRuleDelete(id: id), isFalse);
  });

  test('两个Provider支持注入并跟随窄依赖替换', () async {
    var nextId = 40;
    final highlights = MockHighlightRepository();
    final rules = MockHighlightRuleRepository(nextId: () => nextId++);
    final first = MockBookApi(
      highlightRepository: highlights,
      highlightRuleRepository: rules,
    );
    final second = MockBookApi();
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        highlightRepositoryProvider.overrideWithValue(
          first.highlightRepository,
        ),
        highlightRuleRepositoryProvider.overrideWithValue(
          first.highlightRuleRepository,
        ),
      ]),
    );
    addTearDown(container.dispose);
    expect(container.read(highlightRepositoryProvider), same(highlights));
    expect(container.read(highlightRuleRepositoryProvider), same(rules));
    expect(
      await container
          .read(highlightRuleRepositoryProvider)
          .highlightRuleSave(const HighlightRule()),
      40,
    );
    container.updateOverrides(
      mergeTestOverrides([
        highlightRepositoryProvider.overrideWithValue(
          second.highlightRepository,
        ),
        highlightRuleRepositoryProvider.overrideWithValue(
          second.highlightRuleRepository,
        ),
      ]),
    );
    await container.pump();
    expect(
      container.read(highlightRepositoryProvider),
      same(second.highlightRepository),
    );
    expect(
      container.read(highlightRuleRepositoryProvider),
      same(second.highlightRuleRepository),
    );
    expect(
      await container.read(highlightRuleRepositoryProvider).highlightRuleList(),
      isEmpty,
    );
  });

  group('规则Notifier独立注入', () {
    late HighlightRuleRepositoryMock repository;
    late ProviderContainer container;
    late HighlightRulesNotifier notifier;
    const rule = HighlightRule(
      id: 9,
      name: '规则',
      pattern: '词',
      sortOrder: 27,
      timeoutMillisecond: 150,
    );
    HighlightRulesState state() =>
        container.read(highlightRulesNotifierProvider);

    setUp(() {
      repository = HighlightRuleRepositoryMock();
      when(() => repository.highlightRuleList())
          .thenAnswer((_) async => [rule]);
      container = ProviderContainer(
        overrides: [
          highlightRuleRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      notifier = container.read(highlightRulesNotifierProvider.notifier);
    });

    test('读取失败保留上次规则，重试成功清除错误', () async {
      await notifier.load();
      when(() => repository.highlightRuleList()).thenThrow(StateError('读取失败'));
      await notifier.load();
      expect(state().rules, [rule]);
      expect(state().error, contains('读取失败'));
      expect(state().isLoading, isFalse);
      when(() => repository.highlightRuleList()).thenAnswer((_) async => []);
      await notifier.load();
      expect(state().rules, isEmpty);
      expect(state().error, isNull);
    });

    test('切换启用状态保存同一规则的排序超时并刷新', () async {
      when(() => repository.highlightRuleSave(any()))
          .thenAnswer((_) async => 9);
      await notifier.toggleEnabled(rule, false);
      final saved =
          verify(() => repository.highlightRuleSave(captureAny()))
                  .captured
                  .single
              as HighlightRule;
      expect(saved.isEnabled, isFalse);
      expect(saved.id, 9);
      expect(saved.sortOrder, 27);
      expect(saved.timeoutMillisecond, 150);
      verify(() => repository.highlightRuleList()).called(1);
    });

    test('保存异常保留规则且不刷新', () async {
      await notifier.load();
      clearInteractions(repository);
      when(() => repository.highlightRuleSave(any()))
          .thenThrow(StateError('保存失败'));
      await notifier.saveRule(rule.copyWith(name: '修改'));
      expect(state().rules, [rule]);
      expect(state().error, contains('保存失败'));
      verifyNever(() => repository.highlightRuleList());
    });

    test('返回无效主键不报告保存成功', () async {
      when(() => repository.highlightRuleSave(any()))
          .thenAnswer((_) async => 0);
      await notifier.saveRule(rule);
      expect(state().error, contains('保存高亮规则失败'));
      verifyNever(() => repository.highlightRuleList());
    });

    test('删除返回false保留规则且不刷新', () async {
      await notifier.load();
      clearInteractions(repository);
      when(() => repository.highlightRuleDelete(id: 9))
          .thenAnswer((_) async => false);
      await notifier.deleteRule(rule);
      expect(state().rules, [rule]);
      expect(state().error, contains('删除高亮规则失败'));
      verifyNever(() => repository.highlightRuleList());
    });
  });
}
