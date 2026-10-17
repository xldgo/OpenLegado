import '../fixtures/app_test_api.dart';

// ExploreKindLayout widget 测试：style 驱动的 wide/cell 布局
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/domain/models/explore_action_result.dart';
import 'package:flutter_legado/src/widgets/explore_kind_layout.dart';

import '../mocks/mocks.dart';

void main() {
  late MockRustApi mockApi;

  setUpAll(registerFallbacks);

  setUp(() {
    mockApi = MockRustApi();
    when(() => mockApi.exploreStateRepository.put(any(), any(), any()))
        .thenAnswer((_) async {});
    when(
      () => mockApi.exploreStateRepository.ensureDefault(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockApi.exploreService.evaluateAction(
        source: any(named: 'source'),
        actionJs: any(named: 'actionJs'),
      ),
    ).thenAnswer((_) async => ExploreActionResult());
    when(
      () => mockApi.exploreService.evaluateUiJs(
        source: any(named: 'source'),
        jsStr: any(named: 'jsStr'),
      ),
    ).thenAnswer(
      (invocation) async => invocation.namedArguments[#jsStr] as String,
    );
  });

  Widget wrap(Widget child) => ProviderScope(
    overrides: mergeTestOverrides([...mockApi.overrides]),
    child: MaterialApp(home: Scaffold(body: child)),
  );

  const sourceUrl = 'https://explore-layout.test';
  const source = BookSource(bookSourceUrl: 'https://explore-layout.test');
  const cellStyle = FlexChildStyle(
    layoutFlexGrow: 1,
    layoutFlexBasisPercent: 0.25,
  );
  const wideStyle = FlexChildStyle(
    layoutFlexGrow: 1,
    layoutFlexBasisPercent: 1,
  );

  testWidgets('cell 项按 flexBasisPercent 网格排布，wide 项独占一行', (tester) async {
    final categories = [
      const ExploreCategory(title: '推荐', url: '/rec', style: cellStyle),
      const ExploreCategory(title: '小说', url: '/novel', style: cellStyle),
      const ExploreCategory(title: '会员', url: '/vip', style: cellStyle),
      const ExploreCategory(title: '儿童', url: '/child', style: cellStyle),
      const ExploreCategory(title: '儿童分类', style: wideStyle),
      const ExploreCategory(title: '故事', url: '/story', style: cellStyle),
      const ExploreCategory(title: '排行榜', url: '/rank', style: wideStyle),
      const ExploreCategory(title: '音乐频道', style: wideStyle),
      const ExploreCategory(title: '流行', url: '/pop', style: cellStyle),
    ];

    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 360,
            child: ExploreKindLayout(
              sourceUrl: sourceUrl,
              source: source,
              categories: categories,
            ),
          ),
        ),
      ),
    );

    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('儿童分类'), findsOneWidget);
    expect(find.text('音乐频道'), findsOneWidget);
    expect(find.text('排行榜'), findsOneWidget);

    expect(find.byIcon(Icons.chevron_right), findsNothing);

    Size cellSize(String title) => tester.getSize(
      find.ancestor(of: find.text(title), matching: find.byType(InkWell)),
    );
    final w0 = cellSize('推荐').width;
    final w1 = cellSize('小说').width;
    expect(w0, closeTo(w1, 1));
    expect(w0, closeTo(84.5, 2));

    final wideChip = find.ancestor(
      of: find.text('排行榜'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(wideChip).width, closeTo(360, 2));
  });

  testWidgets('可点击 cell 项触发 onCategoryTap', (tester) async {
    String? tappedTitle;
    await tester.pumpWidget(
      wrap(
        ExploreKindLayout(
          sourceUrl: sourceUrl,
          source: source,
          categories: const [
            ExploreCategory(title: '玄幻', url: '/xh', style: cellStyle),
          ],
          onCategoryTap: (title, url) => tappedTitle = title,
        ),
      ),
    );

    await tester.tap(find.text('玄幻'));
    await tester.pump();
    expect(tappedTitle, '玄幻');
  });

  testWidgets('button 控件点击触发 exploreEvalAction', (tester) async {
    await tester.pumpWidget(
      wrap(
        ExploreKindLayout(
          sourceUrl: sourceUrl,
          source: source,
          categories: const [
            ExploreCategory(
              title: '登录番茄',
              type: 'button',
              action: 'java.refreshExplore()',
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('登录番茄'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(
      () => mockApi.exploreService.evaluateAction(
        source: source,
        actionJs: 'java.refreshExplore()',
      ),
    ).called(1);
  });

  testWidgets('类型化动作仍回放平台操作并刷新分类', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    when(
      () => mockApi.exploreService.evaluateAction(
        source: source,
        actionJs: 'copyAndRefresh()',
      ),
    ).thenAnswer(
      (_) async => ExploreActionResult(
        actions: const [
          {'action': 'copyText', 'text': '发现动作结果'},
        ],
        refreshExplore: true,
      ),
    );
    var refreshes = 0;
    await tester.pumpWidget(
      wrap(
        ExploreKindLayout(
          sourceUrl: sourceUrl,
          source: source,
          categories: const [
            ExploreCategory(
              title: '执行动作',
              type: 'button',
              action: 'copyAndRefresh()',
            ),
          ],
          onRefreshCategories: () async {
            refreshes++;
          },
        ),
      ),
    );
    await tester.tap(find.text('执行动作'));
    await tester.pumpAndSettle();
    expect(copied, '发现动作结果');
    expect(refreshes, 1);
  });
}
