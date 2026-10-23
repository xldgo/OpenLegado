import '../app/bootstrap/application_dependencies.dart'
    show webDavServiceProvider, backupRepositoryProvider;
export '../app/bootstrap/application_dependencies.dart'
    show webDavServiceProvider, backupRepositoryProvider;
import '../features/read_aloud/cloud_tts_providers.dart';
import '../domain/contracts/backup_password_store.dart';
import '../platform/backup/backup_password_store.dart';
import '../app/bootstrap/application_dependencies.dart' show mockModeProvider;
import 'webdav_connection_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/backup_service.dart';
import 'restore_ignore_provider.dart';

final backupPasswordStoreProvider = Provider<BackupPasswordStore>(
  (ref) => ref.watch(mockModeProvider)
      ? MemoryBackupPasswordStore()
      : SecureBackupPasswordStore(),
);

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    repository: ref.watch(backupRepositoryProvider),
    webDav: ref.watch(webDavServiceProvider),
    passwords: ref.watch(backupPasswordStoreProvider),
    connections: ref.watch(webDavConnectionRepositoryProvider),
    cloudTts: ref.watch(cloudTtsRepositoryProvider),
    cloudCredentials: ref.watch(cloudTtsCredentialStoreProvider),
    ignore: ref.watch(restoreIgnoreRepositoryProvider),
  );
});
