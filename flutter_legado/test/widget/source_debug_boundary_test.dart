import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/domain/models/book_source_debug_event.dart';
import 'package:flutter_legado/src/l10n/app_strings.dart';
import 'package:flutter_legado/src/providers/explore/explore_dependencies.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/screens/source_debug_screen.dart';

import '../mocks/mocks.dart';

void main() {
  late BookSourceDebugServiceMock service;
  late StreamController<BookSourceDebugEvent> events;
  var cancelled = 0;
  setUp(() {
    cancelled = 0;
    service = BookSourceDebugServiceMock();
    events = StreamController(onCancel: () => cancelled++);
    when(() => service.debug('source', '关键词')).thenAnswer((_) => events.stream);
    when(() => service.cancel()).thenAnswer((_) async {});
    addTearDown(() => unawaited(events.close()));
  });

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWith((_) => throw StateError('不访问根接口')),
          bookSourceDebugServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: SourceDebugScreen(sourceUrl: 'source')),
      ),
    );
    await tester.enterText(find.byType(TextField).at(1), '关键词');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text(AppStrings.current.debugAction));
    await tester.pump();
  }

  /// 等待StreamIterator的已完成取消Future，再刷新界面。
  Future<void> finish(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
  }

  testWidgets('消费类型化调试日志并在流结束后允许重试', (tester) async {
    await start(tester);
    events.add(const BookSourceDebugEvent(state: 1, message: '正在搜索'));
    events.add(const BookSourceDebugEvent(state: -1, message: '章节错误'));
    events.add(const BookSourceDebugEvent(state: 1000, message: '调试完成'));
    await tester.pump();
    expect(find.text('正在搜索'), findsOneWidget);
    expect(find.text('章节错误'), findsOneWidget);
    expect(find.text('调试完成'), findsOneWidget);
    unawaited(events.close());
    await finish(tester);
    expect(find.text(AppStrings.current.debugAction), findsOneWidget);
    expect(cancelled, 1);
    verifyNever(() => service.cancel());
  });

  testWidgets('停止调用发起服务并取消订阅，迟到消息不显示', (tester) async {
    await start(tester);
    await tester.tap(find.text(AppStrings.current.stopAction));
    await finish(tester);
    verify(() => service.cancel()).called(1);
    expect(cancelled, 1);
    events.add(const BookSourceDebugEvent(state: 1000, message: '迟到完成'));
    await tester.pump();
    expect(find.text('迟到完成'), findsNothing);
    expect(find.text(AppStrings.current.debugAction), findsOneWidget);
  });

  testWidgets('离开调试页取消原生任务与流，不访问已销毁页面', (tester) async {
    await start(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    verify(() => service.cancel()).called(1);
    expect(cancelled, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('流异常展示失败并释放运行态', (tester) async {
    await start(tester);
    events.addError(StateError('规则解析失败'));
    await finish(tester);
    expect(find.textContaining('规则解析失败'), findsOneWidget);
    expect(find.text(AppStrings.current.debugAction), findsOneWidget);
    expect(cancelled, 1);
    expect(tester.takeException(), isNull);
  });
}
