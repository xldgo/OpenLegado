library;

/// ReadRecordNotifier 单元测试
///
/// 覆盖：加载/搜索/排序/删除/总时长（对齐原版 ReadRecordActivity）

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/domain/contracts/read_record_repository.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Records extends Mock implements ReadRecordRepository {}

void main() {
  late _Records recordsApi;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(const ReadRecord());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    recordsApi = _Records();
    container = ProviderContainer(
      overrides: [readRecordRepositoryProvider.overrideWithValue(recordsApi)],
    );
    addTearDown(container.dispose);
  });

  ReadRecordState readState() => container.read(readRecordNotifierProvider);
  ReadRecordNotifier readNotifier() =>
      container.read(readRecordNotifierProvider.notifier);

  void stubRecords(List<ReadRecord> records) {
    when(() => recordsApi.getReadRecords()).thenAnswer((_) async => records);
  }

  group('formatDuring', () {
    test('0 与负数显示 0秒', () {
      expect(formatDuring(0), '0秒');
      expect(formatDuring(-1), '0秒');
    });

    test('组合天时分秒', () {
      // 1天 + 2小时 + 3分钟 + 4秒
      final ms = (1 * 86400 + 2 * 3600 + 3 * 60 + 4) * 1000;
      expect(formatDuring(ms), '1天2小时3分钟4秒');
    });
  });

  group('ReadRecordNotifier', () {
    test('load 汇总总时长并按书名排序', () async {
      stubRecords([
        const ReadRecord(bookName: 'BookB', readTime: 3000, lastRead: 200),
        const ReadRecord(bookName: 'BookA', readTime: 5000, lastRead: 100),
      ]);

      await readNotifier().load();

      expect(readState().isLoading, isFalse);
      expect(readState().totalReadTimeMs, 8000);
      expect(readState().records.map((e) => e.bookName), ['BookA', 'BookB']);
    });

    test('搜索过滤书名', () async {
      stubRecords([
        const ReadRecord(bookName: '斗破苍穹', readTime: 1000),
        const ReadRecord(bookName: '完美世界', readTime: 2000),
      ]);
      await readNotifier().load();
      readNotifier().setSearchQuery('完美');
      expect(readState().records, hasLength(1));
      expect(readState().records.first.bookName, '完美世界');
    });

    test('按阅读时长排序', () async {
      stubRecords([
        const ReadRecord(bookName: '短', readTime: 100),
        const ReadRecord(bookName: '长', readTime: 9999),
      ]);
      await readNotifier().load();
      await readNotifier().setSortMode(ReadRecordSortMode.readTime);
      expect(readState().records.first.bookName, '长');
    });

    test('删除后重新加载', () async {
      stubRecords([
        const ReadRecord(bookName: 'A', readTime: 1),
        const ReadRecord(bookName: 'B', readTime: 2),
      ]);
      when(() => recordsApi.deleteReadRecord(any())).thenAnswer((_) async {});
      await readNotifier().load();

      when(
        () => recordsApi.getReadRecords(),
      ).thenAnswer((_) async => [const ReadRecord(bookName: 'B', readTime: 2)]);
      await readNotifier().deleteByName('A');
      verify(() => recordsApi.deleteReadRecord('A')).called(1);
      expect(readState().records.map((e) => e.bookName), ['B']);
      expect(readState().totalReadTimeMs, 2);
    });

    test('同名记录合并时长，最近阅读取最大值', () async {
      stubRecords([
        const ReadRecord(
          bookName: '同名',
          deviceId: '设备1',
          readTime: 1200,
          lastRead: 5,
        ),
        const ReadRecord(
          bookName: '同名',
          deviceId: '设备2',
          readTime: 2300,
          lastRead: 9,
        ),
      ]);
      await readNotifier().load();
      expect(readState().records.single.readTime, 3500);
      expect(readState().records.single.lastRead, 9);
      expect(readState().totalReadTimeMs, 3500);
    });

    test('清空成功后重新加载，合计归零', () async {
      stubRecords([const ReadRecord(bookName: '保留', readTime: 5000)]);
      await readNotifier().load();
      when(() => recordsApi.clearReadRecords()).thenAnswer((_) async {
        stubRecords([]);
      });
      await readNotifier().clearAll();
      expect(readState().records, isEmpty);
      expect(readState().totalReadTimeMs, 0);
      verify(() => recordsApi.clearReadRecords()).called(1);
    });

    test('查询失败保留原列表与合计，重试成功清除错误', () async {
      stubRecords([const ReadRecord(bookName: '保留', readTime: 4000)]);
      await readNotifier().load();
      when(() => recordsApi.getReadRecords())
          .thenAnswer((_) async => throw StateError('加载失败'));
      await readNotifier().load();
      expect(readState().records.single.bookName, '保留');
      expect(readState().totalReadTimeMs, 4000);
      expect(readState().isLoading, isFalse);
      expect(readState().error, contains('加载失败'));
      stubRecords([]);
      await readNotifier().load();
      expect(readState().error, isNull);
    });

    for (final clear in [false, true]) {
      test('${clear ? "清空" : "删除"}失败保留原数据，不重新加载', () async {
        stubRecords([const ReadRecord(bookName: '保留', readTime: 4000)]);
        await readNotifier().load();
        clearInteractions(recordsApi);
        if (clear) {
          when(() => recordsApi.clearReadRecords())
              .thenAnswer((_) async => throw StateError('写入失败'));
          await readNotifier().clearAll();
        } else {
          when(() => recordsApi.deleteReadRecord('保留'))
              .thenAnswer((_) async => throw StateError('写入失败'));
          await readNotifier().deleteByName('保留');
        }
        expect(readState().records.single.bookName, '保留');
        expect(readState().totalReadTimeMs, 4000);
        expect(readState().error, contains('写入失败'));
        verifyNever(() => recordsApi.getReadRecords());
      });
    }

    test('最近阅读排序及记录开关沿用原偏好持久化', () async {
      stubRecords([
        const ReadRecord(bookName: '旧', lastRead: 100),
        const ReadRecord(bookName: '新', lastRead: 200),
      ]);
      await readNotifier().load();
      await readNotifier().setSortMode(ReadRecordSortMode.lastRead);
      expect(readState().records.first.bookName, '新');
      await readNotifier().toggleEnableRecord();
      expect(readState().enableRecord, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('enableReadRecord'), isFalse);
      // 新容器复用同一窄接口，验证排序与开关读取原持久化值。
      final replacement = ProviderContainer(
        overrides: [readRecordRepositoryProvider.overrideWithValue(recordsApi)],
      );
      addTearDown(replacement.dispose);
      await replacement.read(readRecordNotifierProvider.notifier).load();
      expect(
        replacement.read(readRecordNotifierProvider).sortMode,
        ReadRecordSortMode.lastRead,
      );
      expect(
        replacement.read(readRecordNotifierProvider).enableRecord,
        isFalse,
      );
    });
  });
}
