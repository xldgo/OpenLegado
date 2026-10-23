import 'package:flutter_legado/src/data/repositories/mock_backup_repository.dart';
import 'package:flutter_legado/src/data/repositories/preferences_remote_server_repository.dart';
import 'package:flutter_legado/src/domain/models/remote_server_config.dart';

import 'dart:async';

import 'package:flutter_legado/src/domain/contracts/backup_metadata_repository.dart';
import 'package:flutter_legado/src/domain/models/backup_metadata.dart';
import 'package:flutter_legado/src/domain/contracts/backup_settings_repository.dart';
import 'package:flutter_legado/src/domain/models/backup_settings.dart';
import 'package:flutter_legado/src/data/services/backup_file_policy.dart';
import 'package:flutter_legado/src/features/settings/application/backup_automation_controller.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/data/services/backup_service.dart';
import 'package:flutter_legado/src/data/services/backup_preferences_service.dart';
import 'package:flutter_legado/src/data/repositories/preferences_webdav_connection_repository.dart';
import 'package:flutter_legado/src/domain/contracts/backup_repository.dart';
import 'package:flutter_legado/src/domain/contracts/restore_ignore_repository.dart';
import 'package:flutter_legado/src/domain/contracts/webdav_service.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/models/backup_restore_result.dart';
import 'package:flutter_legado/src/domain/models/backup_restore_stats.dart';
import 'package:flutter_legado/src/domain/models/restore_ignore_config.dart';
import 'package:flutter_legado/src/domain/models/webdav_connection.dart';
import 'package:flutter_legado/src/domain/models/old_data_import_result.dart';
import 'package:flutter_legado/src/platform/backup/backup_password_store.dart';
import 'package:flutter_legado/src/platform/tts/cloud_tts_credential_store.dart';

const counts = BackupRestoreStats(
  books: 2,
  bookmarks: 1,
  replaceRules: 0,
  bookSources: 1,
  rssSources: 0,
  readRecords: 0,
);

class _Ignore extends Fake implements RestoreIgnoreRepository {
  RestoreIgnoreConfig config = RestoreIgnoreConfig();
  @override
  Future<RestoreIgnoreConfig> load() async => config;
}

class _Clouds extends Fake implements CloudTtsRepository {
  List<CloudTtsEngine> engines = [];
  @override
  Future<List<CloudTtsEngine>> list() async => engines;
}

class _Policies extends Fake implements BackupSettingsRepository {
  BackupSettings value = const BackupSettings();
  @override
  Future<BackupSettings> load() async => value;
}

class _Metadata implements BackupMetadataRepository {
  BackupMetadata value = const BackupMetadata(deviceId: 'fixed-installation');
  bool fail = false;
  @override
  Future<BackupMetadata> load() async => value;
  @override
  Future<void> save(BackupMetadata value) async {
    if (fail) throw StateError('记录失败');
    this.value = value;
  }
}

class _Repository extends Fake implements BackupRepository {
  final calls = <String>[];
  Map<String, dynamic> prefs = {}, sensitive = {};
  Map<String, String> files = {};
  String? password;
  Set<String> ignored = {};
  String? restoredPath;
  bool fail = false;
  Future<void> Function()? beforeRestore;
  Future<void> Function()? beforeBackup;
  BackupRestoreResult result = const BackupRestoreResult(stats: counts);
  OldDataImportResult old = const OldDataImportResult(
    books: 0,
    bookSources: 0,
    replaceRules: 0,
    messages: [],
  );
  @override
  Future<String> backup(
    String dirPath, {
    Map<String, dynamic> preferences = const {},
    Map<String, String> files = const {},
    Map<String, dynamic> sensitive = const {},
    String? password,
    String? fileName,
  }) async {
    calls.add('backup');
    await beforeBackup?.call();
    prefs = preferences;
    this.files = files;
    this.sensitive = sensitive;
    this.password = password;
    final file = File('$dirPath/${fileName ?? 'legado_backup_fixture.zip'}');
    await file.writeAsBytes([80, 75, 1, 2]);
    return file.path;
  }

  @override
  Future<BackupRestoreResult> restore(
    String path, {
    String? password,
    Set<String> ignore = const {},
  }) async {
    calls.add('restore');
    restoredPath = path;
    ignored = ignore;
    this.password = password;
    await beforeRestore?.call();
    if (fail) throw StateError('业务恢复失败');
    return result;
  }

  @override
  Future<OldDataImportResult> importOldData(String path) async => old;
}

class _WebDav extends Fake implements WebDavService {
  final remote = <String, List<int>>{};
  final operations = <String>[];
  bool failUpload = false;
  @override
  Future<void> webdavMkdir(WebDavConnection c, String path) async {
    operations.add('mkdir:$path');
  }

