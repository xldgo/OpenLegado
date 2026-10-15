import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/chapter_cache_repository.dart';
import '../domain/contracts/cache_download_service.dart';
import 'providers.dart';

/// 两种能力共享根装配，消费者可独立替换。— Codex + UI
final chapterCacheRepositoryProvider = Provider<ChapterCacheRepository>(
  (ref) => ref.watch(bookApiProvider).chapterCacheRepository,
);

final cacheDownloadServiceProvider = Provider<CacheDownloadService>(
  (ref) => ref.watch(bookApiProvider).cacheDownloadService,
);
