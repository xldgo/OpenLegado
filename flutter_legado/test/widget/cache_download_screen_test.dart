import 'dart:async';

import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
import 'package:flutter_legado/src/providers/chapter_cache_provider.dart';
import 'package:flutter_legado/src/domain/models/cache_download_task.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_legado/src/features/cache/presentation/cache_download_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

/// 缓存下载队列页测试（[UI-fix v2.0.16 | 2026-08-10] 新增页 — Reasonix）
void main() {
  late MockRustApi mockApi;
  late ProviderContainer container;

  setUpAll(registerFallbacks);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApi = MockRustApi();
    when(() => mockApi.cacheDownloadService.watchTasks()).thenAnswer(
      (_) => Stream.fromFuture(
        Future.sync(() => mockApi.cacheDownloadService.cacheDownloadList()),
      ),
    );
    container = ProviderContainer(
      overrides: [
        cacheDownloadServiceProvider.overrideWithValue(
          mockApi.cacheDownloadService,
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Widget wrap(Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: child),
    );
  }

  testWidgets('进度事件即时刷新，退订不取消下载且不继续查询', (tester) async {
    var stopped = false;
    final events = StreamController<List<CacheDownloadTask>>(
      onCancel: () => stopped = true,
    );
    when(() => mockApi.cacheDownloadService.watchTasks())
        .thenAnswer((_) => events.stream);
    await tester.pumpWidget(wrap(const CacheDownloadScreen()));
    events.add(const [
      CacheDownloadTask(
        taskId: 8,
        bookUrl: '事件书',
        status: 'running',
        total: 10,
        completed: 1,
        failed: 0,
      ),
    ]);
    await tester.pump();
    expect(find.textContaining('下载中 · 1/10'), findsOneWidget);
    events.add(const [
      CacheDownloadTask(
        taskId: 8,
        bookUrl: '事件书',
        status: 'completed',
        total: 10,
        completed: 10,
        failed: 0,
      ),
    ]);
    await tester.pump();
    expect(find.textContaining('已完成 · 10/10'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    verifyNever(() => mockApi.cacheDownloadService.cacheDownloadList());
    await tester.pumpWidget(const SizedBox.shrink());
    expect(stopped, isTrue);
    verifyNever(() => mockApi.cacheDownloadService.cacheDownloadCancel(any()));
    unawaited(events.close());
    await tester.pump();
  });

  testWidgets('缓存下载队列 无任务时显示空态', (tester) async {
    when(() => mockApi.cacheDownloadService.cacheDownloadList())
        .thenAnswer((_) async => const []);

    await tester.pumpWidget(wrap(const CacheDownloadScreen()));
    await tester.pump();

    expect(find.text('缓存下载队列'), findsOneWidget);
    expect(find.text('暂无缓存下载任务'), findsOneWidget);
  });

  testWidgets('缓存下载队列 渲染任务列表（状态/进度/取消按钮）', (tester) async {
    when(() => mockApi.cacheDownloadService.cacheDownloadList()).thenAnswer(
      (_) async => const [
        CacheDownloadTask(
          taskId: 1,
          bookUrl: 'https://example.com/book1',
          status: 'running',
          total: 10,
          completed: 4,
          failed: 0,
        ),
        CacheDownloadTask(
          taskId: 2,
          bookUrl: 'https://example.com/book2',
          status: 'completed',
          total: 5,
          completed: 5,
          failed: 0,
        ),
      ],
    );

    await tester.pumpWidget(wrap(const CacheDownloadScreen()));
    await tester.pump();

    expect(find.text('https://example.com/book1'), findsOneWidget);
    expect(find.text('https://example.com/book2'), findsOneWidget);
    expect(find.textContaining('下载中 · 4/10'), findsOneWidget);
    expect(find.textContaining('已完成 · 5/5'), findsOneWidget);
    // running 任务有取消按钮，completed 无
    expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
  });
  testWidgets('首次队列查询失败显示重试，不冒充空任务', (tester) async {
    when(() => mockApi.cacheDownloadService.cacheDownloadList())
        .thenThrow(const FormatException('错误任务响应'));
    await tester.pumpWidget(wrap(const CacheDownloadScreen()));
    await tester.pump();
    expect(find.text('缓存下载队列加载失败'), findsOneWidget);
    expect(find.text('暂无缓存下载任务'), findsNothing);
    when(() => mockApi.cacheDownloadService.cacheDownloadList())
        .thenAnswer((_) async => const []);
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(find.text('暂无缓存下载任务'), findsOneWidget);
    expect(find.text('缓存下载队列加载失败'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('轮询失败保留已加载任务，取消继续调用下载服务', (tester) async {
    when(() => mockApi.cacheDownloadService.cacheDownloadList()).thenAnswer(
      (_) async => const [
        CacheDownloadTask(
          taskId: 7,
          bookUrl: '书',
          status: 'running',
          total: 10,
          completed: 3,
          failed: 0,
        ),
      ],
    );
    when(() => mockApi.cacheDownloadService.cacheDownloadCancel(7))
        .thenAnswer((_) async => true);
    await tester.pumpWidget(wrap(const CacheDownloadScreen()));
    await tester.pump();
    when(() => mockApi.cacheDownloadService.cacheDownloadList())
        .thenThrow(StateError('轮询失败'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('书'), findsOneWidget);
    expect(find.textContaining('下载中 · 3/10'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump();
    verify(() => mockApi.cacheDownloadService.cacheDownloadCancel(7)).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
