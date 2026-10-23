import 'package:flutter_legado/src/data/services/backup_service.dart';
import 'package:flutter_legado/src/providers/backup_provider.dart';
import 'package:flutter_legado/src/domain/models/backup_restore_stats.dart';

import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/data/services/rust_webdav_service.dart';

// SyncNotifier 单元测试
//
// 覆盖 Phase 5.4 provider→Riverpod 迁移后的 WebDAV 云同步状态管理：
// 初始状态/配置管理（saveConfig/loadConfig/toggle/setter）/真实同步操作
// （backupToWebDav/restoreFromWebDav）/lastSyncTimeLabel/SyncStatus 枚举。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_legado/src/domain/contracts/webdav_connection_repository.dart';
import 'package:flutter_legado/src/domain/models/webdav_connection.dart';
import 'package:flutter_legado/src/providers/webdav_connection_provider.dart';
import 'package:flutter_legado/src/domain/contracts/sync_metadata_repository.dart';
import 'package:flutter_legado/src/providers/sync_metadata_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/providers/sync/sync_notifier.dart';

import '../mocks/mocks.dart';

class _BackupWorkflow extends Mock implements BackupService {}

class _ConnectionRepository extends Fake implements WebDavConnectionRepository {
  WebDavConnection saved = const WebDavConnection();
  Completer<void>? gate;
  bool fail = false;

  @override
  Future<WebDavConnection> load() async => saved;

  @override
  Future<WebDavConnection> save(WebDavConnection connection) async {
    await gate?.future;
    if (fail) throw StateError('模拟保存失败');
    return saved = connection.normalized;
  }
}

class _MetadataRepository implements SyncMetadataRepository {
  DateTime? saved = DateTime.fromMillisecondsSinceEpoch(1234);
  bool failSave = true;
  bool failLoad = false;
  int saveCalls = 0;

  @override
  Future<DateTime?> load() async {
    if (failLoad) throw StateError('模拟时间读取失败');
    return saved;
  }

  @override
  Future<void> save(DateTime time) async {
    saveCalls++;
    if (failSave) throw StateError('模拟时间写入失败');
    saved = time;
  }
}

