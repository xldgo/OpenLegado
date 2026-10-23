import 'package:flutter_legado/src/data/repositories/mock_read_record_repository.dart';
import 'package:flutter_legado/src/domain/models/read_record_timeline_entry.dart';
import 'package:flutter_legado/src/features/read_records/read_record_list_provider.dart';
import 'package:flutter_legado/src/features/read_records/read_record_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Timeline extends MockReadRecordRepository {
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
  test('时间线透传搜索、跟随写入刷新及仓储替换，错误不变成空结果', () async {
    final first = _Timeline();
    final container = ProviderContainer(
      overrides: [readRecordRepositoryProvider.overrideWithValue(first)],
    );
    addTearDown(container.dispose);
    final provider = readRecordTimelineProvider('作者');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    expect(await container.read(provider.future), isEmpty);
    expect(first.queries, ['作者']);

    final failure = StateError('查询失败');
    first.failure = failure;
    await first.clearReadRecords();
    await container.pump();
    await expectLater(container.read(provider.future), throwsA(same(failure)));

    final second = _Timeline()
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
  });
}
