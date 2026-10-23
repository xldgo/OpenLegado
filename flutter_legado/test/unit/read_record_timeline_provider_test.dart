import 'package:flutter_legado/src/data/repositories/mock_read_record_repository.dart';
import 'package:flutter_legado/src/domain/models/read_record_timeline_entry.dart';
import 'package:flutter_legado/src/domain/models/read_record_list.dart';
import 'package:flutter_legado/src/features/read_records/read_record_list_provider.dart';
import 'package:flutter_legado/src/features/read_records/read_record_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Timeline extends MockReadRecordRepository {
  ReadRecordListData list = const ReadRecordListData();
  final listQueries = <String>[];
  @override
  Future<ReadRecordListData> getReadRecordList(String query) async {
    listQueries.add(query);
    if (failure case final error?) throw error;
    return list;
  }

  List<ReadRecordTimelineEntry> rows = [];
  Object? failure;
  final queries = <String>[];
  @override
  Future<List<ReadRecordTimelineEntry>> getReadRecordTimeline(
    String query,
  ) async {
    queries.add(query);
    if (failure case final error?) throw error;
    return rows;
  }
}

void main() {
  test('列表与时间线透传搜索、跟随写入和仓储替换，错误不变成空结果', () async {
    final first = _Timeline();
    final container = ProviderContainer(
      overrides: [readRecordRepositoryProvider.overrideWithValue(first)],
    );
    addTearDown(container.dispose);
    final provider = readRecordTimelineProvider('作者');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final listProvider = readRecordListDataProvider('作者');
    final listSubscription = container.listen(listProvider, (_, _) {});
    addTearDown(listSubscription.close);
    expect((await container.read(listProvider.future)).aggregate, isEmpty);
    expect(first.listQueries, ['作者']);
    expect(await container.read(provider.future), isEmpty);
    expect(first.queries, ['作者']);

    final failure = StateError('查询失败');
    first.failure = failure;
    await first.clearReadRecords();
    await container.pump();
    await expectLater(container.read(provider.future), throwsA(same(failure)));
    await expectLater(
      container.read(listProvider.future),
      throwsA(same(failure)),
    );

    const entry = ReadRecordBookEntry(
      bookName: '书',
      author: '作者',
      durationMs: 1000,
      lastRead: 2000,
    );
    final second = _Timeline()
      ..list = const ReadRecordListData(latest: [entry], totalTimeMs: 1000)
      ..rows = [
        const ReadRecordTimelineEntry(
          bookName: '书',
          author: '作者',
          date: '2026-10-13',
          bookUrl: 'u',
          startTime: 1000,
          endTime: 2000,
          chapterIndex: 1,
          sessionIds: [7, 8],
        ),
      ];
    container.updateOverrides([
      readRecordRepositoryProvider.overrideWithValue(second),
    ]);
    await container.pump();
    expect((await container.read(provider.future)).single.sessionIds, [7, 8]);
    expect(second.queries, ['作者']);
    expect(
      (await container.read(listProvider.future)).latest.single,
      same(entry),
    );
    expect(second.listQueries, ['作者']);
  });
}
