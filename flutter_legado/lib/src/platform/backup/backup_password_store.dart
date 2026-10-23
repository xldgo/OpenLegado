import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/contracts/backup_password_store.dart';

final class SecureBackupPasswordStore implements BackupPasswordStore {
  SecureBackupPasswordStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              resetOnError: false,
              migrateOnAlgorithmChange: false,
              storageNamespace: 'legado_backup',
            ),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
            mOptions: MacOsOptions(
              usesDataProtectionKeychain: false,
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  final FlutterSecureStorage _storage;
  static const _key = 'local_backup_password';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String? password) => password == null || password.isEmpty
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: password);
}

final class MemoryBackupPasswordStore implements BackupPasswordStore {
  String? _password;
  @override
  Future<String?> read() async => _password;
  @override
  Future<void> write(String? password) async {
    _password = password;
  }
}
