import 'dart:io';

import '../../domain/contracts/backup_repository.dart';
import '../../domain/contracts/backup_password_store.dart';
import '../../domain/contracts/restore_ignore_repository.dart';
import '../../domain/contracts/webdav_service.dart';
import '../../domain/contracts/webdav_connection_repository.dart';
import '../../domain/contracts/cloud_tts_repository.dart';
import '../../domain/contracts/cloud_tts_credential_store.dart';
import '../../domain/models/webdav_connection.dart';
import '../../domain/models/backup_restore_stats.dart';
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

  Future<String> backupLocal(
    String directory, {
    bool includeCloudCredentials = false,
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
    );
  }

  Future<
    ({
      BackupRestoreStats stats,
      Object? preferencesError,
      List<String> warnings,
    })
  >
  restoreLocal(String path) async {
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
      await _restoreSensitive(result.sensitive);
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

  Future<void> uploadBackup(WebDavConnection connection, String path) async {
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

  Future<List<String>> listRemoteBackups(WebDavConnection connection) async {
    final entries = await webDav.webdavListDir(connection, '');
    final names = <String>[];
    for (final entry in entries) {
      final name = entry['name'];
      if (entry['is_dir'] == true ||
          name is! String ||
          !name.toLowerCase().endsWith('.zip') ||
          name.contains('/') ||
          name.contains('\\')) {
        continue;
      }
      names.add(name);
    }
    names.sort((a, b) => b.compareTo(a));
    return names;
  }

  Future<void> backupToWebDav(
    WebDavConnection connection, {
    String? localPath,
    bool includeCloudCredentials = false,
  }) async {
    if (localPath != null) {
      await uploadBackup(connection, localPath);
      return;
    }
    final temp = await Directory.systemTemp.createTemp('legado-backup-upload-');
    try {
      final path = await backupLocal(
        temp.path,
        includeCloudCredentials: includeCloudCredentials,
      );
      await uploadBackup(connection, path);
    } finally {
      await temp.delete(recursive: true);
    }
  }

  Future<
    ({
      BackupRestoreStats stats,
      Object? preferencesError,
      List<String> warnings,
    })
  >
  restoreFromWebDav(WebDavConnection connection, {String? fileName}) async {
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
      return await restoreLocal(path);
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

  Future<String> importOldData(String directory) async {
    final result = await repository.importOldData(directory);
    return result.messages.isNotEmpty
        ? result.messages.join('\n')
        : '书架 ${result.books} · 书源 ${result.bookSources} · 替换规则 ${result.replaceRules}';
  }
}
