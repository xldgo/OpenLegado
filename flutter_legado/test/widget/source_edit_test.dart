import '../fixtures/app_test_api.dart';

// 书源编辑页 widget 测试
//
// 验证 Phase 5.1 书源编辑表单（对标 Android BookSourceEditActivity）：
// - 基本/搜索/发现/详情/目录/正文六个页签，设置与段评归入基本和正文
// - 各分组的字段与设置开关可见
// - 必填校验（书源名称/URL）与保存创建
// - 编辑模式回填发现/详情/评论规则
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/book_sources/book_sources.dart';

import '../mocks/mocks.dart';

void main() {
  late MockRustApi mockApi;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbacks();
  });

  setUp(() {
    mockApi = MockRustApi();
    when(() => mockApi.bookSourceRepository.getBookSources())
        .thenAnswer((_) async => []);
    container = ProviderContainer(
      overrides: mergeTestOverrides([...mockApi.overrides]),
    );
    addTearDown(container.dispose);
  });

  /// 在底层页面上 push 书源编辑页，便于验证保存后的返回行为
  Future<void> pumpEdit(WidgetTester tester, {String? sourceUrl}) async {
    // 超长表单夹具使用明确DPR，避免8000逻辑高被默认3倍缩放为超限位图。
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SourceEditScreen(sourceUrl: sourceUrl),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> selectTab(WidgetTester tester, String label) async {
    final tab = find.widgetWithText(Tab, label);
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  group('SourceEditScreen 页签结构', () {
    testWidgets('新建模式展示六个规则页签，调试保留在顶栏', (tester) async {
      // 加高可视区域，便于后续字段回填检查。
      await tester.binding.setSurfaceSize(const Size(800, 8000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpEdit(tester);

      expect(find.text('新建书源'), findsWidgets);
      for (final title in const ['基本', '搜索', '发现', '详情', '目录', '正文']) {
        expect(
          find.widgetWithText(Tab, title),
          findsOneWidget,
          reason: '应包含「$title」页签',
        );
      }
    });

    testWidgets('顶部设置段展示开关，各分组展示对应字段', (tester) async {
      // 加高可视区域，确保正文页的段评字段可见。
      await tester.binding.setSurfaceSize(const Size(800, 8000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpEdit(tester);

      // 设置段默认收起（优先展示表单字段）；展开后可见开关
      expect(find.text('设置'), findsOneWidget);
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('CookieJar'), findsOneWidget);
      expect(find.text('事件监听'), findsOneWidget);
      expect(find.text('定制按钮'), findsOneWidget);

      await selectTab(tester, '发现');
      expect(find.byKey(const ValueKey('sf_exploreUrl')), findsOneWidget);
      await selectTab(tester, '详情');
      expect(find.byKey(const ValueKey('sf_i_tocUrl')), findsOneWidget);
      expect(find.byKey(const ValueKey('sf_i_canReName')), findsOneWidget);
      await selectTab(tester, '正文');
      expect(
        find.byKey(const ValueKey('sf_r_reviewSummaryUrl')),
        findsOneWidget,
      );
    });
  });

  group('SourceEditScreen 校验与保存', () {
    testWidgets('其他页签保存仍校验必填字段并返回基本', (tester) async {
      await pumpEdit(tester);
      await selectTab(tester, '正文');

      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();

      expect(find.text('请输入源名称（sourceName）'), findsOneWidget);
      expect(find.text('请输入源 URL（sourceUrl）'), findsOneWidget);
      verifyNever(() => mockApi.bookSourceRepository.addBookSource(any()));
    });

    testWidgets('填写名称与 URL 后保存成功创建书源', (tester) async {
      when(() => mockApi.bookSourceRepository.addBookSource(any()))
          .thenAnswer((inv) async => inv.positionalArguments[0] as BookSource);
      await pumpEdit(tester);

      // 标签已上移为常显 Text，字段改以 ValueKey('sf_<field.key>') 稳定定位。
      await tester.enterText(
        find.byKey(const ValueKey('sf_bookSourceName')),
        '测试书源',
      );
      await tester.enterText(
        find.byKey(const ValueKey('sf_bookSourceUrl')),
        'https://test.com',
      );
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();

      expect(find.text('书源已创建'), findsOneWidget);
      final captured =
          verify(() => mockApi.bookSourceRepository.addBookSource(captureAny()))
                  .captured
                  .single
              as BookSource;
      expect(captured.bookSourceName, '测试书源');
      expect(captured.bookSourceUrl, 'https://test.com');
      // 保存后返回上一页
      expect(find.byType(SourceEditScreen), findsNothing);
    });
  });

  group('SourceEditScreen 编辑模式回填', () {
    testWidgets('回填发现/详情/评论规则字段与开关', (tester) async {
      // 加高可视区域，确保正文页的段评字段可见。
      await tester.binding.setSurfaceSize(const Size(800, 8000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const source = BookSource(
        bookSourceUrl: 'https://edit.com',
        bookSourceName: '可编辑源',
        exploreUrl: '分类::https://edit.com/sort',
        ruleExplore: ExploreRule(bookList: '.explore-list', name: '.e-name'),
        ruleBookInfo: BookInfoRule(init: '.init', tocUrl: '.toc'),
        ruleContent: ContentRule(
          content: '.body',
          contentBatch: '@js: batch()',
          maxBatchSize: 10,
        ),
        ruleReview: ReviewRule(
          enabled: true,
          reviewSummaryUrl: '.review-summary',
        ),
      );
      when(() => mockApi.bookSourceRepository.getBookSources())
          .thenAnswer((_) async => [source]);
      when(() => mockApi.bookSourceRepository.updateBookSource(any()))
          .thenAnswer((_) async {});
      // 预加载书源到 notifier 状态
      await container.read(sourceNotifierProvider.notifier).loadSources();

      await pumpEdit(tester, sourceUrl: 'https://edit.com');

      // 标题为编辑模式
      expect(find.text('编辑书源'), findsWidgets);
      // 基本信息回填
      expect(find.text('可编辑源'), findsOneWidget);

      await selectTab(tester, '发现');
      expect(find.text('分类::https://edit.com/sort'), findsOneWidget);
      expect(find.text('.explore-list'), findsOneWidget);
      await selectTab(tester, '详情');
      expect(find.text('.init'), findsOneWidget);
      expect(find.text('.toc'), findsOneWidget);
      await selectTab(tester, '正文');
      expect(find.text('.review-summary'), findsOneWidget);
      await selectTab(tester, '基本');
      // 段评开关在基本页设置段（CheckboxListTile）并回填为开启；
      // 段默认收起，先展开再断言
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      final reviewCheck = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, '段评'),
      );
      expect(reviewCheck.value, isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('sf_bookSourceName')),
        '修改源名称',
      );
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();
      final saved =
          verify(
                () =>
                    mockApi.bookSourceRepository.updateBookSource(captureAny()),
              ).captured.single
              as BookSource;
      expect(saved.ruleContent?.contentBatch, '@js: batch()');
      expect(saved.ruleContent?.maxBatchSize, 10);
      expect(saved.bookSourceName, '修改源名称');
    });
  });
}
