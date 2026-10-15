import 'package:flutter_legado/src/providers/chapter_cache_provider.dart';
import 'package:flutter_legado/src/domain/models/cache_download_task.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/screens/cache_download_screen.dart';
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
    container = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWith((ref) => throw StateError('队列页不得读取根API')),
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
