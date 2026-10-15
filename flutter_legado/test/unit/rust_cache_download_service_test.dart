import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/services/rust_cache_download_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const service = RustCacheDownloadService();
  const task =
      '{"taskId":7,"bookUrl":"书","status":"running","total":5,"completed":2,"failed":1}';
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('闭区间参数直接传递，任务ID与取消结果保持原值', () async {
    when(
      () => bridge.crateFfiFfiCacheDownloadStart(
        bookUrl: '书',
        startChapter: 2,
        endChapter: 4,
      ),
    ).thenAnswer((_) async => ' 7 ');
    when(() => bridge.crateFfiFfiCacheDownloadCancel(taskId: 7))
        .thenAnswer((_) async => false);
    expect(await service.cacheDownloadStart('书', 2, 4), 7);
    expect(await service.cacheDownloadCancel(7), isFalse);
    verify(
      () => bridge.crateFfiFfiCacheDownloadStart(
        bookUrl: '书',
        startChapter: 2,
        endChapter: 4,
      ),
    ).called(1);
    verify(() => bridge.crateFfiFfiCacheDownloadCancel(taskId: 7)).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('列表与进度解码为同一种任务快照', () async {
    when(() => bridge.crateFfiFfiCacheDownloadList())
        .thenAnswer((_) async => '[$task]');
    when(() => bridge.crateFfiFfiCacheDownloadProgress(taskId: 7))
        .thenAnswer((_) async => task);
    final list = await service.cacheDownloadList();
    final progress = await service.cacheDownloadProgress(7);
    expect(list.single.taskId, 7);
    expect(progress.bookUrl, '书');
    expect(progress.isRunning, isTrue);
    expect([progress.total, progress.completed, progress.failed], [5, 2, 1]);
    expect(() => list.clear(), throwsUnsupportedError);
  });

  test('notFound和未知状态保留原有Rust语义', () async {
    when(() => bridge.crateFfiFfiCacheDownloadProgress(taskId: 9)).thenAnswer(
      (_) async => '{"taskId":9,"bookUrl":"","status":"notFound","total":0,"completed":0,"failed":0}',
    );
    final missing = await service.cacheDownloadProgress(9);
    expect(missing.status, 'notFound');
    expect(missing.bookUrl, isEmpty);
    when(
      () => bridge.crateFfiFfiCacheDownloadList(),
    ).thenAnswer((_) async => '[${task.replaceFirst('running', 'unknown')}]');
    expect((await service.cacheDownloadList()).single.status, 'unknown');
  });

  for (final raw in [
    'null',
    '{}',
    '{',
    '[null]',
    '[{}]',
    '[${task.replaceFirst('"failed":1', '"failed":"1"')}]',
  ]) {
    test('非法任务列表拒绝整份响应：$raw', () async {
      when(() => bridge.crateFfiFfiCacheDownloadList())
          .thenAnswer((_) async => raw);
      await expectLater(service.cacheDownloadList(), throwsFormatException);
    });
  }

  test('坏进度与错误启动响应不能作为成功返回', () async {
    when(() => bridge.crateFfiFfiCacheDownloadProgress(taskId: 7))
        .thenAnswer((_) async => '{}');
    when(
      () => bridge.crateFfiFfiCacheDownloadStart(
        bookUrl: '书',
        startChapter: 0,
        endChapter: 1,
      ),
    ).thenAnswer((_) async => '{"error":"启动失败"}');
    await expectLater(service.cacheDownloadProgress(7), throwsFormatException);
    await expectLater(
      service.cacheDownloadStart('书', 0, 1),
      throwsFormatException,
    );
  });

  for (final (label, method) in [
    (
      '在途',
      (String raw, _Bridge api) =>
          when(() => api.crateFfiFfiCacheDownloadRunningChapters(bookUrl: '书'))
              .thenAnswer((_) async => raw),
    ),
    (
      '失败',
      (String raw, _Bridge api) =>
          when(() => api.crateFfiFfiCacheDownloadFailedChapters(bookUrl: '书'))
              .thenAnswer((_) async => raw),
    ),
  ]) {
    test('$label章节保留整数列表，不接受伪造空结果或字符串索引', () async {
      final query = label == '在途'
          ? service.listDownloadingChapters
          : service.listFailedChapters;
      method('[3,1,7]', bridge);
      expect(await query('书'), [3, 1, 7]);
      method('[]', bridge);
      expect(await query('书'), isEmpty);
      for (final raw in ['{}', 'null', '["1"]', '[1.5]', '[null]']) {
        method(raw, bridge);
        await expectLater(query('书'), throwsFormatException);
      }
    });
  }

  test('合法空队列成功，Rust错误原样传递', () async {
    when(() => bridge.crateFfiFfiCacheDownloadList())
        .thenAnswer((_) async => '[]');
    expect(await service.cacheDownloadList(), isEmpty);
    final error = StateError('任务查询失败');
    when(() => bridge.crateFfiFfiCacheDownloadList()).thenThrow(error);
    await expectLater(service.cacheDownloadList(), throwsA(same(error)));
  });
}
