import '../../models/book_chapter.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/read_record_session.dart';
import '../../domain/contracts/read_record_changes.dart';
import '../../providers/reading_provider.dart';
import 'read_record_dataset.dart';
import 'read_record_repository_provider.dart';
import 'read_record_notifier.dart';
import 'read_record_state.dart';
import 'read_record_list_calculator.dart';

final readRecordSessionsProvider =
    FutureProvider.autoDispose<List<ReadRecordSession>>((ref) {
      final repo = ref.watch(readRecordRepositoryProvider);
      if (repo is ReadRecordChangeSource) {
        final subscription = (repo as ReadRecordChangeSource).changes.listen((
          _,
        ) {
          if (ref.mounted) ref.invalidateSelf();
        });
        ref.onDispose(subscription.cancel);
      }
      return repo.getReadRecordSessions();
    });

final readRecordListProvider =
    Provider.autoDispose<AsyncValue<List<ReadRecordListEntry>>>((ref) {
      final controls = ref.watch(readRecordNotifierProvider);
      final dataset = ref.watch(readRecordDatasetProvider);
      if (controls.displayMode == ReadRecordDisplayMode.timeline) {
        return ref
            .watch(readRecordSessionsProvider)
            .whenData(
              (sessions) => ReadRecordListCalculator.build(
                mode: controls.displayMode,
                records: const [],
                details: const [],
                sessions: sessions,
                query: controls.searchQuery,
              ),
            );
      }
      return dataset.whenData(
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
