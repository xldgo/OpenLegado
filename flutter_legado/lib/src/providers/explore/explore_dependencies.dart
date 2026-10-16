import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/explore_service.dart';
import '../../domain/contracts/explore_state_repository.dart';
import '../../domain/contracts/book_source_query_service.dart';
import '../../domain/contracts/book_source_debug_service.dart';
import '../providers.dart';

/// 各能力共享应用装配，也可独立注入。— Codex + UI
final exploreServiceProvider = Provider<ExploreService>(
  (ref) => ref.watch(bookApiProvider).exploreService,
);
final exploreStateRepositoryProvider = Provider<ExploreStateRepository>(
  (ref) => ref.watch(bookApiProvider).exploreStateRepository,
);
final bookSourceQueryServiceProvider = Provider<BookSourceQueryService>(
  (ref) => ref.watch(bookApiProvider).bookSourceQueryService,
);
final bookSourceDebugServiceProvider = Provider<BookSourceDebugService>(
  (ref) => ref.watch(bookApiProvider).bookSourceDebugService,
);
