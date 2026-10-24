import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_legado/src/bridge/ffi.dart' as controls;
import 'package:flutter_legado/src/bridge/task_dto.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/services/rust_cache_download_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

class _Request extends Fake implements controls.StreamRequest {
  int cancellations = 0, disposals = 0;
  @override
  void cancel() => cancellations++;
  @override
  void dispose() => disposals++;
}

void main() {
  late _Bridge bridge;
  const service = RustCacheDownloadService();
  final id = BigInt.from(7);
  final task = CacheDownloadTaskDto(
    taskId: id,
    bookUrl: '书',
    status: CacheDownloadStatusDto.running,
    total: 5,
    completed: 2,
    failed: 1,
  );
  setUpAll(() {
    registerFallbackValue(_Request());
    registerFallbackValue(BigInt.zero);
  });
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);
  test('闭区间与业务任务编号保持，取消结果不伪造', () async {
    when(
      () => bridge.crateFfiFfiCacheDownloadStart(
        bookUrl: '书',
        startChapter: 2,
        endChapter: 4,
      ),
    ).thenAnswer((_) async => id);
    when(() => bridge.crateFfiFfiCacheDownloadCancel(taskId: id))
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
    verify(() => bridge.crateFfiFfiCacheDownloadCancel(taskId: id)).called(1);
    verifyNoMoreInteractions(bridge);
  });
  test('列表、进度和所有枚举状态保持字段与不可变快照', () async {
    when(() => bridge.crateFfiFfiCacheDownloadList())
        .thenAnswer((_) async => [task]);
    final list = await service.cacheDownloadList();
    expect(list.single.taskId, 7);
    expect(list.single.bookUrl, '书');
    expect(
      [list.single.total, list.single.completed, list.single.failed],
      [5, 2, 1],
    );
    expect(() => list.clear(), throwsUnsupportedError);
    for (final state in CacheDownloadStatusDto.values) {
      when(() => bridge.crateFfiFfiCacheDownloadProgress(taskId: id))
          .thenAnswer(
            (_) async => CacheDownloadTaskDto(
              taskId: id,
              bookUrl: '书',
              status: state,
              total: 5,
              completed: 2,
              failed: 1,
            ),
          );
      expect((await service.cacheDownloadProgress(7)).status, state.name);
    }
  });
  test('章节直接传整数，结果不可变且错误上抛', () async {
    when(() => bridge.crateFfiFfiCacheDownloadRunningChapters(bookUrl: '书'))
        .thenAnswer((_) async => Int32List.fromList([3, 1, 7]));
    when(() => bridge.crateFfiFfiCacheDownloadFailedChapters(bookUrl: '书'))
        .thenAnswer((_) async => Int32List.fromList([2]));
    final values = await service.listDownloadingChapters('书');
    expect(values, [3, 1, 7]);
    expect(() => values.clear(), throwsUnsupportedError);
    expect(await service.listFailedChapters('书'), [2]);
    final error = StateError('查询失败');
    when(() => bridge.crateFfiFfiCacheDownloadList()).thenThrow(error);
    await expectLater(service.cacheDownloadList(), throwsA(same(error)));
  });
  test('有符号索引溢出和负任务编号在桥前拒绝', () async {
    await expectLater(
      service.cacheDownloadStart('书', 2147483648, 0),
      throwsRangeError,
    );
    expect(() => service.cacheDownloadCancel(-1), throwsRangeError);
    await expectLater(service.cacheDownloadProgress(-1), throwsRangeError);
    verifyZeroInteractions(bridge);
  });
  test('自动缓存订阅取消只关闭自己的窗口，不调用手动任务取消', () async {
    final request = _Request();
    final events = StreamController<int>();
    when(() => bridge.crateFfiStreamRequestNew()).thenReturn(request);
    when(
      () => bridge.crateFfiFfiMangaCachePrefetch(
        bookUrl: '漫画',
        currentChapter: 5,
        nextCount: 3,
        previousCount: 1,
        request: request,
      ),
    ).thenAnswer((_) => events.stream);
    final completed = <int>[];
    final subscription = service
        .prefetchMangaChapters(
          bookUrl: '漫画',
          currentChapter: 5,
          nextCount: 3,
          previousCount: 1,
        )
        .listen(completed.add);
    events.add(6);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    events.add(7);
    await events.close();
    expect(completed, [6]);
    expect(request.cancellations, 1);
    expect(request.disposals, 1);
    verifyNever(
      () => bridge.crateFfiFfiCacheDownloadCancel(taskId: any(named: 'taskId')),
    );
  });

  test('观察独立取消并释放凭据，不调用下载取消，迟到事件不再投递', () async {
    final request = _Request();
    final events = StreamController<List<CacheDownloadTaskDto>>();
    when(() => bridge.crateFfiStreamRequestNew()).thenReturn(request);
    when(() => bridge.crateFfiFfiCacheDownloadStream(request: request))
        .thenAnswer((_) => events.stream);
    final received = <int>[];
    final sub = service.watchTasks().listen(
      (v) => received.add(v.single.completed),
    );
    events.add([task]);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    events.add([task]);
    await events.close();
    expect(received, [2]);
    expect(request.cancellations, 1);
    expect(request.disposals, 1);
    verifyNever(() => bridge.crateFfiFfiCacheDownloadCancel(taskId: id));
  });
}