  @override
  Future<void> webdavUploadFile(
    WebDavConnection c,
    String path,
    String file,
  ) async {
    operations.add('upload:$path');
    if (failUpload) throw StateError('网络失败');
    remote[path] = await File(file).readAsBytes();
  }

  @override
  Future<List<Map<String, dynamic>>> webdavListDir(
    WebDavConnection c,
    String path,
  ) async => [
    for (final name in remote.keys) {'name': name, 'is_dir': false},
  ];
  @override
  Future<void> webdavDownloadFile(
    WebDavConnection c,
    String path,
    String file,
  ) async {
    operations.add('download:$path');
    await File(file).writeAsBytes(remote[path]!);
  }

  @override
  Future<void> webdavDelete(WebDavConnection c, String path) async {
    operations.add('delete:$path');
    remote.remove(path);
  }
}

class _FailedPreferences extends BackupPreferencesService {
  bool failCollect = false;
  @override
  Future<Map<String, dynamic>> collectForBackup(
    Map<String, bool> ignore,
  ) async {
    if (failCollect) throw StateError('偏好读取失败');
    return super.collectForBackup(ignore);
  }

  @override
  Future<void> applyFromBackup(
    Map<String, dynamic>? values,
    Map<String, bool> ignore,
  ) async {
    throw StateError('偏好写入失败');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repository;
  late _WebDav dav;
  late _Ignore ignore;
  late Directory directory;
  late MemoryBackupPasswordStore passwords;
  late MemoryCloudTtsCredentialStore credentials;
  late _Clouds clouds;
  late _Policies policy;
  late _Metadata metadata;
  late DateTime now;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'reader_font_size': 18.0,
      'sync_webdav_url': 'https://old.test',
      'sync_webdav_password': 'old-secret',
      'sync_webdav_username': 'fixture-user',
    });
    repository = _Repository();
    policy = _Policies();
    metadata = _Metadata();
    now = DateTime(2026, 10, 24);
    dav = _WebDav();
    ignore = _Ignore();
    passwords = MemoryBackupPasswordStore();
    credentials = MemoryCloudTtsCredentialStore();
    clouds = _Clouds();
    directory = await Directory.systemTemp.createTemp('legado-backup-test-');
    addTearDown(() => directory.delete(recursive: true));
  });
  BackupService service({BackupPreferencesService? preferences}) =>
      BackupService(
        repository: repository,
        settings: policy,
        remoteServers: PreferencesRemoteServerRepository(),
        metadata: metadata,
        clock: () => now,
        webDav: dav,
        ignore: ignore,
        passwords: passwords,
        connections: PreferencesWebDavConnectionRepository(),
        cloudTts: clouds,
        cloudCredentials: credentials,
        preferences: preferences,
      );
  test('本地备份一次收齐普通偏好和字体引用，连接密码只进入加密敏感区', () async {
    final font = File('${directory.path}/font.ttf');
    await font.writeAsBytes([1, 2]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('reader_custom_fonts', ['Custom|${font.path}']);
    await passwords.write('备份密码');
    await PreferencesRemoteServerRepository().save(
      const RemoteServerConfig(
        id: 7,
        name: '私人书库',
        url: 'https://books.test',
        password: 'server-secret',
      ),
    );
    await PreferencesRemoteServerRepository().select(7);
    final path = await service().backupLocal(directory.path);
    expect(await File(path).exists(), isTrue);
    expect(repository.calls, ['backup']);
    expect(repository.prefs['reader_font_size'], 18.0);
    expect(repository.prefs.containsKey('sync_webdav_password'), isFalse);
    expect(repository.files, {font.path: font.path});
    expect(repository.sensitive['webDavPassword'], 'old-secret');
    expect(
      repository.sensitive['remoteServers']['servers'][0]['password'],
      'server-secret',
    );
    expect(repository.prefs.containsKey('remote_servers'), isFalse);
    expect(repository.password, '备份密码');
    await passwords.write(null);
    await service().backupLocal(directory.path);
    expect(repository.sensitive, isEmpty);
    expect(repository.prefs.containsKey('remote_servers'), isFalse);
  });
  test('偏好收集失败时不创建缺设置的半成品，云凭据导出必须有密码且由用户选择', () async {
    final failed = _FailedPreferences()..failCollect = true;
    await expectLater(
      service(preferences: failed).backupLocal(directory.path),
      throwsStateError,
    );
    expect(repository.calls, isEmpty);
    await expectLater(
      service().backupLocal(directory.path, includeCloudCredentials: true),
      throwsStateError,
    );
    expect(repository.calls, isEmpty);
    clouds.engines = [
      const CloudTtsEngine(
        id: 'cloud',
        name: '引擎',
        credentialKey: 'credential-id',
      ),
    ];
    await credentials.write('credential-id', 'key-fixture');
    await passwords.write('密码');
    await service().backupLocal(directory.path);
    expect(repository.sensitive.containsKey('cloudTtsCredentials'), isFalse);
    await service().backupLocal(directory.path, includeCloudCredentials: true);
    expect(repository.sensitive['cloudTtsCredentials'], {
      'credential-id': 'key-fixture',
    });
  });
  test('业务提交后应用偏好与凭据，并保留真实统计和未支持项', () async {
    clouds.engines = [
      const CloudTtsEngine(
        id: 'restored',
        name: '云端',
        credentialKey: 'restored-key',
      ),
    ];
    repository.result = const BackupRestoreResult(
      stats: counts,
      preferences: {
        'reader_font_size': 24.0,
        'sync_webdav_url': 'https://restored.test',
      },
      sensitive: {
        'webDavPassword': 'restored-secret',
        'remoteServers': {
          'selectedId': 9,
          'servers': [
            {
              'id': 9,
              'name': '恢复书库',
              'url': 'https://books.restore',
              'username': 'u',
              'password': 'restored-server',
            },
          ],
        },
        'cloudTtsCredentials': {'restored-key': 'restored-api-key'},
      },
      warnings: ['未恢复上游扩展项'],
    );
    repository.beforeRestore = () async {
      expect(
        (await SharedPreferences.getInstance()).getDouble('reader_font_size'),
        18.0,
      );
    };
    ignore.config = RestoreIgnoreConfig({'localBook': true, 'themeMode': true});
    final result = await service().restoreLocal('${directory.path}/backup.zip');
    expect(result.stats, same(counts));
    expect(result.preferencesError, isNull);
    expect(result.warnings, ['未恢复上游扩展项']);
    expect(repository.ignored, {'localBook'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('reader_font_size'), 24.0);
    expect(prefs.getString('sync_webdav_url'), 'https://restored.test');
    expect(prefs.getString('sync_webdav_password'), 'restored-secret');
    final servers = await PreferencesRemoteServerRepository().load();
    expect(servers.selectedId, 9);
    expect(servers.servers.single.password, 'restored-server');
    expect(await credentials.read('restored-key'), 'restored-api-key');
  });
  test('业务失败不修改偏好或凭据，平台写入失败则保留已提交统计', () async {
    repository.result = const BackupRestoreResult(
      stats: counts,
      preferences: {'reader_font_size': 24.0},
      sensitive: {'webDavPassword': 'changed'},
    );
    repository.fail = true;
    await expectLater(service().restoreLocal('backup.zip'), throwsStateError);
    expect(
      (await SharedPreferences.getInstance()).getDouble('reader_font_size'),
      18.0,
    );
    repository.fail = false;
    final result = await service(preferences: _FailedPreferences())
        .restoreLocal('backup.zip');
    expect(result.stats, same(counts));
    expect(result.preferencesError, isStateError);
    expect(repository.calls, ['restore', 'restore']);
    expect(
      (await SharedPreferences.getInstance()).getString('sync_webdav_password'),
      'old-secret',
    );
  });
  test('WebDAV上传使用已有完整包，恢复只下载选择的文件并清理临时目录', () async {
    const c = WebDavConnection(
      url: 'https://dav.test',
      remoteDir: '/legado/device/',
    );
    final file = File('${directory.path}/backup.zip');
    await file.writeAsBytes([9, 8, 7]);
    await service().backupToWebDav(c, localPath: file.path);
    expect(repository.calls, isEmpty);
    expect(dav.remote['backup.zip'], [9, 8, 7]);
    expect(dav.operations, [
      'mkdir:legado/',
      'mkdir:legado/device/',
      'upload:backup.zip',
    ]);
    dav.operations.clear();
    final result = await service().restoreFromWebDav(c, fileName: 'backup.zip');
    expect(result.stats, same(counts));
    expect(dav.operations, ['download:backup.zip']);
    expect(await File(repository.restoredPath!).exists(), isFalse);
    await expectLater(
      service().restoreFromWebDav(c, fileName: '../backup.zip'),
      throwsFormatException,
    );
  });
  test('旧版导入保留消息或计数表达', () async {
    repository.old = const OldDataImportResult(
      books: 2,
      bookSources: 1,
      replaceRules: 0,
      messages: ['实际结果'],
    );
    expect(await service().importOldData(directory.path), '实际结果');
    repository.old = const OldDataImportResult(
      books: 2,
      bookSources: 1,
      replaceRules: 0,
      messages: [],
    );
    expect(
      await service().importOldData(directory.path),
      '书架 2 · 书源 1 · 替换规则 0',
    );
  });
  test('新包成功才清理同一安装身份旧包，其他设备与上游包保留', () async {
    final workflow = service();
    final connection = await workflow.connections.load();
    final names = BackupFilePolicy('旧设备名', metadata.value.deviceId);
    final old = names.name(DateTime(2026, 1, 1));
    final unrelated = [
      'legadoBackup-2026.zip',
      'openlegado_other_other-id_1.zip',
    ];
    for (final name in [old, ...unrelated]) {
      await File('${directory.path}/$name').writeAsString('old');
      dav.remote[name] = [1];
    }
    final mock = BackupService(
      repository: const MockBackupRepository(),
      webDav: dav,
      ignore: ignore,
      passwords: passwords,
      connections: workflow.connections,
      cloudTts: clouds,
      cloudCredentials: credentials,
      settings: policy,
      metadata: metadata,
      remoteServers: workflow.remoteServers,
    );
    await expectLater(
      mock.createBackup(directory.path),
      throwsUnsupportedError,
    );
    expect(await File('${directory.path}/$old').exists(), isTrue);
    final result = await workflow.createBackup(
      directory.path,
      uploadConnection: connection,
    );
    expect(result.completed, isTrue);
    expect(await File(result.path).exists(), isTrue);
    expect(await File('${directory.path}/$old').exists(), isFalse);
    expect(dav.remote.containsKey(old), isFalse);
    for (final name in unrelated) {
      expect(await File('${directory.path}/$name').exists(), isTrue);
      expect(dav.remote.containsKey(name), isTrue);
    }
    expect(metadata.value.lastBackupMs, now.millisecondsSinceEpoch);
    now = now.add(const Duration(days: 1));
    policy.value = const BackupSettings(onlyLatestBackup: false);
    final next = await workflow.createBackup(
      directory.path,
      uploadConnection: connection,
    );
    expect(await File(result.path).exists(), isTrue);
    expect(await File(next.path).exists(), isTrue);
  });
  test('上传或记录失败保留本地包与旧完成时间，并发操作被同一所有者拒绝', () async {
    final workflow = service();
    final connection = await workflow.connections.load();
    final old = await workflow.createBackup(directory.path);
    final previous = metadata.value.lastBackupMs;
    now = now.add(const Duration(days: 1));
    dav.failUpload = true;
    final failed = await workflow.createBackup(
      directory.path,
      uploadConnection: connection,
    );
    expect(failed.completed, isFalse);
    expect(failed.warnings.single, contains('上传失败'));
    expect(await File(old.path).exists(), isTrue);
    expect(await File(failed.path).exists(), isTrue);
    expect(metadata.value.lastBackupMs, previous);
    dav.failUpload = false;
    metadata.fail = true;
    now = now.add(const Duration(days: 1));
    final unrecorded = await workflow.createBackup(directory.path);
    expect(unrecorded.completed, isFalse);
    expect(metadata.value.lastBackupMs, previous);
    metadata.fail = false;
    now = now.add(const Duration(days: 1));
    final gate = Completer<void>(), entered = Completer<void>();
    repository.beforeBackup = () async {
      entered.complete();
      await gate.future;
    };
    final pending = workflow.createBackup(directory.path);
    await entered.future;
    await expectLater(workflow.restoreLocal('backup.zip'), throwsStateError);
    final controller = BackupAutomationController(workflow);
    await controller.onForeground();
    expect(repository.calls.where((c) => c == 'backup').length, 4);
    controller.dispose();
    gate.complete();
    await pending;
    expect(workflow.isBusy, isFalse);
  });
  test('前台到期自动备份复用真实流程，未到期不重复，新备份提示按连接隔离', () async {
    final workflow = service();
    policy.value = BackupSettings(
      backupPath: directory.path,
      autoBackup: true,
      autoBackupWebDav: true,
    );
    dav.remote['openlegado_other_other-id_2000000000000000.zip'] = [1];
    final controller = BackupAutomationController(workflow);
    addTearDown(controller.dispose);
    await controller.onForeground();
    expect(repository.calls, ['backup']);
    expect(controller.state.newBackup, isNotNull);
    expect(controller.state.error, isNull);
    await controller.dismiss();
    expect(controller.state.newBackup, isNull);
    await controller.onForeground();
    expect(repository.calls, ['backup']);
    expect(controller.state.newBackup, isNull);
    final c = await workflow.connections.load();
    await workflow.connections.save(
      WebDavConnection(
        url: 'https://second.test',
        username: c.username,
        password: c.password,
        remoteDir: c.remoteDir,
      ),
    );
    await controller.onForeground();
    expect(controller.state.newBackup, isNotNull);
    now = now.add(const Duration(days: 1));
    dav.failUpload = true;
    final previous = metadata.value.lastBackupMs;
    await controller.onForeground();
    expect(controller.state.error, contains('上传失败'));
    expect(metadata.value.lastBackupMs, previous);
  });
}
