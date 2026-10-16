import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
import 'package:flutter/services.dart';
import 'package:flutter_legado/src/data/repositories/mock_app_log_repository.dart';
import 'package:flutter_legado/src/domain/models/app_log_entry.dart';
import 'package:flutter_legado/src/providers/app_log_repository_provider.dart';
import 'package:flutter_legado/src/screens/app_log_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  testWidgets('独立仓储切换级别，清空确认取消不写入、确认只清当前级别', (tester) async {
    final repository = MockAppLogRepository();
    await repository.appLogPush(level: 'message', message: '普通消息');
    await repository.appLogPush(level: 'http', message: 'HTTP消息');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appLogRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AppLogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('普通消息'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'HTTP'));
    await tester.pumpAndSettle();
    expect(find.text('HTTP消息'), findsOneWidget);
    expect(find.text('普通消息'), findsNothing);
    Future<void> openClear() async {
      await tester.tap(find.byTooltip('日志操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清空当前级别'));
      await tester.pumpAndSettle();
    }

    await openClear();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await repository.appLogList(level: 'http'), hasLength(1));
    await openClear();
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(await repository.appLogList(level: 'http'), isEmpty);
    expect(await repository.appLogList(level: 'message'), hasLength(1));
    expect(find.text('暂无 http 级别日志'), findsOneWidget);
    expect(find.text('已清空当前级别日志'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('导出经仓储取得原格式并复制到剪贴板', (tester) async {
    final repository = MockAppLogRepository();
    await repository.appLogPush(level: 'message', message: '待导出');
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appLogRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AppLogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('日志操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出到剪贴板'));
    await tester.pumpAndSettle();
    expect(copied, await repository.appLogExport());
    expect(copied, contains('[message] 待导出\n'));
    expect(find.textContaining('日志已复制到剪贴板'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('清空失败显示失败提示，不显示已清空', (tester) async {
    final repository = AppLogRepositoryMock();
    when(() => repository.appLogList(level: 'message')).thenAnswer(
      (_) async => [
        const AppLogEntry(timestamp: 1, level: 'message', message: '未清空消息'),
      ],
    );
    when(() => repository.appLogClearAll()).thenThrow(StateError('缓冲不可用'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appLogRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AppLogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('日志操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空全部'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.textContaining('清空失败'), findsOneWidget);
    expect(find.text('已清空全部日志'), findsNothing);
    verify(() => repository.appLogList(level: 'message')).called(1);
    verify(() => repository.appLogClearAll()).called(1);
    expect(tester.takeException(), isNull);
  });
}
