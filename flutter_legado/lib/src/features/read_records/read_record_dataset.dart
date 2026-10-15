import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/read_record_changes.dart';
import '../../models/models.dart';
import 'read_record_repository_provider.dart';

/// 所有统计共用未过滤的数据快照；异步代次由 Riverpod 管理。— Codex + UI
class ReadRecordDataset {
  final List<ReadRecord> records;
  final List<ReadRecordDetail> details;
  ReadRecordDataset({
    required List<ReadRecord> records,
    required List<ReadRecordDetail> details,
  }) : records = List.unmodifiable(records),
       details = List.unmodifiable(details);
}

final readRecordDatasetProvider = FutureProvider<ReadRecordDataset>((
  ref,
) async {
  final repository = ref.watch(readRecordRepositoryProvider);
  if (repository is ReadRecordChangeSource) {
    final subscription = (repository as ReadRecordChangeSource).changes.listen((
      _,
    ) {
      if (ref.mounted) ref.invalidateSelf();
    });
    ref.onDispose(subscription.cancel);
  }
  final records = repository.getReadRecords();
  final details = repository.getAllReadRecordDetails();
  // 同时注册两个失败处理器，避免另一查询先失败时出现未处理的 Future。
  final results = await Future.wait<Object>([records, details]);
  return ReadRecordDataset(
    records: results[0] as List<ReadRecord>,
    details: results[1] as List<ReadRecordDetail>,
  );
});

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
