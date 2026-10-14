import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/search_service.dart';
import '../../domain/contracts/search_history_repository.dart';
import '../../providers/providers.dart' show bookApiProvider;

/// 分享根实例已有能力，替换根时重新装配。— Codex + UI
final searchServiceProvider = Provider<SearchService>(
  (ref) => ref.watch(bookApiProvider).searchService,
);
final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
  (ref) => ref.watch(bookApiProvider).searchHistoryRepository,
);
