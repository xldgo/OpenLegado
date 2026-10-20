import '../../../../utils/error_message.dart';
import '../../../../providers/rss_repository_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import 'rss_history_state.dart';

export 'rss_history_state.dart';

/// RSS 历史页 Riverpod Notifier
///
/// 职责严格限定（对齐 UI_RESTRUCTURE_PLAN.md §0.2 铁律）：
/// - 已读记录列表经 `RssReadRecordRepository.rssListReadRecords` 委托 Rust（按阅读时间降序），
///   数据层将snake_case载荷解析为已有记录模型。
/// - 清空经 `RssReadRecordRepository.rssClearReadRecords` 委托 Rust，成功后重新拉取列表。
class RssHistoryNotifier extends Notifier<RssHistoryState> {
  @override
  RssHistoryState build() => const RssHistoryState();

  /// 加载已读记录列表；[origin] 非空时走按源查询（F3-17）
  Future<void> load({int? limit, String? origin}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final records = origin != null
          ? await ref
                .read(rssReadRecordRepositoryProvider)
                .rssListReadRecordsByOrigin(origin, limit)
          : await ref
                .read(rssReadRecordRepositoryProvider)
                .rssListReadRecords(limit);
      state = state.copyWith(records: records, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: errorMessage(e), isLoading: false);
    }
  }

  /// 清空全部已读记录（成功后重新拉取列表）
  Future<void> clear() async {
    state = state.copyWith(isClearing: true, error: null);
    try {
      await ref.read(rssReadRecordRepositoryProvider).rssClearReadRecords();
      state = state.copyWith(isClearing: false);
      await load();
    } catch (e) {
      state = state.copyWith(error: errorMessage(e), isClearing: false);
    }
  }
}

/// RSS 历史 Notifier 全局 Provider
///
/// 使用方式：
/// ```dart
/// final state = ref.watch(rssHistoryNotifierProvider);
/// ref.read(rssHistoryNotifierProvider.notifier).load();
/// ```
final rssHistoryNotifierProvider =
    NotifierProvider<RssHistoryNotifier, RssHistoryState>(
      RssHistoryNotifier.new,
    );
