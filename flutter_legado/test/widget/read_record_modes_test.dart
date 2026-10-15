import 'package:flutter_legado/src/widgets/book_cover.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/data/repositories/mock_read_record_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/routes.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/widgets/legado_app_bar.dart';
import 'package:flutter_legado/src/widgets/app_animated_text_line.dart';

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  late MockReadRecordRepository repo;
  late MockRustApi api;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = MockReadRecordRepository();
    api = MockRustApi();
    when(() => api.bookshelfRepository.getBooks()).thenAnswer((_) async => []);
    when(() => api.bookGroupRepository.getBookGroups())
        .thenAnswer((_) async => []);
    when(() => api.getChapters(any()))
        .thenAnswer((_) async => [const BookChapter(index: 2, title: '第三章')]);
    final end = DateTime(2026, 10, 13, 12).millisecondsSinceEpoch;
    await repo.putReadRecord(
      ReadRecord(
        bookName: '测试小说',
        author: '作者',
        readTime: 60000,
        startTime: end - 60000,
        lastRead: end,
      ),
      bookUrl: 'u',
      chapterIndex: 2,
    );
  });
  Future<void> pump(
    WidgetTester tester, {
    double width = 360,
    double textScale = 1,
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWithValue(api),
          readRecordRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
            ),
            child: child!,
          ),
          routes: {
            AppRoutes.readRecordOverview: (_) =>
                const Scaffold(body: Text('总览入口')),
          },
          home: const ReadRecordScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder titleText(String text) =>
      find.descendant(of: find.byType(LegadoAppBar), matching: find.text(text));

  testWidgets('选择态双行文案过渡、数量变化及系统返回先退出选择', (tester) async {
    final end = DateTime(2026, 10, 13, 12).millisecondsSinceEpoch;
    await repo.putReadRecord(
      ReadRecord(
        bookName: '第二本小说',
        author: '作者',
        readTime: 60000,
        lastRead: end,
      ),
    );
    await pump(tester);
    expect(titleText('阅读记录'), findsOneWidget);
    expect(titleText('汇总视图'), findsOneWidget);
    final titleRect = tester.getRect(find.byType(LegadoAppBar));
    final cover = tester.element(find.byType(BookCover).first);
    await tester.longPress(find.text('测试小说'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(titleText('阅读记录'), findsOneWidget);
    expect(titleText('已选 1 项'), findsOneWidget);
    expect(titleText('点按项目选择，返回退出'), findsOneWidget);
    expect(cover.mounted, isTrue);
    expect(tester.element(find.byType(BookCover).first), same(cover));

    final incoming = tester.widget<FractionalTranslation>(
      find
          .ancestor(
            of: titleText('已选 1 项'),
            matching: find.byType(FractionalTranslation),
          )
          .first,
    );
    final outgoing = tester.widget<FractionalTranslation>(
      find
          .ancestor(
            of: titleText('阅读记录'),
            matching: find.byType(FractionalTranslation),
          )
          .first,
    );
    expect(incoming.translation.dy, inExclusiveRange(0.0, 1.0));
    expect(outgoing.translation.dy, inExclusiveRange(-1.0, 0.0));
    expect(tester.getRect(find.byType(LegadoAppBar)), titleRect);
    await tester.pumpAndSettle();
    expect(titleText('阅读记录'), findsNothing);
    expect(titleText('汇总视图'), findsNothing);
    await tester.tap(find.text('第二本小说'));
    await tester.pumpAndSettle();
    expect(titleText('已选 2 项'), findsOneWidget);
    await tester.tap(find.text('测试小说'));
    await tester.pumpAndSettle();
    expect(titleText('已选 1 项'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(titleText('已选 1 项'), findsOneWidget);
    final normalIncoming = tester.widget<FractionalTranslation>(
      find
          .ancestor(
            of: titleText('阅读记录'),
            matching: find.byType(FractionalTranslation),
          )
          .first,
    );
    expect(normalIncoming.translation.dy, inExclusiveRange(0.0, 1.0));
    await tester.pumpAndSettle();
    expect(find.byType(ReadRecordScreen), findsOneWidget);
    expect(titleText('阅读记录'), findsOneWidget);
    expect(titleText('汇总视图'), findsOneWidget);
    expect(titleText('点按项目选择，返回退出'), findsNothing);
    expect(cover.mounted, isTrue);
    expect(tester.element(find.byType(BookCover).first), same(cover));

    expect(tester.takeException(), isNull);
  });

  testWidgets('快速退出选择不残留旧标题，减少动态效果时直接切换', (tester) async {
    await pump(tester);
    await tester.longPress(find.text('测试小说'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byTooltip('退出选择'));
    await tester.pumpAndSettle();
    expect(titleText('阅读记录'), findsOneWidget);
    expect(titleText('已选 1 项'), findsNothing);
    await pump(tester, disableAnimations: true);
    await tester.longPress(find.text('测试小说'));
    await tester.pumpAndSettle();
    expect(titleText('已选 1 项'), findsOneWidget);
    final titleLines = find.descendant(
      of: find.byType(LegadoAppBar),
      matching: find.byType(AppAnimatedTextLine),
    );
    expect(titleLines, findsNWidgets(2));
    final translations = tester.widgetList<FractionalTranslation>(
      find.descendant(
        of: titleLines,
        matching: find.byType(FractionalTranslation),
      ),
    );
    expect(translations.every((t) => t.translation == Offset.zero), isTrue);
    await tester.tap(find.text('测试小说'));
    await tester.pumpAndSettle();
    expect(titleText('阅读记录'), findsOneWidget);
    expect(titleText('汇总视图'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('汇总一天一个卡片，内部书籍共享日期和当日总时长', (tester) async {
    await repo.clearReadRecords();
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day, 12);
    for (final name in ['当天甲书', '当天乙书']) {
      await repo.putReadRecord(
        ReadRecord(
          bookName: name,
          author: '作者',
          readTime: 60000,
          startTime: day.millisecondsSinceEpoch - 60000,
          lastRead: day.millisecondsSinceEpoch,
        ),
      );
    }
    await pump(tester);
    final date =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final card = find.byKey(ValueKey('read-record-day-$date'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('今天')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('已读 2分钟')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('当天甲书')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('当天乙书')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.byType(Card)),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.text('阅读时长：1分钟')),
      findsNWidgets(2),
    );
    expect(tester.takeException(), isNull);
  });
  for (final size in [(360.0, 1.0), (320.0, 2.0)]) {
    testWidgets('汇总已读徽标靠右且不溢出：${size.$1}dp / ${size.$2}倍文字', (tester) async {
      await repo.clearReadRecords();
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day - 6, 23);
      final duration = const Duration(hours: 12, minutes: 35).inMilliseconds;
      await repo.putReadRecord(
        ReadRecord(
          bookName: '长时长样例',
          readTime: duration,
          startTime: day.millisecondsSinceEpoch - duration,
          lastRead: day.millisecondsSinceEpoch,
        ),
      );
      await pump(tester, width: size.$1, textScale: size.$2);
      final date =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final card = find.byKey(ValueKey('read-record-day-$date'));
      final label = find.descendant(
        of: card,
        matching: find.textContaining('已读 '),
      );
      final badge = find
          .ancestor(of: label, matching: find.byType(Container))
          .first;
      expect(
        tester.getRect(badge).right,
        closeTo(tester.getRect(card).right - 12, 0.01),
      );
      expect(
        tester.getRect(find.text(date)).right,
        lessThanOrEqualTo(tester.getRect(badge).left - 12),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final days in [1, 2, 5, 6]) {
    testWidgets('日期对齐上游：$days天前的显示边界', (tester) async {
      await repo.clearReadRecords();
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day - days, 12);
      await repo.putReadRecord(
        ReadRecord(
          bookName: '日期样例',
          readTime: 60000,
          startTime: day.millisecondsSinceEpoch - 60000,
          lastRead: day.millisecondsSinceEpoch,
        ),
      );
      await pump(tester);
      final date =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final card = find.byKey(ValueKey('read-record-day-$date'));
      final label = days == 1
          ? '昨天'
          : days <= 5
          ? '$days天前'
          : date;
      expect(
        find.descendant(of: card, matching: find.text(label)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('未知作者')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('时间线每天一张卡片，显示结束时间、封面与章节', (tester) async {
    final end = DateTime(2026, 10, 13, 12, 40).millisecondsSinceEpoch;
    await repo.putReadRecord(
      ReadRecord(
        bookName: '测试小说',
        author: '作者',
        readTime: 120000,
        startTime: DateTime(2026, 10, 13, 11, 59).millisecondsSinceEpoch,
        lastRead: end,
      ),
      bookUrl: 'u',
      chapterIndex: 2,
    );
    await pump(tester);
    await tester.tap(find.byTooltip('切换阅读记录视图'));
    await tester.pumpAndSettle();
    final card = find.byKey(
      const ValueKey('read-record-timeline-day-2026-10-13'),
    );
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(Card)),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.text('12:40')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('12:00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('测试小说')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: card, matching: find.text('作者')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: card, matching: find.text('第三章')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('已读')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('时间线长按删除只影响选定会话，保留同日其他会话', (tester) async {
    final end = DateTime(2026, 10, 13, 12, 40).millisecondsSinceEpoch;
    await repo.putReadRecord(
      ReadRecord(
        bookName: '测试小说',
        author: '作者',
        readTime: 120000,
        startTime: DateTime(2026, 10, 13, 11, 59).millisecondsSinceEpoch,
        lastRead: end,
      ),
      bookUrl: 'u',
      chapterIndex: 2,
    );
    await pump(tester);
    await tester.tap(find.byTooltip('切换阅读记录视图'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('测试小说').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect((await repo.getReadRecordSessions()).length, 1);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('12:40'), findsNothing);
    expect(find.text('第三章'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('最后阅读按上游平铺封面、书名、作者和完整阅读时间', (tester) async {
    await pump(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('切换阅读记录视图'));
      await tester.pumpAndSettle();
    }
    final title = find.text('测试小说');
    expect(title, findsOneWidget);
    expect(find.ancestor(of: title, matching: find.byType(Card)), findsNothing);
    expect(find.text('作者'), findsOneWidget);
    expect(find.text('1分钟 • 2026-10-13 12:00'), findsOneWidget);
    expect(find.byTooltip('筛选阅读日期'), findsNothing);
    final coverFinder = find.descendant(
      of: find.ancestor(of: title, matching: find.byType(InkWell)).first,
      matching: find.byType(BookCover),
    );
    final cover = tester.element(coverFinder);
    final row = find.ancestor(of: title, matching: find.byType(InkWell)).first;
    final rowRect = tester.getRect(row);
    expect(rowRect.left, 0);
    expect(rowRect.right, 360);
    expect(tester.getTopLeft(coverFinder).dx, 16);
    final normalTitleX = tester.getTopLeft(title).dx;
    await tester.longPress(title);
    await tester.pumpAndSettle();
    expect(cover.mounted, isTrue);
    expect(tester.element(coverFinder), same(cover));
    expect(tester.getTopLeft(title).dx, normalTitleX + 20);
    final material = tester.widget<Material>(
      find.ancestor(of: title, matching: find.byType(Material)).first,
    );
    expect(material.color, AppTheme.light.colorScheme.secondaryContainer);
    expect(tester.getRect(row), rowRect);
    // 左侧原留白也属于本行，点按取消后仍处于同一封面元素树。
    await tester.tapAt(Offset(4, rowRect.center.dy));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dx, normalTitleX);
    expect(cover.mounted, isTrue);
    await tester.longPress(title);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(await repo.getReadRecords(), isEmpty);
    expect(await repo.getReadRecordSessions(), isEmpty);
    expect(await repo.getAllReadRecordDetails(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('三视图顶栏切换、显示真实章节、偏好持久化并保留总览入口', (tester) async {
    await pump(tester);
    expect(find.text('汇总视图'), findsOneWidget);
    expect(find.text('按书'), findsNothing);
    expect(find.text('按天'), findsNothing);
    expect(find.text('测试小说'), findsOneWidget);
    await tester.tap(find.byTooltip('排序与设置'));
    await tester.pumpAndSettle();
    expect(find.text('阅读总览'), findsNothing);
    expect(find.text('清空'), findsOneWidget);
    await tester.tapAt(const Offset(20, 150));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('切换阅读记录视图'));
    await tester.pumpAndSettle();
    expect(find.text('时间线视图'), findsOneWidget);
    expect(find.textContaining('第三章'), findsOneWidget);
    await tester.tap(find.byTooltip('切换阅读记录视图'));
    await tester.pumpAndSettle();
    expect(find.text('最后阅读视图'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'readRecordDisplayMode',
      ),
      'latest',
    );
    await tester.tap(find.text('累计阅读成就'));
    await tester.pumpAndSettle();
    expect(find.text('总览入口'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('移除日历入口后作者搜索和选择删除正常', (tester) async {
    await pump(tester);
    expect(find.byTooltip('筛选阅读日期'), findsNothing);
    expect(find.byType(ReadingHeatmapCard), findsNothing);
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '作者');
    await tester.pumpAndSettle();
    expect(find.text('测试小说'), findsOneWidget);
    await tester.longPress(find.text('测试小说'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(await repo.getAllReadRecordDetails(), isEmpty);
    expect(await repo.getReadRecordSessions(), isEmpty);
    expect(await repo.getReadRecords(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
