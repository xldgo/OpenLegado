import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/read_record_changes.dart';
import '../../models/models.dart';
import 'read_record_repository_provider.dart';

/// 最近阅读只需累计记录，不为首页额外拉取全部每日明细。
final readRecordRecordsProvider = FutureProvider<List<ReadRecord>>((ref) {
  final repository = ref.watch(readRecordRepositoryProvider);
  if (repository is ReadRecordChangeSource) {
    final subscription = (repository as ReadRecordChangeSource).changes.listen((
      _,
    ) {
      ref.invalidateSelf();
    });
    ref.onDispose(subscription.cancel);
  }
  return repository.getReadRecords();
});