void main() {
  late MockRustApi mockApi;
  late ProviderContainer container;
  late _BackupWorkflow workflow;

  setUpAll(() {
    registerFallbacks();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApi = MockRustApi();
    workflow = _BackupWorkflow();
    when(
      () => workflow.backupToWebDav(
        any(),
        localPath: any(named: 'localPath'),
        includeCloudCredentials: any(named: 'includeCloudCredentials'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => workflow.restoreFromWebDav(any(), fileName: any(named: 'fileName')),
    ).thenAnswer(
      (_) async => (
        stats: const BackupRestoreStats(
          books: 1,
          bookmarks: 0,
          replaceRules: 0,
          bookSources: 1,
          rssSources: 0,
          readRecords: 0,
        ),
        preferencesError: null,
        warnings: <String>[],
      ),
    );
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...mockApi.overrides,
        backupServiceProvider.overrideWithValue(workflow),
      ]),
    );
    addTearDown(container.dispose);
  });

  SyncState readState() => container.read(syncNotifierProvider);
  SyncNotifier readNotifier() => container.read(syncNotifierProvider.notifier);

  group('SyncNotifier 初始状态', () {
    test('初始状态为 idle', () {
      expect(readState().status, equals(SyncStatus.idle));
    });

    test('初始无最后同步时间', () {
      expect(readState().lastSyncTime, isNull);
    });

    test('初始无错误', () {
      expect(readState().error, isNull);
    });

    test('初始自动同步关闭', () {
      expect(readState().autoSync, isFalse);
    });

    test('初始 WebDAV 配置为空', () {
      final state = readState();
      expect(state.webDavUrl, equals(''));
      expect(state.webDavUsername, equals(''));
      expect(state.webDavPassword, equals(''));
      expect(state.remoteDir, equals('/legado/'));
      expect(state.deviceName, equals(''));
    });

    test('初始同步书籍进度默认开启、增强默认关闭', () {
      expect(readState().syncBookProgress, isTrue);
      expect(readState().syncBookProgressPlus, isFalse);
    });

    test('初始 isConfigured 为 false', () {
      expect(readState().isConfigured, isFalse);
    });

    test('初始 lastSyncTimeLabel 为"从未同步"', () {
      expect(readState().lastSyncTimeLabel, equals('从未同步'));
    });
  });

  group('SyncNotifier 配置管理', () {
    test('仓储成功前不更新投影，失败原值保持且可重试', () async {
      final repository = _ConnectionRepository()
        ..saved = const WebDavConnection(url: 'https://old.example');
      container = ProviderContainer(
        overrides: mergeTestOverrides([
          ...mockApi.overrides,
          webDavConnectionRepositoryProvider.overrideWithValue(repository),
        ]),
      );
      addTearDown(container.dispose);
      await readNotifier().loadConfig();
      final gate = Completer<void>();
      repository.gate = gate;
      final saving = readNotifier().saveConfig(
        ' https://new.example ',
        ' 账号 ',
        ' 密码 ',
        ' /new ',
      );
      expect(readState().webDavUrl, 'https://old.example');
      gate.complete();
      await saving;
      expect(readState().webDavUrl, 'https://new.example');
      expect(readState().webDavPassword, ' 密码 ');
      expect(readNotifier().normalizedRemoteDir, '/new/');
      repository.fail = true;
      await expectLater(
        readNotifier().saveConfig('https://failed.example', '', '', ''),
        throwsStateError,
      );
      expect(readState().webDavUrl, 'https://new.example');
      expect(readState().status, SyncStatus.idle);
      repository.fail = false;
      await readNotifier().saveConfig('https://retry.example', '', '', '');
      expect(readState().webDavUrl, 'https://retry.example');
    });

    test('saveConfig 保存 WebDAV 配置（含设备名）', () async {
      await readNotifier().saveConfig(
        'https://dav.example.com',
        'user@test.com',
        'pass123',
        '/backup/',
        deviceName: 'my-phone',
      );

      final state = readState();
      expect(state.webDavUrl, equals('https://dav.example.com'));
      expect(state.webDavUsername, equals('user@test.com'));
      expect(state.webDavPassword, equals('pass123'));
      expect(state.remoteDir, equals('/backup/'));
      expect(state.deviceName, equals('my-phone'));
      expect(state.isConfigured, isTrue);
    });

    test('saveConfig 空目录时使用默认 /legado/', () async {
      await readNotifier().saveConfig('https://dav.com', 'user', 'pass', '  ');
      expect(readState().remoteDir, equals('/legado/'));
    });

    test('saveConfig trim 处理', () async {
      await readNotifier().saveConfig(
        '  https://dav.com  ',
        '  user  ',
        'pass',
        '  /dir/  ',
        deviceName: '  dev  ',
      );
      final state = readState();
      expect(state.webDavUrl, equals('https://dav.com'));
      expect(state.webDavUsername, equals('user'));
      expect(state.remoteDir, equals('/dir/'));
      expect(state.deviceName, equals('dev'));
    });

    test('saveConfig 触发状态变更通知', () async {
      var notified = false;
      container.listen(syncNotifierProvider, (_, _) => notified = true);
      await readNotifier().saveConfig('url', 'user', 'pass', '/dir/');
      expect(notified, isTrue);
    });

    test('数据适配编码输出 Rust WebDavConfig 结构（含 remote_dir 必需字段，Task #52）', () async {
      await readNotifier().saveConfig(
        'https://dav.com',
        'user',
        'pass',
        '/dir/',
      );
      expect(
        encodeWebDavConfig(readNotifier().connection),
        equals(
          '{"url":"https://dav.com","username":"user","password":"pass","remote_dir":"/dir/"}',
        ),
      );
    });

    test('loadConfig 从 SharedPreferences 加载（含新字段）', () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'sync_webdav_url': 'https://loaded.com',
        'sync_webdav_username': 'loaded_user',
        'sync_webdav_password': 'loaded_pass',
        'sync_webdav_remote_dir': '/loaded/',
        'sync_webdav_device_name': 'loaded_dev',
        'sync_book_progress': false,
        'sync_book_progress_plus': true,
        'sync_auto': true,
        'sync_last_time': now.millisecondsSinceEpoch,
      });
      await readNotifier().loadConfig();

      final state = readState();
      expect(state.webDavUrl, equals('https://loaded.com'));
      expect(state.webDavUsername, equals('loaded_user'));
      expect(state.webDavPassword, equals('loaded_pass'));
      expect(state.remoteDir, equals('/loaded/'));
      expect(state.deviceName, equals('loaded_dev'));
      expect(state.syncBookProgress, isFalse);
      expect(state.syncBookProgressPlus, isTrue);
      expect(state.autoSync, isTrue);
      expect(state.lastSyncTime, isNotNull);
    });

    test('loadConfig 触发状态变更通知', () async {
      var notified = false;
      container.listen(syncNotifierProvider, (_, _) => notified = true);
      await (await SharedPreferences.getInstance()).setString(
        'sync_webdav_url',
        'https://changed.com',
      );
      await readNotifier().loadConfig();
      expect(notified, isTrue);
      expect(readState().webDavUrl, 'https://changed.com');
    });

    test('loadConfig 相同配置不重复通知', () async {
      await readNotifier().loadConfig();
      var notified = false;
      container.listen(syncNotifierProvider, (_, _) => notified = true);
      await readNotifier().loadConfig();
      expect(notified, isFalse);
    });

    test('setSyncBookProgress 持久化开关', () async {
      await readNotifier().setSyncBookProgress(false);
      expect(readState().syncBookProgress, isFalse);
    });
  });

  group('SyncNotifier完整包操作', () {
    test('恢复消费整包结果而不上传，成功后记录时间', () async {
      await readNotifier().saveConfig(
        'https://dav.test',
        'user',
        'password',
        'legado',
      );
      final message = await readNotifier().restoreFromWebDav(
        fileName: 'selected.zip',
      );
      expect(message, contains('2条业务记录'));
      expect(readState().status, SyncStatus.success);
      expect(readState().lastSyncTime, isNotNull);
      verify(() => workflow.restoreFromWebDav(any(), fileName: 'selected.zip'))
          .called(1);
      verifyNever(
        () => workflow.backupToWebDav(
          any(),
          localPath: any(named: 'localPath'),
          includeCloudCredentials: any(named: 'includeCloudCredentials'),
        ),
      );
    });
    test('业务已提交但设置失败保留部分结果，不更新时间或重复恢复', () async {
      await readNotifier().saveConfig(
        'https://dav.test',
        'user',
        'password',
        'legado',
      );
      when(
        () =>
            workflow.restoreFromWebDav(any(), fileName: any(named: 'fileName')),
      ).thenAnswer(
        (_) async => (
          stats: const BackupRestoreStats(
            books: 1,
            bookmarks: 0,
            replaceRules: 0,
            bookSources: 0,
            rssSources: 0,
            readRecords: 0,
          ),
          preferencesError: StateError('设置失败'),
          warnings: <String>[],
        ),
      );
      final message = await readNotifier().restoreFromWebDav();
      expect(message, contains('已恢复1条业务记录'));
      expect(message, contains('设置失败'));
      expect(readState().status, SyncStatus.error);
      expect(readState().lastSyncTime, isNull);
      verify(() => workflow.restoreFromWebDav(any(), fileName: null)).called(1);
    });
    test('云端完成但时间记录失败保留成功和旧时间，不重传文件', () async {
      final metadata = _MetadataRepository();
      final scoped = ProviderContainer(
        overrides: mergeTestOverrides([
          ...mockApi.overrides,
          backupServiceProvider.overrideWithValue(workflow),
          syncMetadataRepositoryProvider.overrideWithValue(metadata),
        ]),
      );
      addTearDown(scoped.dispose);
      final notifier = scoped.read(syncNotifierProvider.notifier);
      await notifier.saveConfig(
        'https://dav.test',
        'user',
        'password',
        'legado',
      );
      await notifier.loadConfig();
      await notifier.backupToWebDav(localPath: 'existing.zip');
      final state = scoped.read(syncNotifierProvider);
      expect(state.status, SyncStatus.success);
      expect(state.lastSyncTime, metadata.saved);
      expect(state.error, contains('时间未保存'));
      expect(metadata.saveCalls, 1);
      verify(
        () => workflow.backupToWebDav(
          any(),
          localPath: 'existing.zip',
          includeCloudCredentials: false,
        ),
      ).called(1);
    });
    test('不支持的上游项目作为明确提示保留', () async {
      await readNotifier().saveConfig(
        'https://dav.test',
        'user',
        'password',
        'legado',
      );
      when(
        () =>
            workflow.restoreFromWebDav(any(), fileName: any(named: 'fileName')),
      ).thenAnswer(
        (_) async => (
          stats: const BackupRestoreStats(
            books: 1,
            bookmarks: 0,
            replaceRules: 0,
            bookSources: 0,
            rssSources: 0,
            readRecords: 0,
          ),
          preferencesError: null,
          warnings: ['未恢复Android主题配置'],
        ),
      );
      expect(
        await readNotifier().restoreFromWebDav(),
        contains('未恢复Android主题配置'),
      );
      expect(readState().error, contains('未恢复Android主题配置'));
    });
    test('上传或下载失败不记录成功时间', () async {
      await readNotifier().saveConfig(
        'https://dav.test',
        'user',
        'password',
        'legado',
      );
      when(
        () => workflow.backupToWebDav(
          any(),
          localPath: any(named: 'localPath'),
          includeCloudCredentials: any(named: 'includeCloudCredentials'),
        ),
      ).thenThrow(StateError('上传失败'));
      when(
        () =>
            workflow.restoreFromWebDav(any(), fileName: any(named: 'fileName')),
      ).thenThrow(StateError('下载失败'));
      await readNotifier().backupToWebDav();
      expect(readState().status, SyncStatus.error);
      expect(readState().lastSyncTime, isNull);
      expect(await readNotifier().restoreFromWebDav(), contains('下载失败'));
      expect(readState().lastSyncTime, isNull);
    });
    test('未配置时不触发备份恢复', () async {
      await readNotifier().backupToWebDav();
      expect(readState().status, SyncStatus.error);
      expect(await readNotifier().restoreFromWebDav(), contains('请先配置'));
      verifyNever(
        () =>
            workflow.restoreFromWebDav(any(), fileName: any(named: 'fileName')),
      );
    });
  });

  group('SyncNotifier lastSyncTimeLabel', () {
    test('刚刚同步显示刚刚', () async {
      await readNotifier().saveConfig(
        'https://dav.test',
        'user',
        'password',
        'legado',
      );
      await readNotifier().backupToWebDav();
      expect(readState().lastSyncTimeLabel, '刚刚');
    });
  });

  group('SyncStatus 枚举', () {
    test('包含所有预期状态', () {
      expect(
        SyncStatus.values,
        containsAll([
          SyncStatus.idle,
          SyncStatus.syncing,
          SyncStatus.success,
          SyncStatus.error,
        ]),
      );
    });
  });
}
