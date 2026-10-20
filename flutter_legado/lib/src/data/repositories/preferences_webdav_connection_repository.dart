import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/contracts/webdav_connection_repository.dart';
import '../../domain/models/webdav_connection.dart';
import '../../services/settings_write_queue.dart';

/// 保留原五个偏好键，连接读写串行，普通失败恢复本次写入。— connection_migration + UI
final class PreferencesWebDavConnectionRepository
    implements WebDavConnectionRepository {
  PreferencesWebDavConnectionRepository({
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const _urlKey = 'sync_webdav_url';
  static const _usernameKey = 'sync_webdav_username';
  static const _passwordKey = 'sync_webdav_password';
  static const _remoteDirKey = 'sync_webdav_remote_dir';
  static const _deviceNameKey = 'sync_webdav_device_name';

  final Future<SharedPreferences> Function() _loadPreferences;
  final _queue = SettingsWriteQueue();

  @override
  Future<WebDavConnection> load() async {
    late WebDavConnection connection;
    await _queue.run(() async {
      try {
        final prefs = await _loadPreferences();
        connection = WebDavConnection(
          url: prefs.getString(_urlKey) ?? '',
          username: prefs.getString(_usernameKey) ?? '',
          password: prefs.getString(_passwordKey) ?? '',
          remoteDir: prefs.getString(_remoteDirKey) ?? '/legado/',
          deviceName: prefs.getString(_deviceNameKey) ?? '',
        );
      } catch (_) {
        // 连接读取失败仍上报，平台原始诊断不进入消费者提示。
        throw StateError('WebDAV 连接读取失败，请重试');
      }
    });
    return connection;
  }

  @override
  Future<WebDavConnection> save(WebDavConnection connection) async {
    final saved = connection.normalized;
    await _queue.run(() async {
      final prefs = await _loadPreferences();
      final values = <String, String>{
        _urlKey: saved.url,
        _usernameKey: saved.username,
        _passwordKey: saved.password,
        _remoteDirKey: saved.remoteDir,
        _deviceNameKey: saved.deviceName,
      };
      final previous = {
        for (final key in values.keys) key: prefs.getString(key),
      };
      final attempted = <String>[];
      try {
        for (final entry in values.entries) {
          // SharedPreferences会先修改内存缓存，失败的当前键也需要恢复。
          attempted.add(entry.key);
          if (!await prefs.setString(entry.key, entry.value)) {
            throw StateError('WebDAV 连接写入被拒绝');
          }
        }
      } catch (_) {
        var restored = true;
        for (final key in attempted.reversed) {
          try {
            final value = previous[key];
            final success = value == null
                ? await prefs.remove(key)
                : await prefs.setString(key, value);
            restored = success && restored;
          } catch (_) {
            restored = false;
          }
        }
        // 不附带平台异常文本，避免凭据出现在错误或日志中。
        throw StateError(
          restored ? 'WebDAV 连接保存失败，请重试' : 'WebDAV 连接保存失败，部分配置恢复失败，请重试',
        );
      }
    });
    return saved;
  }
}
