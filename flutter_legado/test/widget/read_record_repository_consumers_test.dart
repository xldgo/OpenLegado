import 'package:flutter_legado/src/domain/contracts/read_record_repository.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/screens/home_tab_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

class _Records extends Mock implements ReadRecordRepository {}

void main() {
  late _Records records;
  late MockRustApi api;

  setUpAll(registerFallbacks);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    records = _Records();
    api = MockRustApi();
    when(() => api.getBooks()).thenAnswer((_) async => []);
    when(() => api.getBookGroups()).thenAnswer((_) async => []);
    when(() => records.getReadRecords()).thenAnswer(
      (_) async => [const ReadRecord(bookName: '窄接口小说', readTime: 5000)],
    );
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    when(() => records.readRecordDailyList(now.year)).thenAnswer(
      (_) async => [
        {'date': date, 'seconds': 7},
      ],
    );
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWithValue(api),
          readRecordRepositoryProvider.overrideWithValue(records),
        ],
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('记录页及按天视图使用同一窄接口，不读取根记录实现', (tester) async {
    await pump(tester, const ReadRecordScreen());
    expect(find.text('窄接口小说'), findsOneWidget);
    verify(() => records.getReadRecords()).called(1);
    verify(() => records.readRecordDailyList(DateTime.now().year)).called(1);
    verifyNever(() => api.readRecordRepository);
    await tester.tap(find.text('按天'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadRecordDailyView), findsOneWidget);
    expect(find.textContaining('7秒'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页累计时长、今日目标与热力图共用窄接口', (tester) async {
    await pump(tester, const HomeTabScreen());
    expect(find.text('累计阅读'), findsOneWidget);
    expect(find.text('阅读时长'), findsOneWidget);
    verify(() => records.getReadRecords()).called(1);
    verify(() => records.readRecordDailyList(DateTime.now().year)).called(2);
    verifyNever(() => api.readRecordRepository);
    expect(tester.takeException(), isNull);
  });
}
