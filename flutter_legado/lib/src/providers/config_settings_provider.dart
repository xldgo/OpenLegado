import '../data/repositories/app_request_settings_repository.dart';
import '../data/repositories/app_cache_download_settings_repository.dart';
import '../domain/contracts/cache_download_settings_repository.dart';
import '../domain/models/cache_download_settings.dart';
import '../domain/contracts/request_settings_repository.dart';
import '../domain/models/request_settings.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings_provider.dart';
import '../data/repositories/app_change_source_settings_repository.dart';
import '../domain/contracts/change_source_settings_repository.dart';
import '../data/repositories/app_audio_playback_settings_repository.dart';
import '../domain/contracts/audio_playback_settings_repository.dart';
import '../data/repositories/app_service_settings_repository.dart';
import '../domain/contracts/service_settings_repository.dart';
import '../data/repositories/app_manga_settings_repository.dart';
import '../domain/contracts/manga_settings_repository.dart';

/// 普通配置领域共享同一设置服务，无第二份缓存或写队列。— Codex + UI
final changeSourceSettingsRepositoryProvider =
    Provider<ChangeSourceSettingsRepository>(
      (ref) => AppChangeSourceSettingsRepository(
        ref.watch(appSettingsServiceProvider),
      ),
    );
final audioPlaybackSettingsRepositoryProvider =
    Provider<AudioPlaybackSettingsRepository>(
      (ref) => AppAudioPlaybackSettingsRepository(
        ref.watch(appSettingsServiceProvider),
      ),
    );
final serviceSettingsRepositoryProvider = Provider<ServiceSettingsRepository>(
  (ref) => AppServiceSettingsRepository(ref.watch(appSettingsServiceProvider)),
);
final mangaSettingsRepositoryProvider = Provider<MangaSettingsRepository>(
  (ref) => AppMangaSettingsRepository(ref.watch(appSettingsServiceProvider)),
);

/// 并发设置与其他Rust配置共享快照及写入失败回退。— Codex + UI
final requestSettingsRepositoryProvider = Provider<RequestSettingsRepository>(
  (ref) => AppRequestSettingsRepository(ref.watch(appSettingsServiceProvider)),
);
final requestSettingsProvider = StreamProvider<RequestSettings>((ref) async* {
  final repository = ref.watch(requestSettingsRepositoryProvider);
  await repository.load();
  yield* repository.watch();
});

/// 离线下载配置有独立投影，避免改变搜索并发或正文预下载设置。
final cacheDownloadSettingsRepositoryProvider =
    Provider<CacheDownloadSettingsRepository>(
      (ref) => AppCacheDownloadSettingsRepository(
        ref.watch(appSettingsServiceProvider),
      ),
    );
final cacheDownloadSettingsProvider = StreamProvider<CacheDownloadSettings>((
  ref,
) async* {
  final repository = ref.watch(cacheDownloadSettingsRepositoryProvider);
  await repository.load();
  yield* repository.watch();
});
