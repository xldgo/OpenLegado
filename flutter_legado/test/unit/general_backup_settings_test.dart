import '../fixtures/app_test_api.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_general_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_backup_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_appearance_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_bookshelf_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/general_settings.dart';
import 'package:flutter_legado/src/domain/models/backup_settings.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/backup_settings_provider.dart';
import 'package:flutter_legado/src/providers/sync/sync_notifier.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late AppGeneralSettingsRepository general;
  late AppBackupSettingsRepository backup;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = HomeSettingsStorage();
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    general = AppGeneralSettingsRepository(service);
    backup = AppBackupSettingsRepository(service);
  });
  tearDown(() => service.dispose());

  test('普通偏好按原键读取，不补写默认值或扫描凭据', () async {
    storage.values['sync_webdav_password'] = '保留的凭据';
    expect(await general.load(), const GeneralSettings());
    expect(storage.reads.toSet(), {
      'defaultBookTreeUri',
      'showAddToShelfAlert',
      'showMangaUi',
      'webPort',
      'defaultToRead',
      'sourceEditMaxLine',
    });
    expect(await backup.load(), const BackupSettings());
    expect(storage.reads, isNot(contains('sync_webdav_password')));
    await general.update();
    await backup.update();
    expect(storage.writes, isEmpty);
  });

  test('七个字段保留原键类型，单字段修改不覆盖其他值', () async {
    storage.values.addAll({
      'showAddToShelfAlert': false,
      'webPort': 4321,
      'app_backup_path': 'E:/备份目录',
      'sync_book_progress': false,
    });
    await general.update(defaultBookTreeUri: 'E:/书签');
    expect((await general.load()).webPort, 4321);
    expect(general.current.showAddToShelfAlert, isFalse);
    await backup.load();
    await backup.update(backupPath: 'E:/新备份');
    expect(backup.current.syncBookProgress, isFalse);
    await AppAppearanceSettingsRepository(service)
        .update((current) => current.copyWith(launcherIcon: 'icon4'));
    await AppBookshelfSettingsRepository(service)
        .update(deleteBookAlert: false);
    expect(storage.values, {
      'defaultBookTreeUri': 'E:/书签',
      'showAddToShelfAlert': false,
      'webPort': 4321,
      'app_backup_path': 'E:/新备份',
      'sync_book_progress': false,
      'launcherIcon': 'icon4',
      'delete_book_alert': false,
    });
  });

  test('清空目录删除真实 Preferences 原键，保留连接密码', () async {
    SharedPreferences.setMockInitialValues({
      'defaultBookTreeUri': 'E:/原导出',
      'app_backup_path': 'E:/原备份',
      'sync_webdav_password': '原密码',
    });
    final actual = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(actual.dispose);
    await AppGeneralSettingsRepository(actual).update(defaultBookTreeUri: '');
    await AppBackupSettingsRepository(actual).update(backupPath: '');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('defaultBookTreeUri'), isFalse);
    expect(prefs.containsKey('app_backup_path'), isFalse);
    expect(prefs.getString('sync_webdav_password'), '原密码');
  });

  test('错误类型只兜底展示，越界端口保持原值交给启动入口校验', () async {
    storage.values.addAll({
      'webPort': 80,
      'defaultBookTreeUri': 12,
      'showAddToShelfAlert': 'false',
      'sync_book_progress': 0,
    });
    expect(await general.load(), const GeneralSettings(webPort: 80));
    expect(await backup.load(), const BackupSettings());
    expect(storage.writes, isEmpty);
  });

  test('保存失败回退，重试与恢复重读更新同一快照', () async {
    storage.values.addAll({
      'webPort': 4321,
      'sync_book_progress': false,
      'sourceEditMaxLine': 20,
    });
    await general.load();
    await backup.load();
    storage.writeFailure = true;
    await expectLater(general.update(webPort: 5000), throwsStateError);
    await expectLater(general.update(sourceEditMaxLines: 30), throwsStateError);
    await expectLater(general.update(showMangaUi: false), throwsStateError);
    await expectLater(backup.update(syncBookProgress: true), throwsStateError);
    expect(general.current.webPort, 4321);
    expect(general.current.sourceEditMaxLines, 20);
    expect(general.current.showMangaUi, isTrue);
    expect(backup.current.syncBookProgress, isFalse);
    storage.writeFailure = false;
    await general.update(webPort: 5000);
    await general.update(sourceEditMaxLines: 0);
    await general.update(showMangaUi: false);
    expect(storage.values['showMangaUi'], isFalse);
    expect(storage.values['sourceEditMaxLine'], 0);
    storage.values['webPort'] = 6000;
    storage.values['sourceEditMaxLine'] = 40;
    storage.values['showMangaUi'] = true;
    storage.values['sync_book_progress'] = true;
    await general.reload();
    await backup.reload();
    expect(general.current.webPort, 6000);
    expect(general.current.sourceEditMaxLines, 40);
    expect(general.current.showMangaUi, isTrue);
    expect(backup.current.syncBookProgress, isTrue);
  });

  test('编辑行数仅接受不限或至少10行，非法写入不覆盖保存值', () async {
    storage.values['sourceEditMaxLine'] = 9;
    await general.load();
    expect(general.current.sourceEditMaxLines, 0);
    expect(storage.writes, isEmpty);
    await general.update(sourceEditMaxLines: 10);
    expect(storage.values['sourceEditMaxLine'], 10);
    for (final invalid in [-1, 1, 9]) {
      expect(
        () => general.update(sourceEditMaxLines: invalid),
        throwsArgumentError,
      );
    }
    expect(general.current.sourceEditMaxLines, 10);
    await general.update(sourceEditMaxLines: 0);
    expect(general.current.sourceEditMaxLines, 0);
  });

  test('多键保存保持已成功路径，仅失败的开关回退', () async {
    await backup.load();
    storage.beforeWrite = (key, _) async {
      if (key == 'sync_book_progress') throw StateError('开关保存失败');
    };
    await expectLater(
      backup.update(backupPath: 'E:/已保存', syncBookProgress: false),
      throwsStateError,
    );
    expect(backup.current.backupPath, 'E:/已保存');
    expect(backup.current.syncBookProgress, isTrue);
  });

  test('同步消费者与备份仓储同源，失败回退且外部恢复后刷新', () async {
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        appSettingsServiceProvider.overrideWithValue(service),
      ]),
    );
    addTearDown(container.dispose);
    final notifier = container.read(syncNotifierProvider.notifier);
    await notifier.loadConfig();
    storage.writeFailure = true;
    await expectLater(notifier.setSyncBookProgress(false), throwsStateError);
    expect(container.read(syncNotifierProvider).syncBookProgress, isTrue);
    storage.writeFailure = false;
    await notifier.setSyncBookProgress(false);
    expect(
      container.read(backupSettingsRepositoryProvider).current.syncBookProgress,
      isFalse,
    );
    storage.values['sync_book_progress'] = true;
    await container.read(backupSettingsRepositoryProvider).reload();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(syncNotifierProvider).syncBookProgress, isTrue);
  });

  test('同步策略从共享仓储加载并在恢复重读后订阅更新', () async {
    storage.values.addAll({'sync_auto': true, 'sync_book_progress_plus': true});
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        appSettingsServiceProvider.overrideWithValue(service),
      ]),
    );
    addTearDown(container.dispose);
    await container.read(syncNotifierProvider.notifier).loadConfig();
    expect(container.read(syncNotifierProvider).autoSync, isTrue);
    expect(container.read(syncNotifierProvider).syncBookProgressPlus, isTrue);
    storage.values['sync_auto'] = false;
    storage.values['sync_book_progress_plus'] = false;
    await container.read(backupSettingsRepositoryProvider).reload();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(syncNotifierProvider).autoSync, isFalse);
    expect(container.read(syncNotifierProvider).syncBookProgressPlus, isFalse);
    expect(storage.writes, isEmpty);
  });

  test('两项策略按真实Preferences读取并随reload订阅，不增加写入口', () async {
    SharedPreferences.setMockInitialValues({
      'sync_auto': true,
      'sync_book_progress_plus': true,
    });
    final actual = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(actual.dispose);
    final repository = AppBackupSettingsRepository(actual);
    final values = <BackupSettings>[];
    final subscription = repository.watch().listen(values.add);
    addTearDown(subscription.cancel);
    expect(
      await repository.load(),
      const BackupSettings(autoSync: true, syncBookProgressPlus: true),
    );
    await repository.update(backupPath: 'E:/新路径');
    expect(repository.current.autoSync, isTrue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_auto', false);
    await prefs.setBool('sync_book_progress_plus', false);
    await repository.reload();
    await Future<void>.delayed(Duration.zero);
    expect(values.last.autoSync, isFalse);
    expect(values.last.syncBookProgressPlus, isFalse);
    expect(repository.current.backupPath, 'E:/新路径');
  });
}
