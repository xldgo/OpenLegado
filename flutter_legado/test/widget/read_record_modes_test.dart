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
    when(() => api.readingRepository.getChapters(any()))
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
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
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
