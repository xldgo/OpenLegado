import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/read_record_changes.dart';
import '../../domain/models/read_record_statistics.dart';
import '../bookshelf/bookshelf.dart';
import 'read_record_repository_provider.dart';
import 'read_record_dataset.dart';
import 'read_record_overview_calculator.dart';
import 'read_record_overview_state.dart';

/// 周期与日期是页面状态，查询与迟到结果归属交给Riverpod。— Codex + UI
class _OverviewSelection extends Notifier<(ReadPeriod, DateTime)> {
  @override
  (ReadPeriod, DateTime) build() {
    final now = DateTime.now();
    return (ReadPeriod.day, DateTime(now.year, now.month, now.day));
  }

  void select(ReadPeriod period, DateTime date) => state = (period, date);
}

final _selectionProvider =
    NotifierProvider<_OverviewSelection, (ReadPeriod, DateTime)>(
      _OverviewSelection.new,
    );

final readRecordStatisticsProvider = FutureProvider.autoDispose
    .family<ReadRecordStatistics, (ReadPeriod, DateTime)>((ref, query) {
      final repository = ref.watch(readRecordRepositoryProvider);
      // 封面和读完状态由DB读取；书架写回后的状态变化触发重新查询。
      ref.watch(bookshelfNotifierProvider.select((state) => state.books));
      if (repository is ReadRecordChangeSource) {
        final subscription = (repository as ReadRecordChangeSource).changes
            .listen((_) {
              if (ref.mounted) ref.invalidateSelf();
            });
        ref.onDispose(subscription.cancel);
      }
      return repository.getReadRecordOverview(query.$1, query.$2);
    });

ReadRecordOverviewState _overviewState(
  ReadPeriod period,
  DateTime date,
  AsyncValue<ReadRecordStatistics> result,
) {
  final data = result.asData?.value;
  return ReadRecordOverviewState(
    period: period,
    referenceDate: date,
    totalTimeMs: data?.totalTimeMs ?? 0,
    readingDays: data?.readingDays ?? 0,
    totalBooks: data?.totalBooks ?? 0,
    finishedBooks: data?.finishedBooks ?? 0,
    readingBooks: data?.readingBooks ?? 0,
    topBooks: data?.topBooks ?? const [],
    dailyTimeData: data?.dailyTimeData ?? const [],
    dailyTopBook: data?.dailyTopBook ?? const {},
    allDailyTimes: data?.allDailyTimes ?? const {},
    allDailyCounts: data?.allDailyCounts ?? const {},
    isLoading: result.isLoading,
    error: result.error?.toString(),
  );
}

class ReadRecordOverviewNotifier extends Notifier<ReadRecordOverviewState> {
  @override
  ReadRecordOverviewState build() {
    final query = ref.watch(_selectionProvider);
    final result = ref.watch(readRecordStatisticsProvider(query));
    final value = _overviewState(query.$1, query.$2, result);
    if (query.$1 != ReadPeriod.day) return value;
    final sessions = ref.watch(readRecordSessionsProvider);
    return value.copyWith(
      dailyTimeData: ReadRecordOverviewCalculator.hourlyDistribution(
        query.$2,
        sessions.asData?.value ?? const [],
      ),
      isLoading: result.isLoading || sessions.isLoading,
      error: result.error?.toString() ?? sessions.error?.toString(),
    );
  }

  void setPeriod(ReadPeriod period) {
    if (state.period != period) {
      ref.read(_selectionProvider.notifier).select(period, state.referenceDate);
    }
  }

  void previousPeriod() => _step(-1);
  void nextPeriod() => _step(1);
  void _step(int step) => ref
      .read(_selectionProvider.notifier)
      .select(
        state.period,
        ReadRecordOverviewCalculator.stepDate(
          state.period,
          state.referenceDate,
          step,
        ),
      );

  Future<void> refresh() async {
    final query = ref.read(_selectionProvider);
    final requests = <Future<Object?>>[
      ref.refresh(readRecordStatisticsProvider(query).future),
      if (query.$1 == ReadPeriod.day)
        ref.refresh(readRecordSessionsProvider.future),
    ];
    // 错误由当前查询的AsyncValue呈现，不将旧查询的失败写到新页面选择。
    await Future.wait(requests)
        .then<void>((_) {}, onError: (Object _, StackTrace _) {});
  }

  static (DateTime, DateTime) getPeriodRange(
    ReadPeriod period,
    DateTime date,
  ) => ReadRecordOverviewCalculator.getPeriodRange(period, date);
}

final readRecordOverviewNotifierProvider =
    NotifierProvider<ReadRecordOverviewNotifier, ReadRecordOverviewState>(
      ReadRecordOverviewNotifier.new,
    );

/// 首页固定all查询，独立于总览页导航。
final homeReadRecordOverviewProvider = Provider<ReadRecordOverviewState>((ref) {
  final now = DateTime.now();
  final date = DateTime(now.year, now.month, now.day);
  return _overviewState(
    ReadPeriod.all,
    date,
    ref.watch(readRecordStatisticsProvider((ReadPeriod.all, date))),
  );
});
