import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/data/repositories/mock_cache_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_cache_repository.dart';
import 'package:flutter_legado/src/data/services/rust_database_maintenance_service.dart';
import 'package:flutter_legado/src/providers/cache_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  test('正式与Mock工厂装配对应窄接口，读取复用同一实例', () async {
    final real = createTestApplication(useMock: false);
    expect(real.cacheRepository, isA<RustCacheRepository>());
    expect(
      real.databaseMaintenanceService,
      isA<RustDatabaseMaintenanceService>(),
    );
    final api = createTestApplication(useMock: true);
    expect(api.cacheRepository, isA<MockCacheRepository>());
    final repository = api.cacheRepository;
    expect(api.cacheRepository, same(repository));
    expect(await repository.getCacheSize(), 50 * 1024 * 1024);
    expect(await repository.getCacheBookCount(), 3);
    expect(await repository.getCacheChapterCount(), 30);
    await repository.clearCache();
    await repository.clearCacheBefore(12);
    expect(
      await repository.getCacheSize(),
      50 * 1024 * 1024,
      reason: '保留旧Mock固定样例，不把空操作当真实清理',
    );
    expect(
      await api.databaseMaintenanceService.shrinkDatabase(),
      10 * 1024 * 1024,
    );
  });

  test('替换根装配时两个窄Provider同步更换实例', () async {
    final first = MockBookApi(cacheRepository: CacheRepositoryMock());
    final second = MockBookApi(
      cacheRepository: CacheRepositoryMock(),
      databaseMaintenanceService: DatabaseMaintenanceServiceMock(),
    );
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        cacheRepositoryProvider.overrideWithValue(first.cacheRepository),
        databaseMaintenanceServiceProvider.overrideWithValue(
          first.databaseMaintenanceService,
        ),
      ]),
    );
    addTearDown(container.dispose);
    expect(
      container.read(cacheRepositoryProvider),
      same(first.cacheRepository),
    );
    expect(
      container.read(databaseMaintenanceServiceProvider),
      same(first.databaseMaintenanceService),
    );
    container.updateOverrides(
      mergeTestOverrides([
        cacheRepositoryProvider.overrideWithValue(second.cacheRepository),
        databaseMaintenanceServiceProvider.overrideWithValue(
          second.databaseMaintenanceService,
        ),
      ]),
    );
    await container.pump();
    expect(
      container.read(cacheRepositoryProvider),
      same(second.cacheRepository),
    );
    expect(
      container.read(databaseMaintenanceServiceProvider),
      same(second.databaseMaintenanceService),
    );
  });

  test('窄接口独立注入，统计和压缩无需创建根接口', () async {
    final repository = CacheRepositoryMock();
    final maintenance = DatabaseMaintenanceServiceMock();
    when(() => repository.getCacheSize()).thenAnswer((_) async => 1024);
    when(() => repository.getCacheBookCount()).thenAnswer((_) async => 2);
    when(() => repository.getCacheChapterCount()).thenAnswer((_) async => 9);
    when(() => maintenance.shrinkDatabase()).thenAnswer((_) async => 0);
    final container = ProviderContainer(
      overrides: [
        cacheRepositoryProvider.overrideWithValue(repository),
        databaseMaintenanceServiceProvider.overrideWithValue(maintenance),
      ],
    );
    addTearDown(container.dispose);
    final stats = await container.read(cacheServiceProvider).getCacheStats();
    expect(stats.totalSize, 1024);
    expect(stats.bookCount, 2);
    expect(stats.chapterCount, 9);
    expect(
      await container.read(databaseMaintenanceServiceProvider).shrinkDatabase(),
      0,
    );
  });
}
