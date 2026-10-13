import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/contracts/cloud_tts_credential_store.dart';

/// 锁屏时可读取首次解锁后的凭据；不使用普通偏好作为回退。— Codex + UI
final class SecureCloudTtsCredentialStore implements CloudTtsCredentialStore {
  SecureCloudTtsCredentialStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              resetOnError: false,
              migrateOnAlgorithmChange: false,
              storageNamespace: 'legado_cloud_tts',
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
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String apiKey) =>
      _storage.write(key: key, value: apiKey);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class MemoryCloudTtsCredentialStore implements CloudTtsCredentialStore {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String apiKey) async {
    _values[key] = apiKey;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
