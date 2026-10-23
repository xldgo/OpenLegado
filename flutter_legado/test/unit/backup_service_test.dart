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

class _Repository extends Fake implements BackupRepository {
  final calls = <String>[];
  Map<String, dynamic> prefs = {}, sensitive = {};
  Map<String, String> files = {};
  String? password;
  Set<String> ignored = {};
  String? restoredPath;
  bool fail = false;
  Future<void> Function()? beforeRestore;
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
  }) async {
    calls.add('backup');
    prefs = preferences;
    this.files = files;
    this.sensitive = sensitive;
    this.password = password;
    final file = File('$dirPath/legado_backup_fixture.zip');
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'reader_font_size': 18.0,
      'sync_webdav_url': 'https://old.test',
      'sync_webdav_password': 'old-secret',
    });
    repository = _Repository();
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
    final path = await service().backupLocal(directory.path);
    expect(await File(path).exists(), isTrue);
    expect(repository.calls, ['backup']);
    expect(repository.prefs['reader_font_size'], 18.0);
    expect(repository.prefs.containsKey('sync_webdav_password'), isFalse);
    expect(repository.files, {font.path: font.path});
    expect(repository.sensitive, {'webDavPassword': 'old-secret'});
    expect(repository.password, '备份密码');
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
    repository.result = const BackupRestoreResult(
      stats: counts,
      preferences: {
        'reader_font_size': 24.0,
        'sync_webdav_url': 'https://restored.test',
      },
      sensitive: {'webDavPassword': 'restored-secret'},
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
}
