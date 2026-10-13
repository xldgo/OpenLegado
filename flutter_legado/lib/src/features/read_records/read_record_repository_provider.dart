import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/read_record_repository.dart';
import '../../providers/providers.dart';

/// 页面、首页与阅读器共享根实例的记录存储。— Codex + UI
final readRecordRepositoryProvider = Provider<ReadRecordRepository>(
  (ref) => ref.watch(bookApiProvider).readRecordRepository,
);
