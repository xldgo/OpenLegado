import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/app_backup_settings_repository.dart';
import '../domain/contracts/backup_settings_repository.dart';
import '../domain/models/backup_settings.dart';
import 'app_settings_provider.dart';

final backupSettingsRepositoryProvider = Provider<BackupSettingsRepository>(
  (ref) => AppBackupSettingsRepository(ref.watch(appSettingsServiceProvider)),
);

final backupSettingsProvider = StreamProvider<BackupSettings>((ref) async* {
  final repository = ref.watch(backupSettingsRepositoryProvider);
  await repository.load();
  yield* repository.watch();
});
