import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/services/cache_service.dart';

import '../mocks/mocks.dart';

void main() {
  late CacheService service;
  late CacheRepositoryMock repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = CacheRepositoryMock();
    service = CacheService(repository);
  });

  group('CacheService.formatSize 静态方法', () {
    test('小于 1KB 显示字节', () {
      expect(CacheService.formatSize(0), equals('0 B'));
      expect(CacheService.formatSize(512), equals('512 B'));
      expect(CacheService.formatSize(1023), equals('1023 B'));
    });

    test('1KB 到 1MB 之间显示 KB', () {
      expect(CacheService.formatSize(1024), equals('1.0 KB'));
      expect(CacheService.formatSize(1536), equals('1.5 KB'));
      expect(CacheService.formatSize(10240), equals('10.0 KB'));
      expect(CacheService.formatSize(1048575), equals('1024.0 KB'));
    });

    test('1MB 到 1GB 之间显示 MB', () {
      expect(CacheService.formatSize(1048576), equals('1.0 MB'));
      expect(CacheService.formatSize(5242880), equals('5.0 MB'));
      expect(CacheService.formatSize(104857600), equals('100.0 MB'));
    });

    test('大于等于 1GB 显示 GB', () {
      expect(CacheService.formatSize(1073741824), equals('1.00 GB'));
      expect(CacheService.formatSize(2684354560), equals('2.50 GB'));
    });

    test('边界值 1024 字节为 1.0 KB', () {
      expect(CacheService.formatSize(1024), equals('1.0 KB'));
    });

    test('边界值 1048576 字节为 1.0 MB', () {
      expect(CacheService.formatSize(1048576), equals('1.0 MB'));
    });
  });

  group('CacheService getCacheStats（mock API）', () {
    test('正确返回缓存统计', () async {
      when(() => repository.getCacheSize()).thenAnswer((_) async => 5242880);
      when(() => repository.getCacheBookCount()).thenAnswer((_) async => 10);
      when(() => repository.getCacheChapterCount())
          .thenAnswer((_) async => 200);

      final stats = await service.getCacheStats();

      expect(stats.totalSize, equals(5242880));
      expect(stats.bookCount, equals(10));
      expect(stats.chapterCount, equals(200));
    });

    test('缓存为空时统计为 0', () async {
      when(() => repository.getCacheSize()).thenAnswer((_) async => 0);
      when(() => repository.getCacheBookCount()).thenAnswer((_) async => 0);
      when(() => repository.getCacheChapterCount()).thenAnswer((_) async => 0);

      final stats = await service.getCacheStats();

      expect(stats.totalSize, equals(0));
      expect(stats.bookCount, equals(0));
      expect(stats.chapterCount, equals(0));
    });
  });

  group('CacheService clearCache（mock API）', () {
    test('清除全部缓存返回清除大小', () async {
      // 使用计数器模拟两次调用返回不同值
      var callCount = 0;
      when(() => repository.getCacheSize()).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? 1000 : 0;
      });
      when(() => repository.clearCache()).thenAnswer((_) async {});

      final cleared = await service.clearCache();

      expect(cleared, equals(1000));
      verify(() => repository.clearCache()).called(1);
    });

    test('按时间清除缓存', () async {
      final before = DateTime(2025, 1, 1);
      var callCount = 0;
      when(() => repository.getCacheSize()).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? 500 : 200;
      });
      when(() => repository.clearCacheBefore(any())).thenAnswer((_) async {});

      final cleared = await service.clearCache(before: before);

      expect(cleared, equals(300));
      verify(() => repository.clearCacheBefore(before.millisecondsSinceEpoch))
          .called(1);
    });

    test('清除后大小大于清除前时返回 0', () async {
      var callCount = 0;
      when(() => repository.getCacheSize()).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? 100 : 200; // 异常：清除后反而变大
      });
      when(() => repository.clearCache()).thenAnswer((_) async {});

      final cleared = await service.clearCache();

      expect(cleared, equals(0));
    });

    test('清除前后大小相同时返回 0', () async {
      when(() => repository.getCacheSize()).thenAnswer((_) async => 0);
      when(() => repository.clearCache()).thenAnswer((_) async {});

      final cleared = await service.clearCache();

      expect(cleared, equals(0));
    });
  });

  group('CacheService 自动过期天数（SharedPreferences）', () {
    test('默认自动过期天数为 0（永不过期）', () async {
      expect(await service.getAutoExpireDays(), equals(0));
    });

    test('设置并读取自动过期天数', () async {
      await service.setAutoExpireDays(30);
      expect(await service.getAutoExpireDays(), equals(30));
    });

    test('设置为 0 表示永不过期', () async {
      await service.setAutoExpireDays(30);
      await service.setAutoExpireDays(0);
      expect(await service.getAutoExpireDays(), equals(0));
    });

    test('设置较大天数', () async {
      await service.setAutoExpireDays(365);
      expect(await service.getAutoExpireDays(), equals(365));
    });
  });

  group('CacheService失败传播', () {
    setUp(() {
      when(() => repository.getCacheSize()).thenAnswer((_) async => 200);
      when(() => repository.getCacheBookCount()).thenAnswer((_) async => 2);
      when(() => repository.getCacheChapterCount()).thenAnswer((_) async => 20);
    });

    for (final field in ['大小', '书籍', '章节']) {
      test('$field查询失败不构造部分统计', () async {
        final error = StateError('$field读取失败');
        switch (field) {
          case '大小':
            when(() => repository.getCacheSize()).thenThrow(error);
          case '书籍':
            when(() => repository.getCacheBookCount()).thenThrow(error);
          case '章节':
            when(() => repository.getCacheChapterCount()).thenThrow(error);
        }
        await expectLater(service.getCacheStats(), throwsA(same(error)));
      });
    }

    test('清理失败不读取后置大小或返回已清理字节', () async {
      final error = StateError('清理失败');
      when(() => repository.clearCache()).thenThrow(error);
      await expectLater(service.clearCache(), throwsA(same(error)));
      verify(() => repository.getCacheSize()).called(1);
    });

    test('按时间清理失败不退回全部清理', () async {
      when(() => repository.clearCacheBefore(any()))
          .thenAnswer((_) async => throw StateError('按时间清理失败'));
      await expectLater(
        service.clearCache(before: DateTime.utc(2026, 10, 1)),
        throwsStateError,
      );
      verifyNever(() => repository.clearCache());
      verify(() => repository.getCacheSize()).called(1);
    });

    test('清理前查询失败不执行删除', () async {
      when(() => repository.getCacheSize()).thenThrow(StateError('统计失败'));
      await expectLater(service.clearCache(), throwsStateError);
      verifyNever(() => repository.clearCache());
    });
  });
}
