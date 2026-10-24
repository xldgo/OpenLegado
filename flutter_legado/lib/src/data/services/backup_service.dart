import '../../domain/contracts/remote_server_repository.dart';
import '../../domain/models/remote_server_config.dart';
import '../../domain/contracts/backup_settings_repository.dart';
import '../../domain/contracts/backup_metadata_repository.dart';
import '../../domain/models/backup_creation_result.dart';
import '../../domain/models/backup_restore_result.dart';
import 'backup_file_policy.dart';

import 'dart:io';

import '../../domain/contracts/backup_repository.dart';
import '../../domain/contracts/backup_password_store.dart';
import '../../domain/contracts/restore_ignore_repository.dart';
import '../../domain/contracts/webdav_service.dart';
import '../../domain/contracts/webdav_connection_repository.dart';
import '../../domain/contracts/cloud_tts_repository.dart';
import '../../domain/contracts/cloud_tts_credential_store.dart';
import '../../domain/models/webdav_connection.dart';
import '../../platform/device_name.dart';
import 'backup_preferences_service.dart';

/// 文件、远程传输与凭据的应用编排；业务校验、资源重定位和事务由Rust执行。
class BackupService {
  BackupService({
    required this.repository,
    required this.webDav,
    required this.ignore,
    required this.passwords,
    required this.connections,
    required this.cloudTts,
    required this.cloudCredentials,
    required this.settings,
    required this.metadata,
    required this.remoteServers,
    this.clock = DateTime.now,
    this.defaultDeviceName = readSystemDeviceName,
    BackupPreferencesService? preferences,
  }) : _preferences = preferences ?? BackupPreferencesService();
  final BackupRepository repository;
  final WebDavService webDav;
  final RestoreIgnoreRepository ignore;
  final BackupPasswordStore passwords;
  final WebDavConnectionRepository connections;
  final CloudTtsRepository cloudTts;
  final CloudTtsCredentialStore cloudCredentials;
  final BackupPreferencesService _preferences;
  final BackupSettingsRepository settings;
  final RemoteServerRepository remoteServers;
  final BackupMetadataRepository metadata;
  final DateTime Function() clock;
  final Future<String> Function() defaultDeviceName;
  bool _busy = false;
  bool get isBusy => _busy;
  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_busy) throw StateError('已有备份或恢复正在进行');
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }

  Future<String> backupLocal(
    String directory, {
    bool includeCloudCredentials = false,
  }) => _exclusive(
    () => _backupLocal(
      directory,
      includeCloudCredentials: includeCloudCredentials,
    ),
  );
  Future<BackupRestoreOutcome> restoreLocal(String path) =>
      _exclusive(() => _restoreLocal(path));
  Future<void> backupToWebDav(
    WebDavConnection connection, {
    String? localPath,
    bool includeCloudCredentials = false,
  }) => _exclusive(
    () => _backupToWebDav(
      connection,
      localPath: localPath,
      includeCloudCredentials: includeCloudCredentials,
    ),
  );
  Future<BackupRestoreOutcome> restoreFromWebDav(
    WebDavConnection connection, {
    String? fileName,
  }) => _exclusive(() => _restoreFromWebDav(connection, fileName: fileName));

  Future<BackupCreationResult> createBackup(
    String directory, {
    WebDavConnection? uploadConnection,
  }) => _exclusive(() async {
    final policy = await settings.load();
    final state = await metadata.load();
    final connection = await connections.load();
    final deviceName = connection.deviceName.trim().isEmpty
        ? await defaultDeviceName()
        : connection.deviceName;
    final names = BackupFilePolicy(deviceName, state.deviceId);
    final now = clock();
    final path = await _backupLocal(
      directory,
      includeCloudCredentials: policy.includeCloudCredentials,
      fileName: names.name(now),
    );
    final warnings = <String>[];
    if (uploadConnection != null) {
      try {
        await _uploadBackup(uploadConnection, path);
      } catch (_) {
        return BackupCreationResult(
          path: path,
          completed: false,
          warnings: ['本地备份已生成，云端上传失败，请重试'],
        );
      }
    }
    final keep = File(path).uri.pathSegments.last;
    if (policy.onlyLatestBackup) {
      try {
        await for (final entry in Directory(
          directory,
        ).list(followLinks: false)) {
          if (entry is File) {
            final name = File(entry.path).uri.pathSegments.last;
            if (name != keep && names.owns(name)) {
              await entry.delete();
            }
          }
        }
      } catch (_) {
        warnings.add('新备份已生成，部分本地旧备份清理失败');
      }
      if (uploadConnection != null) {
        try {
          for (final name in await listRemoteBackups(uploadConnection)) {
            if (name != keep && names.owns(name)) {
              await webDav.webdavDelete(uploadConnection, name);
            }
          }
        } catch (_) {
          warnings.add('新备份已上传，部分云端旧备份清理失败');
        }
      }
    }
    try {
      await metadata.save(
        state.copyWith(lastBackupMs: now.millisecondsSinceEpoch),
      );
    } catch (_) {
      return BackupCreationResult(
        path: path,
        completed: false,
        warnings: [...warnings, '备份已生成，但完成时间保存失败'],
      );
    }
    return BackupCreationResult(path: path, warnings: warnings);
  });

  Future<void> markRemoteSeen(WebDavConnection connection, String name) =>
      _exclusive(() async {
        final value = await metadata.load();
        await metadata.save(
          value.copyWith(
            remoteScope: BackupFilePolicy.scope(
              connection.url,
              connection.username,
              connection.remoteDir,
            ),
            seenRemote: name,
          ),
        );
      });

  Future<String> _backupLocal(
    String directory, {
    bool includeCloudCredentials = false,
    String? fileName,
  }) async {
    final ignore = await this.ignore.load();
    final preferences = await _preferences.collectForBackup(ignore.values);
    final password = await passwords.read();
    final sensitive = <String, dynamic>{};
    if (includeCloudCredentials && (password == null || password.isEmpty)) {
      throw StateError('备份云TTS凭据前请先设置本地密码');
    }
    if (password != null && password.isNotEmpty) {
      final connection = await connections.load();
      final servers = await remoteServers.load();
      if (servers.servers.isNotEmpty) {
        sensitive['remoteServers'] = {
          'selectedId': servers.selectedId,
          'servers': servers.servers.map((e) => e.toJson()).toList(),
        };
      }
      if (connection.password.isNotEmpty) {
        sensitive['webDavPassword'] = connection.password;
      }
      if (includeCloudCredentials) {
        final credentials = <String, String>{};
        for (final engine in await cloudTts.list()) {
          if (engine.credentialKey.isEmpty) continue;
          final value = await cloudCredentials.read(engine.credentialKey);
          if (value != null && value.isNotEmpty) {
            credentials[engine.credentialKey] = value;
          }
        }
        if (credentials.isNotEmpty) {
          sensitive['cloudTtsCredentials'] = credentials;
        }
      }
    }
    return repository.backup(
      directory,
      preferences: preferences,
      files: _preferences.collectFiles(preferences),
      sensitive: sensitive,
      password: password,
      fileName: fileName,
    );
  }

  Future<BackupRestoreOutcome> _restoreLocal(String path) async {
    if (!path.toLowerCase().endsWith('.zip')) {
      throw const FormatException('请选择ZIP备份文件');
    }
    final ignore = await this.ignore.load();
    final result = await repository.restore(
      path,
      password: await passwords.read(),
      ignore: {
        for (final key in [
          'localBook',
          'threadCount',
          'coverConfig',
          'readConfig',
        ])
          if (ignore[key]) key,
      },
    );
    try {
      await _preferences.applyFromBackup(result.preferences, ignore.values);
      try {
        await _restoreSensitive(result.sensitive);
      } catch (_) {
        return (
          stats: result.stats,
          preferencesError: StateError('凭据恢复失败，请检查本地安全存储后重试'),
          warnings: result.warnings,
        );
      }
      return (
        stats: result.stats,
        preferencesError: null,
        warnings: result.warnings,
      );
    } catch (error) {
      return (
        stats: result.stats,
        preferencesError: error,
        warnings: result.warnings,
      );
    }
  }

  Future<void> _restoreSensitive(Map<String, dynamic> sensitive) async {
    final password = sensitive['webDavPassword'];
    if (password != null) {
      if (password is! String) throw const FormatException('备份连接密码格式无效');
      final c = await connections.load();
      await connections.save(
        WebDavConnection(
          url: c.url,
          username: c.username,
          password: password,
          remoteDir: c.remoteDir,
          deviceName: c.deviceName,
        ),
      );
    }
    final servers = sensitive['remoteServers'];
    if (servers != null) {
      if (servers is! Map<String, dynamic> ||
          servers['servers'] is! List ||
          servers['selectedId'] is! int) {
        throw const FormatException('远程服务器备份结构无效');
      }
      final restored = (servers['servers'] as List)
          .map(
            (entry) => RemoteServerConfig.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();
      final ids = restored.map((s) => s.id).toSet();
      final selected = servers['selectedId'] as int;
      if (ids.length != restored.length ||
          (selected != defaultRemoteServerId && !ids.contains(selected))) {
        throw const FormatException('远程服务器标识无效');
      }
      for (final server in restored) {
        await remoteServers.save(server);
      }
      await remoteServers.select(selected);
    }
    final credentials = sensitive['cloudTtsCredentials'];
    if (credentials != null) {
      if (credentials is! Map<String, dynamic>) {
        throw const FormatException('云TTS凭据格式无效');
      }
      final allowed = {
        for (final engine in await cloudTts.list()) engine.credentialKey,
      };
      for (final entry in credentials.entries) {
        if (!allowed.contains(entry.key)) {
          throw const FormatException('备份凭据不属于已恢复的云TTS引擎');
        }
        if (entry.value is! String) throw const FormatException('云TTS凭据内容格式无效');
        await cloudCredentials.write(entry.key, entry.value as String);
      }
    }
  }

  Future<void> _uploadBackup(WebDavConnection connection, String path) async {
    final name = File(path).uri.pathSegments.last;
    _validateName(name);
    final parts = connection.remoteDir
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.any((part) => part == '.' || part == '..')) {
      throw const FormatException('WebDAV子目录不能包含相对路径');
    }
    final root = WebDavConnection(
      url: connection.url,
      username: connection.username,
      password: connection.password,
      remoteDir: '',
    );
    var prefix = '';
    for (final part in parts) {
      prefix = '$prefix$part/';
      await webDav.webdavMkdir(root, prefix);
    }
    await webDav.webdavUploadFile(connection, name, path);
  }

  Future<List<String>> listRemoteBackups(
    WebDavConnection connection, {
    int? newerThanMs,
  }) async {
    final entries = await webDav.webdavListDir(connection, '');
    final names = <String, int>{};
    for (final entry in entries) {
      final name = entry['name'];
      if (entry['is_dir'] == true ||
          name is! String ||
          !name.toLowerCase().endsWith('.zip') ||
          name.contains('/') ||
          name.contains('\\') ||
          name.contains(':')) {
        continue;
      }
      var modified = BackupFilePolicy.timestamp(name) ~/ 1000;
      final raw = entry['last_modified'];
      if (raw is String) {
        final iso = DateTime.tryParse(raw);
        if (iso != null) {
          modified = iso.millisecondsSinceEpoch;
        } else {
          try {
            modified = HttpDate.parse(raw).millisecondsSinceEpoch;
          } on HttpException {
            /* 无可用时间时不把旧包误称更新。 */
          }
        }
      }
      if (newerThanMs != null && newerThanMs > 0 && modified <= newerThanMs) {
        continue;
      }
      names[name] = modified;
    }
    return names.keys.toList()..sort((a, b) {
      final order = names[b]!.compareTo(names[a]!);
      return order == 0 ? b.compareTo(a) : order;
    });
  }

  Future<void> _backupToWebDav(
    WebDavConnection connection, {
    String? localPath,
    bool includeCloudCredentials = false,
  }) async {
    if (localPath != null) {
      await _uploadBackup(connection, localPath);
      return;
    }
    final temp = await Directory.systemTemp.createTemp('legado-backup-upload-');
    try {
      final path = await _backupLocal(
        temp.path,
        includeCloudCredentials: includeCloudCredentials,
      );
      await _uploadBackup(connection, path);
    } finally {
      await temp.delete(recursive: true);
    }
  }

  Future<BackupRestoreOutcome> _restoreFromWebDav(
    WebDavConnection connection, {
    String? fileName,
  }) async {
    final selected =
        fileName ?? (await listRemoteBackups(connection)).firstOrNull;
    if (selected == null) throw StateError('云端没有可用备份');
    _validateName(selected);
    final temp = await Directory.systemTemp.createTemp(
      'legado-backup-download-',
    );
    try {
      final path = '${temp.path}${Platform.pathSeparator}backup.zip';
      await webDav.webdavDownloadFile(connection, selected, path);
      final result = await _restoreLocal(path);
      if (result.preferencesError == null) {
        try {
          final value = await metadata.load();
          await metadata.save(
            value.copyWith(
              remoteScope: BackupFilePolicy.scope(
                connection.url,
                connection.username,
                connection.remoteDir,
              ),
              seenRemote: selected,
            ),
          );
        } catch (_) {
          return (
            stats: result.stats,
            preferencesError: null,
            warnings: [...result.warnings, '恢复已完成，但已查看备份记录保存失败'],
          );
        }
      }
      return result;
    } finally {
      await temp.delete(recursive: true);
    }
  }

  void _validateName(String name) {
    if (name.isEmpty ||
        name.contains('/') ||
        name.contains('\\') ||
        name.contains(':') ||
        !name.toLowerCase().endsWith('.zip')) {
      throw const FormatException('无效备份文件名');
    }
  }

  Future<String> importOldData(String directory) =>
      _exclusive(() => _importOldData(directory));
  Future<String> _importOldData(String directory) async {
    final result = await repository.importOldData(directory);
    return result.messages.isNotEmpty
        ? result.messages.join('\n')
        : '书架 ${result.books} · 书源 ${result.bookSources} · 替换规则 ${result.replaceRules}';
  }
}
