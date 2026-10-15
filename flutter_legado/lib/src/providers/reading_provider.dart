import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/reading_repository.dart';
import 'providers.dart';

/// 共享根装配的阅读仓储，测试可独立替换数据访问。— Codex + UI
final readingRepositoryProvider = Provider<ReadingRepository>(
  (ref) => ref.watch(bookApiProvider).readingRepository,
);
