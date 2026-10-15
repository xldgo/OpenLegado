import 'package:flutter_legado/src/data/repositories/mock_rss_source_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_rss_star_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/rss_repository_provider.dart';
import 'package:flutter_legado/src/screens/rss_favorites_screen.dart';
import 'package:flutter_legado/src/screens/rss_source_manage_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('源管理开关通过独立RSS仓储保存并刷新状态', (tester) async {
    final sources = MockRssSourceRepository();
    await sources.addRssSource(
      const RssSource(sourceUrl: 'feed', sourceName: '订阅源', sourceGroup: '自定义'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWith((_) => throw StateError('不应创建根接口')),
          rssSourceRepositoryProvider.overrideWithValue(sources),
        ],
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
          bookApiProvider.overrideWith((_) => throw StateError('不应创建根接口')),
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
