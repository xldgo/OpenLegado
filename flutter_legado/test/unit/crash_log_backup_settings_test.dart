import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 目录桩仅替换现有插件的传递平台接口，不增加运行时依赖。
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:flutter_legado/src/data/repositories/app_backup_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/services/crash_log_service.dart';

import '../fixtures/home_settings_storage.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('日志目录来自备份共享仓储，恢复后列表和读取使用新目录', () async {
    SharedPreferences.setMockInitialValues({});
    final root = await Directory.systemTemp.createTemp(
      'legado-backup-settings-',
    );
    addTearDown(() => root.delete(recursive: true));
    final paths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    addTearDown(() => PathProviderPlatform.instance = paths);
    final storage = HomeSettingsStorage();
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    addTearDown(service.dispose);
    final repository = AppBackupSettingsRepository(service);
    await CrashLogService.instance.init(backupSettings: repository);
    final before = Directory('${root.path}/before/crash')
      ..createSync(recursive: true);
    final restored = Directory('${root.path}/restored/crash')
      ..createSync(recursive: true);
    File('${before.path}/before.log').writeAsStringSync('原目录内容');
    File('${restored.path}/restored.log').writeAsStringSync('恢复后内容');
    await repository.update(backupPath: before.parent.path);
    expect(
      (await CrashLogService.instance.listCrashLogs()).single.fileName,
      'before.log',
    );
    CrashLogService.instance.logError(StateError('原目录备份'), StackTrace.current);
    await CrashLogService.instance.flush();
    expect(
      before.listSync().whereType<File>().any(
        (file) =>
            file.uri.pathSegments.last.startsWith('crash-') &&
            file.readAsStringSync().contains('原目录备份'),
      ),
      isTrue,
    );
    storage.values['app_backup_path'] = restored.parent.path;
    await repository.reload();
    expect(
      (await CrashLogService.instance.listCrashLogs()).single.fileName,
      'restored.log',
    );
    expect(
      await CrashLogService.instance.readCrashLog('restored.log'),
      '恢复后内容',
    );
    CrashLogService.instance.logError(StateError('恢复后备份'), StackTrace.current);
    await CrashLogService.instance.flush();
    expect(
      restored.listSync().whereType<File>().any(
        (file) =>
            file.uri.pathSegments.last.startsWith('crash-') &&
            file.readAsStringSync().contains('恢复后备份'),
      ),
      isTrue,
    );
    await repository.update(backupPath: '');
    expect(await CrashLogService.instance.listCrashLogs(), isEmpty);
    expect(await CrashLogService.instance.readCrashLog('restored.log'), isNull);
  });
}
