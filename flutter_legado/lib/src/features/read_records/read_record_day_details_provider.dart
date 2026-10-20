import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bookshelf/bookshelf.dart';
import 'read_record_dataset.dart';
import 'read_record_overview_calculator.dart';
import 'read_record_overview_state.dart';

/// 日历明细复用未过滤快照，随阅读记录保存、删除和清空刷新。— Codex + UI
final readRecordDayDetailsProvider = Provider.autoDispose
    .family<AsyncValue<List<ReadBookRanking>>, DateTime>((ref, date) {
      final data = ref.watch(readRecordDatasetProvider);
      final shelf = ref.watch(
        bookshelfNotifierProvider.select((state) => state.books),
      );
      return data.whenData(
        (snapshot) => ReadRecordOverviewCalculator.booksForDay(
          date: date,
          details: snapshot.details,
          shelfBooks: shelf,
        ),
      );
    });
