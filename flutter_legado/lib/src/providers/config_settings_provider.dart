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
