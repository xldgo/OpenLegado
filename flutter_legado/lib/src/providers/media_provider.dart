import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../domain/contracts/book_image_repository.dart';
import '../domain/contracts/audio_cache_repository.dart';
import '../domain/contracts/audio_cache_download_service.dart';
import '../domain/contracts/audio_book_service.dart';
import '../domain/contracts/video_danmaku_service.dart';

/// 媒体各域复用应用装配，可独立覆盖。— Codex + UI
final bookImageRepositoryProvider = Provider<BookImageRepository>(
  (ref) => ref.watch(bookApiProvider).bookImageRepository,
);
final audioCacheRepositoryProvider = Provider<AudioCacheRepository>(
  (ref) => ref.watch(bookApiProvider).audioCacheRepository,
);
final audioCacheDownloadServiceProvider = Provider<AudioCacheDownloadService>(
  (ref) => ref.watch(bookApiProvider).audioCacheDownloadService,
);
final audioBookServiceProvider = Provider<AudioBookService>(
  (ref) => ref.watch(bookApiProvider).audioBookService,
);
final videoDanmakuServiceProvider = Provider<VideoDanmakuService>(
  (ref) => ref.watch(bookApiProvider).videoDanmakuService,
);
