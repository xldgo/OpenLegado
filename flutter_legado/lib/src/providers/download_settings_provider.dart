import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/app_download_settings_repository.dart';
import '../domain/contracts/download_settings_repository.dart';
import '../domain/models/download_settings.dart';
import 'app_settings_provider.dart';

/// 页面与阅读器使用相同设置实例及变更流。— Codex + UI
final downloadSettingsRepositoryProvider = Provider<DownloadSettingsRepository>(
  (ref) => AppDownloadSettingsRepository(ref.watch(appSettingsServiceProvider)),
);
final downloadSettingsProvider = StreamProvider<DownloadSettings>((ref) async* {
  final repository = ref.watch(downloadSettingsRepositoryProvider);
  await repository.load();
  yield* repository.watch();
});
