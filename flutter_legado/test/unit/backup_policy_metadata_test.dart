import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/data/repositories/preferences_backup_metadata_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_backup_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/services/backup_preferences_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('备份策略可重读，安装身份与执行记录保留本机且不随备份恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final service = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(service.dispose);
    final repository = AppBackupSettingsRepository(service);
    await repository.load();
    await repository.update(
      backupPath: 'local-backup',
      onlyLatestBackup: false,
      autoCheckNewBackup: false,
      autoBackup: true,
      autoBackupIntervalDays: 7,
      autoBackupWebDav: true,
      includeCloudCredentials: true,
    );
    final saved = repository.current;
    await repository.reload();
    expect(repository.current, saved);
    expect(saved.autoBackup, isTrue);
    expect(saved.autoBackupIntervalDays, 7);
    expect(
      () => repository.update(autoBackupIntervalDays: 0),
      throwsArgumentError,
    );
    final metadata = PreferencesBackupMetadataRepository();
    final first = await metadata.load();
    await metadata.save(
      first.copyWith(
        lastBackupMs: 123,
        remoteScope: 'dav-a',
        seenRemote: 'fixture.zip',
      ),
    );
    final reloaded = await PreferencesBackupMetadataRepository().load();
    expect(reloaded.deviceId, first.deviceId);
    expect(reloaded.lastBackupMs, 123);
    final prefs = BackupPreferencesService();
    final snapshot = await prefs.collectForBackup({});
    expect(snapshot.containsKey('backup_local_metadata'), isFalse);
    expect(snapshot.containsKey('app_backup_path'), isFalse);
    await prefs.applyFromBackup({
      'backup_local_metadata': 'invalid',
      'app_backup_path': 'other-device',
    }, {});
    expect((await metadata.load()).deviceId, first.deviceId);
    expect(
      (await SharedPreferences.getInstance()).getString('app_backup_path'),
      'local-backup',
    );
  });
}
