import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_cache_repository.dart';
import 'package:flutter_legado/src/data/services/rust_database_maintenance_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const repository = RustCacheRepository();
  const maintenance = RustDatabaseMaintenanceService();

  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('三项统计原样返回，大小支持超过32位', () async {
    when(() => bridge.crateFfiFfiCacheGetSize())
        .thenAnswer((_) async => 5 * 1024 * 1024 * 1024);
    when(() => bridge.crateFfiFfiCacheGetBookCount())
        .thenAnswer((_) async => 8);
    when(() => bridge.crateFfiFfiCacheGetChapterCount())
        .thenAnswer((_) async => 600);
    expect(await repository.getCacheSize(), 5 * 1024 * 1024 * 1024);
    expect(await repository.getCacheBookCount(), 8);
    expect(await repository.getCacheChapterCount(), 600);
    verify(() => bridge.crateFfiFfiCacheGetSize()).called(1);
    verify(() => bridge.crateFfiFfiCacheGetBookCount()).called(1);
    verify(() => bridge.crateFfiFfiCacheGetChapterCount()).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('全部与按时间清理走各自FRB，毫秒截止值不转换单位', () async {
    const timestamp = 1792108800123;
    when(() => bridge.crateFfiFfiCacheClear()).thenAnswer((_) async => true);
    when(() => bridge.crateFfiFfiCacheClearBefore(beforeTimestampMs: timestamp))
        .thenAnswer((_) async => true);
    await repository.clearCache();
    await repository.clearCacheBefore(timestamp);
    verify(() => bridge.crateFfiFfiCacheClear()).called(1);
    verify(
      () => bridge.crateFfiFfiCacheClearBefore(beforeTimestampMs: timestamp),
    ).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('清理返回false不能转换成成功', () async {
    when(() => bridge.crateFfiFfiCacheClear()).thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiCacheClearBefore(beforeTimestampMs: 12))
        .thenAnswer((_) async => false);
    await expectLater(repository.clearCache(), throwsStateError);
    await expectLater(repository.clearCacheBefore(12), throwsStateError);
  });

  test('压缩保留0与释放字节数，不额外发起缓存清理', () async {
    when(() => bridge.crateFfiFfiCacheShrinkDatabase())
        .thenAnswer((_) async => 0);
    expect(await maintenance.shrinkDatabase(), 0);
    when(() => bridge.crateFfiFfiCacheShrinkDatabase())
        .thenAnswer((_) async => 10 * 1024 * 1024);
    expect(await maintenance.shrinkDatabase(), 10 * 1024 * 1024);
    verify(() => bridge.crateFfiFfiCacheShrinkDatabase()).called(2);
    verifyNoMoreInteractions(bridge);
  });

  test('六项调用的异常均传递，不伪造零值或成功', () async {
    final error = StateError('数据库不可用');
    when(() => bridge.crateFfiFfiCacheGetSize()).thenThrow(error);
    when(() => bridge.crateFfiFfiCacheGetBookCount()).thenThrow(error);
    when(() => bridge.crateFfiFfiCacheGetChapterCount()).thenThrow(error);
    when(() => bridge.crateFfiFfiCacheClear()).thenThrow(error);
    when(() => bridge.crateFfiFfiCacheClearBefore(beforeTimestampMs: 12))
        .thenThrow(error);
    when(() => bridge.crateFfiFfiCacheShrinkDatabase()).thenThrow(error);
    for (final operation in <Future<Object?> Function()>[
      repository.getCacheSize,
      repository.getCacheBookCount,
      repository.getCacheChapterCount,
      repository.clearCache,
      () => repository.clearCacheBefore(12),
      maintenance.shrinkDatabase,
    ]) {
      await expectLater(operation, throwsA(same(error)));
    }
  });
}
