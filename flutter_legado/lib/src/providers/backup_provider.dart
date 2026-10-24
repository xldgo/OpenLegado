import '../features/remote_books/application/remote_server_provider.dart';
import '../domain/models/backup_metadata.dart';
import '../features/settings/application/backup_automation_controller.dart';
import '../domain/contracts/backup_metadata_repository.dart';
import '../data/repositories/preferences_backup_metadata_repository.dart';
import 'backup_settings_provider.dart';
import '../app/bootstrap/application_dependencies.dart'
    show webDavServiceProvider, backupRepositoryProvider;
export '../app/bootstrap/application_dependencies.dart'
    show webDavServiceProvider, backupRepositoryProvider;
import '../features/read_aloud/cloud_tts_providers.dart';
import '../domain/contracts/backup_password_store.dart';
import '../platform/backup/backup_password_store.dart';
import '../app/bootstrap/application_dependencies.dart' show mockModeProvider;
import 'webdav_connection_provider.dart';
import 'device_name_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/backup_service.dart';
import 'restore_ignore_provider.dart';

final backupPasswordStoreProvider = Provider<BackupPasswordStore>(
  (ref) => ref.watch(mockModeProvider)
      ? MemoryBackupPasswordStore()
      : SecureBackupPasswordStore(),
);

final backupMetadataRepositoryProvider = Provider<BackupMetadataRepository>(
  (ref) => PreferencesBackupMetadataRepository(),
);
final backupAutomationControllerProvider = Provider<BackupAutomationController>(
  (ref) {
    final controller = BackupAutomationController(
      ref.watch(backupServiceProvider),
    );
    ref.onDispose(controller.dispose);
    return controller;
  },
);
final backupAutomationStateProvider = StreamProvider<BackupAutomationState>((
  ref,
) async* {
  final controller = ref.watch(backupAutomationControllerProvider);
  yield controller.state;
  yield* controller.changes;
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    repository: ref.watch(backupRepositoryProvider),
    settings: ref.watch(backupSettingsRepositoryProvider),
    remoteServers: ref.watch(remoteServerRepositoryProvider),
    metadata: ref.watch(backupMetadataRepositoryProvider),
    webDav: ref.watch(webDavServiceProvider),
    passwords: ref.watch(backupPasswordStoreProvider),
    connections: ref.watch(webDavConnectionRepositoryProvider),
    defaultDeviceName: () => ref.read(systemDeviceNameProvider.future),
    cloudTts: ref.watch(cloudTtsRepositoryProvider),
    cloudCredentials: ref.watch(cloudTtsCredentialStoreProvider),
    ignore: ref.watch(restoreIgnoreRepositoryProvider),
  );
});

final backupMetadataProvider = FutureProvider<BackupMetadata>((ref) {
  ref.watch(backupAutomationStateProvider);
  return ref.watch(backupMetadataRepositoryProvider).load();
});
