import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
import 'package:flutter_legado/src/data/bridge/mock_app_runtime.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/data/repositories/mock_read_record_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_read_record_repository.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('工厂装配正式实现，Mock 会话分别拥有独立存储', () async {
    expect(
      createTestApplication(useMock: false).readRecordRepository,
      isA<RustReadRecordRepository>(),
    );
    final first = createTestApplication(useMock: true);
    final second = createTestApplication(useMock: true);
    await first.readRecordRepository.putReadRecord(
      const ReadRecord(bookName: '独立', readTime: 123),
    );
    expect(await second.readRecordRepository.getReadRecords(), isEmpty);
  });

  test('Mock 按书名替换并完整保留字段，列表副本不能改写存储', () async {
    final repository = MockReadRecordRepository();
    const original = ReadRecord(
      bookName: '甲',
      deviceId: '设备1',
      readTime: 2000,
      lastRead: 12,
    );
    const other = ReadRecord(bookName: '乙', readTime: 3000);
    await repository.putReadRecord(original);
    await repository.putReadRecord(other);
    final replacement = original.copyWith(
      deviceId: '设备2',
      readTime: 4999,
      lastRead: 99,
    );
    await repository.putReadRecord(replacement);
    expect(await repository.getReadRecords(), [other, replacement]);
    (await repository.getReadRecords()).clear();
    expect(await repository.getReadRecords(), [other, replacement]);
    await repository.deleteReadRecord('不存在');
    await repository.deleteReadRecord('甲');
    expect(await repository.getReadRecords(), [other]);
    await repository.clearReadRecords();
    expect(await repository.getReadRecords(), isEmpty);
  });

  test('Mock 按真实写入生成每日明细，不推算不存在的日期', () async {
    final repository = MockReadRecordRepository();
    await repository.putReadRecord(
      const ReadRecord(bookName: '测试', readTime: 5000),
    );
    final now = DateTime.now();
    expect(
      (await repository.readRecordDailyList(now.year))
          .fold<int>(0, (sum, d) => sum + (d['seconds'] as int)),
      5,
    );
    expect(await repository.getAllReadRecordDetails(), hasLength(1));
  });

  test('多个消费者共享根 Repository，依赖替换后跟随且不重新初始化', () async {
    final first = _Api();
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        readRecordRepositoryProvider.overrideWithValue(
          first.readRecordRepository,
        ),
      ]),
    );
    addTearDown(container.dispose);
    final consumer = Provider((ref) => ref.watch(readRecordRepositoryProvider));
    final repository = container.read(consumer);
    expect(repository, same(first.readRecordRepository));
    expect(container.read(readRecordRepositoryProvider), same(repository));
    await repository.putReadRecord(
      const ReadRecord(bookName: '旧会话', readTime: 42),
    );
    final second = _Api();
    container.updateOverrides(
      mergeTestOverrides([
        readRecordRepositoryProvider.overrideWithValue(
          second.readRecordRepository,
        ),
      ]),
    );
    expect(container.read(consumer), same(second.readRecordRepository));
    expect(await container.read(consumer).getReadRecords(), isEmpty);
    expect((await repository.getReadRecords()).single.bookName, '旧会话');
    expect(first.initializations, 0);
    expect(second.initializations, 0);
  });
}

class _Api extends MockBookApi {
  int initializations = 0;

  @override
  MockAppRuntime get runtime => _fixtureRuntime;
  late final _fixtureRuntime = MockAppRuntime(startup: _fixtureInitialize);

  Future<void> _fixtureInitialize() async => initializations++;
}
