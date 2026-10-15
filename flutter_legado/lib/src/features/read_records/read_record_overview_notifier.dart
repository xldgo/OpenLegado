import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../bookshelf/bookshelf.dart';
import 'read_record_dataset.dart';
import 'read_record_overview_calculator.dart';
import 'read_record_overview_state.dart';

/// 周期选择独立于记录页搜索；所有数据来自真实、未过滤的存储快照。— Codex + UI
class ReadRecordOverviewNotifier extends Notifier<ReadRecordOverviewState> {
  int _requestGeneration = 0;

  @override
  ReadRecordOverviewState build() {
    final data = ref.watch(readRecordDatasetProvider);
    final sessions = ref.watch(readRecordSessionsProvider);
    final books = ref.watch(bookshelfNotifierProvider.select((s) => s.books));
    final previous =
        stateOrNull ?? ReadRecordOverviewState(referenceDate: DateTime.now());
    if (data.asData case final snapshot?) {
      return computeOverview(
        period: previous.period,
        referenceDate: previous.referenceDate,
        details: snapshot.value.details,
        records: snapshot.value.records,
        shelfBooks: books,
        sessions: sessions.asData?.value ?? const [],
      ).copyWith(
        isLoading:
            data.isLoading ||
            (previous.period == ReadPeriod.day && sessions.isLoading),
        error: previous.period == ReadPeriod.day
            ? sessions.error?.toString()
            : null,
      );
    }
    return previous.copyWith(
      isLoading: data.isLoading,
      error: data.error?.toString(),
      clearError: !data.hasError,
    );
  }

  void setPeriod(ReadPeriod period) {
    if (state.period == period) return;
    _select(period, state.referenceDate);
  }

  void previousPeriod() => _select(
    state.period,
    ReadRecordOverviewCalculator.stepDate(
      state.period,
      state.referenceDate,
      -1,
    ),
  );

  void nextPeriod() => _select(
    state.period,
    ReadRecordOverviewCalculator.stepDate(state.period, state.referenceDate, 1),
  );

  void _select(ReadPeriod period, DateTime date) {
    final snapshot = ref.read(readRecordDatasetProvider).asData?.value;
    final sessions = ref.read(readRecordSessionsProvider);
    state = snapshot == null
        ? state.copyWith(period: period, referenceDate: date)
        : computeOverview(
            period: period,
            referenceDate: date,
            details: snapshot.details,
            records: snapshot.records,
            shelfBooks: ref.read(bookshelfNotifierProvider).books,
            sessions: sessions.asData?.value ?? const [],
          ).copyWith(
            isLoading: period == ReadPeriod.day && sessions.isLoading,
            error: period == ReadPeriod.day ? sessions.error?.toString() : null,
          );
  }

  /// 明确重新查询；重叠请求、销毁和数据源替换后的旧结果不回写。
  Future<void> refresh() async {
    final generation = ++_requestGeneration;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait<Object>([
        ref.refresh(readRecordDatasetProvider.future),
        ref.refresh(readRecordSessionsProvider.future),
      ]);
      final snapshot = results[0] as ReadRecordDataset;
      final sessions = results[1] as List<ReadRecordSession>;
      if (!ref.mounted || generation != _requestGeneration) return;
      state = computeOverview(
        period: state.period,
        referenceDate: state.referenceDate,
        details: snapshot.details,
        records: snapshot.records,
        shelfBooks: ref.read(bookshelfNotifierProvider).books,
        sessions: sessions,
      );
    } catch (error) {
      if (ref.mounted && generation == _requestGeneration) {
        state = state.copyWith(isLoading: false, error: error.toString());
      }
    }
  }

  static ReadRecordOverviewState computeOverview({
    required ReadPeriod period,
    required DateTime referenceDate,
    required List<ReadRecordDetail> details,
    required List<ReadRecord> records,
    required List<Book> shelfBooks,
    List<ReadRecordSession> sessions = const [],
  }) => ReadRecordOverviewCalculator.compute(
    period: period,
    referenceDate: referenceDate,
    details: details,
    records: records,
    shelfBooks: shelfBooks,
    sessions: sessions,
  );

  static (DateTime, DateTime) getPeriodRange(
    ReadPeriod period,
    DateTime refDate,
  ) => ReadRecordOverviewCalculator.getPeriodRange(period, refDate);
}

final readRecordOverviewNotifierProvider =
    NotifierProvider<ReadRecordOverviewNotifier, ReadRecordOverviewState>(
      ReadRecordOverviewNotifier.new,
    );

/// 首页固定展示累计排行及当月日历，不跟随总览页的日期导航。— Codex + UI
final homeReadRecordOverviewProvider = Provider<ReadRecordOverviewState>((ref) {
  final snapshot = ref.watch(readRecordDatasetProvider);
  final books = ref.watch(bookshelfNotifierProvider.select((s) => s.books));
  final today = DateTime.now();
  final data = snapshot.asData?.value;
  return data == null
      ? ReadRecordOverviewState(
          referenceDate: today,
          isLoading: snapshot.isLoading,
          error: snapshot.error?.toString(),
        )
      : ReadRecordOverviewCalculator.compute(
          period: ReadPeriod.all,
          referenceDate: today,
          details: data.details,
          records: data.records,
          shelfBooks: books,
        );
});
