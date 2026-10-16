export '../app/bootstrap/application_dependencies.dart'
    show
        bookImageRepositoryProvider,
        audioCacheRepositoryProvider,
        audioCacheDownloadServiceProvider,
        audioBookServiceProvider,
        videoDanmakuServiceProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/video_progress_repository.dart';
import '../data/repositories/config_video_progress_repository.dart';
import 'config_provider.dart';

/// 媒体各域复用应用装配，可独立覆盖。— Codex + UI

final videoProgressRepositoryProvider = Provider<VideoProgressRepository>(
  (ref) => ConfigVideoProgressRepository(ref.watch(configRepositoryProvider)),
);
