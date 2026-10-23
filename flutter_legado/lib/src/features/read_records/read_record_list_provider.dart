export 'read_record_dataset.dart' show readRecordSessionsProvider;

import '../../models/book_chapter.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/reading_provider.dart';
import 'read_record_dataset.dart';
import 'read_record_notifier.dart';
import 'read_record_state.dart';
import 'read_record_list_calculator.dart';
import 'read_record_repository_provider.dart';
import '../../domain/contracts/read_record_changes.dart';
import '../../domain/models/read_record_timeline_entry.dart';

/// 直接查询Rust时间线，成功写入后失效；Riverpod负责查询参数与实例的异步归属。
final readRecordTimelineProvider = FutureProvider.autoDispose
    .family<List<ReadRecordTimelineEntry>, String>((ref, query) {
      final repository = ref.watch(readRecordRepositoryProvider);
      if (repository is ReadRecordChangeSource) {
        final subscription = (repository as ReadRecordChangeSource).changes
            .listen((_) {
              if (ref.mounted) ref.invalidateSelf();
            });
        ref.onDispose(subscription.cancel);
      }
      return repository.getReadRecordTimeline(query);
    });

final readRecordListProvider =
    Provider.autoDispose<AsyncValue<List<ReadRecordListEntry>>>((ref) {
      final controls = ref.watch(readRecordNotifierProvider);
      if (controls.displayMode == ReadRecordDisplayMode.timeline) {
        return ref
            .watch(readRecordTimelineProvider(controls.searchQuery))
            .whenData(
              (rows) => rows
                  .map(
                    (row) => ReadRecordListEntry(
                      bookName: row.bookName,
                      author: row.author,
                      key: 'session:${row.sessionIds.first}',
                      date: row.date,
                      durationMs: row.durationMs,
                      lastRead: row.endTime,
                      startTime: row.startTime,
                      bookUrl: row.bookUrl,
                      chapterIndex: row.chapterIndex,
                      sessionIds: row.sessionIds,
                    ),
                  )
                  .toList(),
            );
      }
      return ref
          .watch(readRecordDatasetProvider)
          .whenData(
            (data) => ReadRecordListCalculator.build(
              mode: controls.displayMode,
              records: data.records,
              details: data.details,
              query: controls.searchQuery,
            ),
          );
    });

final _readRecordChaptersProvider = FutureProvider.autoDispose
    .family<List<BookChapter>, String>(
      (ref, url) => ref.watch(readingRepositoryProvider).getChapters(url),
    );

final readRecordChapterTitleProvider = FutureProvider.autoDispose
    .family<String?, (String, int)>((ref, key) async {
      if (key.$1.isEmpty) return null;
      final chapters = await ref.watch(
        _readRecordChaptersProvider(key.$1).future,
      );
      return chapters.where((c) => c.index == key.$2).firstOrNull?.title;
    });
