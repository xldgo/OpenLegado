import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/chapter_content_service.dart';
import 'chapter_cache_provider.dart';
import 'reading_provider.dart';

/// 同一装配中的阅读器、朗读与预加载使用相同正文策略。— Codex + UI
final chapterContentServiceProvider = Provider<ChapterContentService>(
  (ref) => ChapterContentService(
    reading: ref.watch(readingRepositoryProvider),
    cache: ref.watch(chapterCacheRepositoryProvider),
  ),
);
