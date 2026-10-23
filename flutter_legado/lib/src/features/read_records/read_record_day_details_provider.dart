import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/read_record_changes.dart';
import '../bookshelf/bookshelf.dart';
import 'read_record_repository_provider.dart';
import 'read_record_overview_state.dart';

/// 日历明细直接查询Rust投影，保留全部单书结果。— Codex + UI
final readRecordDayDetailsProvider = FutureProvider.autoDispose
    .family<List<ReadBookRanking>, DateTime>((ref, date) {
      final repository = ref.watch(readRecordRepositoryProvider);
      ref.watch(bookshelfNotifierProvider.select((state) => state.books));
      if (repository is ReadRecordChangeSource) {
        final subscription = (repository as ReadRecordChangeSource).changes
            .listen((_) {
              ref.invalidateSelf();
            });
        ref.onDispose(subscription.cancel);
      }
      return repository.getReadRecordBooksForDay(date);
    });
