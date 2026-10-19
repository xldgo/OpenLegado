import '../fixtures/routing_test_app.dart';
import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/domain/contracts/read_record_repository.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

class _MockReadRecordRepository extends Mock implements ReadRecordRepository {}

void main() {
  late _MockReadRecordRepository mockRepo;
  late MockRustApi mockApi;

  setUpAll(registerFallbacks);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockRepo = _MockReadRecordRepository();
    mockApi = MockRustApi();

    when(() => mockRepo.getReadRecords()).thenAnswer(
      (_) async => [const ReadRecord(bookName: '测试书籍', readTime: 120000)],
    );
    when(() => mockRepo.getAllReadRecordDetails()).thenAnswer((_) async => []);
    when(() => mockRepo.readRecordDailyList(any())).thenAnswer(
      (_) async => [
        {'date': '2026-05-20', 'seconds': 120},
      ],
    );
  });

  Widget buildTestWidget({NavigatorObserver? observer}) {
    return ProviderScope(
      overrides: mergeTestOverrides([
        ...mockApi.overrides,
        readRecordRepositoryProvider.overrideWithValue(mockRepo),
      ]),
      child: RoutingTestApp(
        navigatorObservers: observer != null ? [observer] : [],
        routes: {
          AppRoutes.readRecordOverview: (context) =>
              const Scaffold(body: Text('阅读总览页面')),
        },
        home: const ReadRecordScreen(),
      ),
    );
  }

  testWidgets('渲染阅读记录页时汇总卡能找到阅读总览入口', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final buttonFinder = find.byTooltip('阅读总览');
    expect(buttonFinder, findsOneWidget);

    expect(find.text('累计阅读成就'), findsOneWidget);
  });

  testWidgets('点击「阅读总览」按钮时能正确触发导航跳转至 AppRoutes.readRecordOverview', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final buttonFinder = find.byTooltip('阅读总览');
    expect(buttonFinder, findsOneWidget);

    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    expect(find.text('阅读总览页面'), findsOneWidget);
  });
}
