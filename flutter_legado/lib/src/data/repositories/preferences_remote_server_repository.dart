import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/contracts/remote_server_repository.dart';
import '../../domain/models/remote_server_config.dart';
import '../../services/settings_write_queue.dart';

/// 保留既有JSON与选中键，串行读改写并检查落盘结果。— connection_migration + UI
final class PreferencesRemoteServerRepository
    implements RemoteServerRepository {
  PreferencesRemoteServerRepository({
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const _serversKey = 'remote_servers';
  static const _selectedKey = 'remote_server_id';
  final Future<SharedPreferences> Function() _loadPreferences;
  final _queue = SettingsWriteQueue();

  RemoteServerSnapshot _read(SharedPreferences prefs) {
    final raw = prefs.getString(_serversKey) ?? '[]';
    final selectedId = prefs.getInt(_selectedKey) ?? defaultRemoteServerId;
    var servers = <RemoteServerConfig>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        servers = decoded
            .whereType<Map>()
            .map(
              (entry) =>
                  RemoteServerConfig.fromJson(Map<String, dynamic>.from(entry)),
            )
            .toList();
      }
    } catch (_) {
      // 沿用原损坏JSON回退空列表的规则，不覆盖原始存储。
    }
    return RemoteServerSnapshot(servers: servers, selectedId: selectedId);
  }

  Future<RemoteServerSnapshot> _run(
    Future<RemoteServerSnapshot> Function(SharedPreferences) operation,
  ) async {
    late RemoteServerSnapshot result;
    await _queue.run(() async {
      result = await operation(await _loadPreferences());
    });
    return result;
  }

  @override
  Future<RemoteServerSnapshot> load() => _run((prefs) async => _read(prefs));

  @override
  Future<RemoteServerSnapshot> save(RemoteServerConfig server) => _run((
    prefs,
  ) async {
    final current = _read(prefs);
    final servers = [...current.servers];
    final index = servers.indexWhere((entry) => entry.id == server.id);
    if (index < 0) {
      servers.add(server);
    } else {
      servers[index] = server;
    }
    await _write(prefs, {
      _serversKey: jsonEncode(servers.map((entry) => entry.toJson()).toList()),
    });
    return RemoteServerSnapshot(
      servers: servers,
      selectedId: current.selectedId,
    );
  });

  @override
  Future<RemoteServerSnapshot> select(int id) => _run((prefs) async {
    final current = _read(prefs);
    await _write(prefs, {_selectedKey: id});
    return RemoteServerSnapshot(servers: current.servers, selectedId: id);
  });

  @override
  Future<RemoteServerSnapshot> delete(int id) => _run((prefs) async {
    final current = _read(prefs);
    final servers = current.servers.where((entry) => entry.id != id).toList();
    final selectedId = current.selectedId == id
        ? defaultRemoteServerId
        : current.selectedId;
    await _write(prefs, {
      _serversKey: jsonEncode(servers.map((entry) => entry.toJson()).toList()),
      if (current.selectedId == id) _selectedKey: selectedId,
    });
    return RemoteServerSnapshot(servers: servers, selectedId: selectedId);
  });

  Future<bool> _set(SharedPreferences prefs, String key, Object? value) {
    if (value == null) return prefs.remove(key);
    if (value is int) return prefs.setInt(key, value);
    return prefs.setString(key, value as String);
  }

  Future<void> _write(
    SharedPreferences prefs,
    Map<String, Object> values,
  ) async {
    final previous = <String, Object?>{
      for (final key in values.keys)
        key: key == _serversKey ? prefs.getString(key) : prefs.getInt(key),
    };
    final attempted = <String>[];
    try {
      for (final entry in values.entries) {
        // 失败的当前键也可能已改动Preferences内存缓存。
        attempted.add(entry.key);
        if (!await _set(prefs, entry.key, entry.value)) {
          throw StateError('远程服务器写入被拒绝');
        }
      }
    } catch (_) {
      var restored = true;
      for (final key in attempted.reversed) {
        try {
          restored = await _set(prefs, key, previous[key]) && restored;
        } catch (_) {
          restored = false;
        }
      }
      // 平台错误可能含凭据，只向调用方返回通用失败信息。
      throw StateError(restored ? '远程服务器保存失败，请重试' : '远程服务器保存失败，部分配置恢复失败，请重试');
    }
  }
}
