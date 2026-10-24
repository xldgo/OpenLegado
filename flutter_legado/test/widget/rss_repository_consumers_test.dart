import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
import 'package:flutter_legado/src/data/repositories/mock_rss_source_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_rss_star_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/rss_repository_provider.dart';
import 'package:flutter_legado/src/features/rss/presentation/rss_favorites_screen.dart';
import 'package:flutter_legado/src/features/rss/presentation/rss_source_manage_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/widgets/source_selection_bar.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('源管理开关通过独立RSS仓储保存并刷新状态', (tester) async {
    final sources = MockRssSourceRepository();
    await sources.addRssSource(
      const RssSource(sourceUrl: 'feed', sourceName: '订阅源', sourceGroup: '自定义'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rssSourceRepositoryProvider.overrideWithValue(sources)],
        child: const MaterialApp(home: RssSourceManageScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect((await sources.getRssSources()).single.enabled, isFalse);
    expect((await sources.getRssSources()).single.sourceGroup, '自定义');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await sources.getRssSources()).single.enabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('订阅源手柄保存排序，长按多选保留选择并可退出', (tester) async {
    final sources = MockRssSourceRepository();
    for (var i = 0; i < 3; i++) {
      await sources.addRssSource(
        RssSource(sourceUrl: 'feed-$i', sourceName: '订阅$i', customOrder: i),
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rssSourceRepositoryProvider.overrideWithValue(sources)],
        child: const MaterialApp(home: RssSourceManageScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final handle = find.byType(ReorderableDragStartListener).first;
    final lastCard = find.ancestor(
      of: find.text('订阅2'),
      matching: find.byType(Card),
    );
    final start = tester.getCenter(handle);
    final destination =
        tester.getBottomLeft(lastCard).dy + tester.getSize(lastCard).height / 2;
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(Offset(0, tester.getSize(handle).height));
    await tester.pump();
    await gesture.moveTo(Offset(start.dx, destination));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    final saved = await sources.getRssSources();
    saved.sort((a, b) => a.customOrder.compareTo(b.customOrder));
    expect(saved.map((s) => s.sourceUrl), ['feed-1', 'feed-2', 'feed-0']);

    await tester.longPress(find.text('订阅1'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SourceSelectionBar>(find.byType(SourceSelectionBar))
          .selectedCount,
      1,
    );
    await tester.tap(find.text('订阅2'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SourceSelectionBar>(find.byType(SourceSelectionBar))
          .selectedCount,
      2,
    );
    await tester.tap(find.byTooltip('退出选择'));
    await tester.pumpAndSettle();
    expect(find.byType(SourceSelectionBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('收藏页读取来源名称并通过独立仓储取消收藏', (tester) async {
    final sources = MockRssSourceRepository();
    final stars = MockRssStarRepository();
    await sources.addRssSource(
      const RssSource(sourceUrl: 'feed', sourceName: '订阅源'),
    );
    await stars.addRssStar(
      const RssStar(origin: 'feed', title: '收藏文章', link: 'article'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rssSourceRepositoryProvider.overrideWithValue(sources),
          rssStarRepositoryProvider.overrideWithValue(stars),
        ],
        child: const MaterialApp(home: RssFavoritesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('收藏文章'), findsOneWidget);
    expect(find.text('订阅源'), findsOneWidget);
    await tester.tap(find.widgetWithIcon(IconButton, Symbols.star_rounded));
    await tester.pumpAndSettle();
    expect(find.text('收藏文章'), findsNothing);
    expect(await stars.getRssStars(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
