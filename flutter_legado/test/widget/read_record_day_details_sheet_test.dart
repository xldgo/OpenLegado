import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/features/read_records/read_record_day_details_provider.dart';
import 'package:flutter_legado/src/features/read_records/read_record_overview_state.dart';
import 'package:flutter_legado/src/features/read_records/widgets/read_record_day_details_sheet.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/features/privacy/privacy_controller.dart';

class _LoadedPrivacy extends PrivacyController {
  @override
  PrivacyState build() => const PrivacyState(loading: false);
}

void main() {
  testWidgets('当天明细展示全部书籍与总时长，书籍不直接跳转', (tester) async {
    final date = DateTime(2026, 10, 13);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyControllerProvider.overrideWith(_LoadedPrivacy.new),
          readRecordDayDetailsProvider(date).overrideWithValue(
            const AsyncData([
              ReadBookRanking(
                bookName: '同名小说',
                author: '甲作者',
                readTimeMs: 60000,
              ),
              ReadBookRanking(
                bookName: '同名小说',
                author: '乙作者',
                readTimeMs: 120000,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showReadRecordDayDetails(context, date),
                child: const Text('查看当天明细'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('查看当天明细'));
    await tester.pumpAndSettle();
    expect(find.text('2026年10月13日 阅读明细'), findsOneWidget);
    expect(find.text('同名小说'), findsNWidgets(2));
    expect(find.text('甲作者'), findsOneWidget);
    expect(find.text('乙作者'), findsOneWidget);
    expect(find.text('2本 · 3分钟'), findsOneWidget);
    await tester.tap(find.text('同名小说').first);
    await tester.pumpAndSettle();
    expect(find.byType(ReadRecordDayDetailsSheet), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadRecordDayDetailsSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
