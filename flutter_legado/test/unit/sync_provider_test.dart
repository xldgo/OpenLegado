import 'package:flutter_legado/src/domain/models/webdav_sync_result.dart';

import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/data/services/rust_webdav_service.dart';

// SyncNotifier 单元测试
//
// 覆盖 Phase 5.4 provider→Riverpod 迁移后的 WebDAV 云同步状态管理：
// 初始状态/配置管理（saveConfig/loadConfig/toggle/setter）/真实同步操作
// （backupToWebDav/restoreFromWebDav）/lastSyncTimeLabel/SyncStatus 枚举。
import 'dart:async';
import 'dart:convert';

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
import 'package:flutter_legado/src/models/models.dart';

import '../mocks/mocks.dart';

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

  setUpAll(() {
    registerFallbacks();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApi = MockRustApi();
    container = ProviderContainer(
      overrides: mergeTestOverrides([...mockApi.overrides]),
    );
    addTearDown(container.dispose);
  });

  SyncState readState() => container.read(syncNotifierProvider);
  SyncNotifier readNotifier() => container.read(syncNotifierProvider.notifier);

  /// 桩入真实同步所需的 TestApi 调用
  void stubSyncApis({String remoteBooks = '[]', String remoteSources = '[]'}) {
    when(() => mockApi.bookshelfRepository.getBooks())
        .thenAnswer((_) async => [const Book(bookUrl: 'b1', name: '书1')]);
    when(() => mockApi.bookSourceRepository.getBookSources()).thenAnswer(
      (_) async => [
        const BookSource(bookSourceUrl: 'https://a.com', bookSourceName: '源A'),
      ],
    );
    when(() => mockApi.webDavService.webdavFullSync(any(), any(), any()))
        .thenAnswer(
          (_) async => WebDavSyncResult(books: '[]', sources: remoteSources),
        );
    when(() => mockApi.webDavService.webdavDownload(any(), 'bookshelf.json'))
        .thenAnswer((_) async => remoteBooks);
    when(() => mockApi.webDavService.webdavDownload(any(), 'sources.json'))
        .thenAnswer((_) async => remoteSources);
    when(() => mockApi.bookshelfRepository.importBooks(any()))
        .thenAnswer((_) async => 1);
    when(() => mockApi.bookSourceRepository.importBookSources(any()))
        .thenAnswer((_) async => 1);
  }

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

  group('SyncNotifier 真实同步操作', () {
    test('云端恢复只下载远端书架和书源，不读取或上传本地快照', () async {
      const remoteBooks = '[{"bookUrl":"remote-book","name":"云端书籍"}]';
      const remoteSources = '[{"bookSourceUrl":"https://remote.example"}]';
      when(() => mockApi.bookshelfRepository.getBooks())
          .thenAnswer((_) async => const []);
      when(() => mockApi.bookSourceRepository.getBookSources())
          .thenAnswer((_) async => const []);
      when(() => mockApi.webDavService.webdavFullSync(any(), any(), any()))
          .thenAnswer(
            (_) async => const WebDavSyncResult(books: '[]', sources: '[]'),
          );
      when(() => mockApi.webDavService.webdavDownload(any(), 'bookshelf.json'))
          .thenAnswer((_) async => remoteBooks);
      when(() => mockApi.webDavService.webdavDownload(any(), 'sources.json'))
          .thenAnswer((_) async => remoteSources);
      when(() => mockApi.bookshelfRepository.importBooks(remoteBooks))
          .thenAnswer((_) async => 1);
      when(() => mockApi.bookSourceRepository.importBookSources(remoteSources))
          .thenAnswer((_) async => 1);
      await readNotifier().saveConfig('https://dav.example', 'u', 'p', '/dir');

      final message = await readNotifier().restoreFromWebDav();

      verifyNever(
        () => mockApi.webDavService.webdavFullSync(any(), any(), any()),
      );
      expect(readState().status, SyncStatus.success);
      expect(message, '恢复完成，回写 1 本书籍、1 条书源');
      final configs = verify(
        () => mockApi.webDavService.webdavDownload(captureAny(), any()),
      ).captured.cast<WebDavConnection>();
      expect(configs, hasLength(2));
      expect(
        configs.map((connection) => jsonDecode(encodeWebDavConfig(connection))),
        everyElement({
          'url': 'https://dav.example',
          'username': 'u',
          'password': 'p',
          'remote_dir': '/dir/',
        }),
      );
      verify(() => mockApi.bookshelfRepository.importBooks(remoteBooks))
          .called(1);
      verify(
        () => mockApi.bookSourceRepository.importBookSources(remoteSources),
      ).called(1);
      verifyNever(
        () => mockApi.webDavService.webdavUpload(any(), any(), any()),
      );
      verifyNever(
        () => mockApi.webDavService.webdavUploadFile(any(), any(), any()),
      );
      verifyNever(() => mockApi.webDavService.webdavDelete(any(), any()));
      verifyNever(() => mockApi.bookshelfRepository.getBooks());
      verifyNever(() => mockApi.bookSourceRepository.getBookSources());
    });

    test('两份载荷下载完成前不开始任何导入', () async {
      const books = '[{"bookUrl":"remote-book"}]';
      const sources = '[{"bookSourceUrl":"remote-source"}]';
      stubSyncApis(remoteBooks: books, remoteSources: sources);
      final download = Completer<String>();
      when(() => mockApi.webDavService.webdavDownload(any(), 'sources.json'))
          .thenAnswer((_) => download.future);
      await readNotifier().saveConfig('https://dav.example', 'u', 'p', '/dir/');

      final restoring = readNotifier().restoreFromWebDav();
      await Future<void>.delayed(Duration.zero);

      expect(readState().status, SyncStatus.syncing);
      verifyNever(() => mockApi.bookshelfRepository.importBooks(any()));
      verifyNever(() => mockApi.bookSourceRepository.importBookSources(any()));
      download.complete(sources);
      await restoring;
      expect(readState().status, SyncStatus.success);
      verifyInOrder([
        () => mockApi.webDavService.webdavDownload(any(), 'bookshelf.json'),
        () => mockApi.webDavService.webdavDownload(any(), 'sources.json'),
        () => mockApi.bookshelfRepository.importBooks(books),
        () => mockApi.bookSourceRepository.importBookSources(sources),
      ]);
    });

    for (final file in ['bookshelf.json', 'sources.json']) {
      test('$file下载失败不回写本地，也不更新上次同步时间', () async {
        SharedPreferences.setMockInitialValues({'sync_last_time': 1234});
        stubSyncApis(
          remoteBooks: '[{"bookUrl":"remote-book"}]',
          remoteSources: '[{"bookSourceUrl":"remote-source"}]',
        );
        when(() => mockApi.webDavService.webdavDownload(any(), file))
            .thenThrow(StateError('远端文件不存在或网络失败'));
        await readNotifier().saveConfig(
          'https://dav.example',
          'u',
          'p',
          '/dir/',
        );
        await readNotifier().loadConfig();

        final message = await readNotifier().restoreFromWebDav();

        expect(readState().status, SyncStatus.error);
        expect(message, contains('恢复失败'));
        expect(message, contains('远端文件不存在或网络失败'));
        expect(readState().lastSyncTime?.millisecondsSinceEpoch, 1234);
        expect(
          (await SharedPreferences.getInstance()).getInt('sync_last_time'),
          1234,
        );
        verifyNever(() => mockApi.bookshelfRepository.importBooks(any()));
        verifyNever(
          () => mockApi.bookSourceRepository.importBookSources(any()),
        );
        verifyNever(
          () => mockApi.webDavService.webdavFullSync(any(), any(), any()),
        );
      });

      for (final (label, payload) in [
        ('空响应', ''),
        ('损坏JSON', '[{'),
        ('null', 'null'),
        ('对象代替数组', '{}'),
        ('非对象条目', '[1]'),
        ('缺少标识', '[{}]'),
        ('空标识', '[{"bookUrl":" ","bookSourceUrl":" "}]'),
        ('非字符串标识', '[{"bookUrl":1,"bookSourceUrl":1}]'),
      ]) {
        test('$file$label在任何导入前被拒绝', () async {
          stubSyncApis(
            remoteBooks: '[{"bookUrl":"remote-book"}]',
            remoteSources: '[{"bookSourceUrl":"remote-source"}]',
          );
          when(() => mockApi.webDavService.webdavDownload(any(), file))
              .thenAnswer((_) async => payload);
          await readNotifier().saveConfig(
            'https://dav.example',
            'u',
            'p',
            '/dir/',
          );

          final message = await readNotifier().restoreFromWebDav();

          expect(readState().status, SyncStatus.error);
          expect(readState().lastSyncTime, isNull);
          expect(message, contains(file));
          verifyNever(() => mockApi.bookshelfRepository.importBooks(any()));
          verifyNever(
            () => mockApi.bookSourceRepository.importBookSources(any()),
          );
          verifyNever(
            () => mockApi.webDavService.webdavFullSync(any(), any(), any()),
          );
        });
      }
    }

    test('恢复原样保留扩展字段，不按Dart模型重编码载荷', () async {
      const books = '[ {"bookUrl":"remote-book", "extra":{"flag":true}} ]';
      const sources = '[ {"bookSourceUrl":"remote-source", "extra":[1,2]} ]';
      stubSyncApis(remoteBooks: books, remoteSources: sources);
      await readNotifier().saveConfig('https://dav.example', 'u', 'p', '/dir/');

      expect(await readNotifier().restoreFromWebDav(), '恢复完成，回写 1 本书籍、1 条书源');

      verify(() => mockApi.bookshelfRepository.importBooks(books)).called(1);
      verify(() => mockApi.bookSourceRepository.importBookSources(sources))
          .called(1);
    });

    test('书籍导入失败不继续书源导入，不覆盖原同步时间', () async {
      SharedPreferences.setMockInitialValues({'sync_last_time': 1234});
      stubSyncApis(
        remoteBooks: '[{"bookUrl":"remote-book"}]',
        remoteSources: '[{"bookSourceUrl":"remote-source"}]',
      );
      when(() => mockApi.bookshelfRepository.importBooks(any()))
          .thenThrow(StateError('书籍导入失败'));
      await readNotifier().saveConfig('https://dav.example', 'u', 'p', '/dir/');
      await readNotifier().loadConfig();

      final message = await readNotifier().restoreFromWebDav();

      expect(readState().status, SyncStatus.error);
      expect(message, contains('书籍导入失败'));
      expect(readState().lastSyncTime?.millisecondsSinceEpoch, 1234);
      expect(
        (await SharedPreferences.getInstance()).getInt('sync_last_time'),
        1234,
      );
      verify(() => mockApi.bookshelfRepository.importBooks(any())).called(1);
      verifyNever(() => mockApi.bookSourceRepository.importBookSources(any()));
    });

    test('书籍已导入但书源失败报告部分完成，不重做导入或更新时间', () async {
      SharedPreferences.setMockInitialValues({'sync_last_time': 1234});
      stubSyncApis(
        remoteBooks: '[{"bookUrl":"remote-book"}]',
        remoteSources: '[{"bookSourceUrl":"remote-source"}]',
      );
      when(() => mockApi.bookshelfRepository.importBooks(any()))
          .thenAnswer((_) async => 1);
      when(() => mockApi.bookSourceRepository.importBookSources(any()))
          .thenThrow(StateError('书源写入失败'));
      await readNotifier().saveConfig('https://dav.example', 'u', 'p', '/dir/');
      await readNotifier().loadConfig();

      final message = await readNotifier().restoreFromWebDav();

      expect(readState().status, SyncStatus.error);
      expect(message, contains('恢复未完成，已回写 1 本书籍；书源恢复失败'));
      expect(message, contains('书源写入失败'));
      expect(readState().error, message);
      expect(readState().lastSyncTime?.millisecondsSinceEpoch, 1234);
      expect(
        (await SharedPreferences.getInstance()).getInt('sync_last_time'),
        1234,
      );
      verify(() => mockApi.bookshelfRepository.importBooks(any())).called(1);
      verify(() => mockApi.bookSourceRepository.importBookSources(any()))
          .called(1);
      verify(
        () => mockApi.webDavService.webdavDownload(any(), 'bookshelf.json'),
      ).called(1);
      verify(() => mockApi.webDavService.webdavDownload(any(), 'sources.json'))
          .called(1);
      verifyNever(
        () => mockApi.webDavService.webdavFullSync(any(), any(), any()),
      );
    });

    for (final restore in [false, true]) {
      test('云端${restore ? '恢复' : '备份'}完成但时间记录失败保留旧时间和成功，不重做云端', () async {
        final metadata = _MetadataRepository();
        container = ProviderContainer(
          overrides: mergeTestOverrides([
            ...mockApi.overrides,
            syncMetadataRepositoryProvider.overrideWithValue(metadata),
          ]),
        );
        addTearDown(container.dispose);
        stubSyncApis();
        await readNotifier().saveConfig(
          'https://dav.example',
          'u',
          'p',
          '/dir/',
        );
        await readNotifier().loadConfig();
        if (restore) {
          expect(
            await readNotifier().restoreFromWebDav(),
            '恢复完成，回写 0 本书籍、0 条书源',
          );
        } else {
          await readNotifier().backupToWebDav();
        }
        expect(readState().status, SyncStatus.success);
        expect(readState().lastSyncTime?.millisecondsSinceEpoch, 1234);
        expect(readState().error, '云端同步已完成，但本地同步时间未保存');
        expect(metadata.saveCalls, 1);
        if (restore) {
          verify(
            () => mockApi.webDavService.webdavDownload(any(), 'bookshelf.json'),
          ).called(1);
          verify(
            () => mockApi.webDavService.webdavDownload(any(), 'sources.json'),
          ).called(1);
          verifyNever(
            () => mockApi.webDavService.webdavFullSync(any(), any(), any()),
          );
        } else {
          verify(
            () => mockApi.webDavService.webdavFullSync(any(), any(), any()),
          ).called(1);
        }
        metadata.failSave = false;
        await readNotifier().backupToWebDav();
        expect(readState().status, SyncStatus.success);
        expect(readState().lastSyncTime, metadata.saved);
        expect(readState().error, isNull);
        verify(() => mockApi.webDavService.webdavFullSync(any(), any(), any()))
            .called(1);
      });
    }

    test('时间读取失败向调用方报告，不沿用连接进行云端操作', () async {
      final metadata = _MetadataRepository()..failLoad = true;
      container = ProviderContainer(
        overrides: mergeTestOverrides([
          ...mockApi.overrides,
          syncMetadataRepositoryProvider.overrideWithValue(metadata),
        ]),
      );
      addTearDown(container.dispose);
      await expectLater(readNotifier().loadConfig(), throwsStateError);
      expect(readState().status, SyncStatus.idle);
      verifyNever(
        () => mockApi.webDavService.webdavFullSync(any(), any(), any()),
      );
    });

    test('backupToWebDav 未配置时设置错误', () async {
      await readNotifier().backupToWebDav();
      expect(readState().status, equals(SyncStatus.error));
      expect(readState().error, equals('请先配置 WebDAV 服务器信息'));
    });

    test('restoreFromWebDav 未配置时返回提示', () async {
      final msg = await readNotifier().restoreFromWebDav();
      expect(readState().status, equals(SyncStatus.error));
      expect(msg, equals('请先配置 WebDAV 服务器信息'));
    });

    test('backupToWebDav 配置后调用 webdavFullSync 成功', () async {
      stubSyncApis();
      await readNotifier().saveConfig(
        'https://dav.com',
        'user',
        'pass',
        '/dir/',
      );

      await readNotifier().backupToWebDav();

      final state = readState();
      expect(state.status, equals(SyncStatus.success));
      expect(state.error, isNull);
      expect(state.lastSyncTime, isNotNull);
      verify(() => mockApi.webDavService.webdavFullSync(any(), any(), any()))
          .called(1);
    });

    test('backupToWebDav 失败时设置错误', () async {
      when(() => mockApi.bookshelfRepository.getBooks())
          .thenThrow(Exception('网络错误'));
      await readNotifier().saveConfig(
        'https://dav.com',
        'user',
        'pass',
        '/dir/',
      );

      await readNotifier().backupToWebDav();

      expect(readState().status, equals(SyncStatus.error));
      expect(readState().error, contains('备份失败'));
    });

    test('restoreFromWebDav 回写远端书源', () async {
      stubSyncApis(remoteSources: '[{"bookSourceUrl":"https://a.com"}]');
      await readNotifier().saveConfig(
        'https://dav.com',
        'user',
        'pass',
        '/dir/',
      );

      final msg = await readNotifier().restoreFromWebDav();

      expect(readState().status, equals(SyncStatus.success));
      expect(msg, '恢复完成，回写 0 本书籍、1 条书源');
      verify(() => mockApi.bookSourceRepository.importBookSources(any()))
          .called(1);
    });

    test('restoreFromWebDav 远端书源为空时不回写', () async {
      stubSyncApis(remoteSources: '[]');
      await readNotifier().saveConfig(
        'https://dav.com',
        'user',
        'pass',
        '/dir/',
      );

      final msg = await readNotifier().restoreFromWebDav();

      expect(readState().status, equals(SyncStatus.success));
      expect(msg, '恢复完成，回写 0 本书籍、0 条书源');
      verifyNever(() => mockApi.bookshelfRepository.importBooks(any()));
      verifyNever(() => mockApi.bookSourceRepository.importBookSources(any()));
    });
  });

  group('SyncNotifier lastSyncTimeLabel', () {
    test('刚刚同步显示"刚刚"', () async {
      stubSyncApis();
      await readNotifier().saveConfig(
        'https://dav.com',
        'user',
        'pass',
        '/dir/',
      );
      await readNotifier().backupToWebDav();

      expect(readState().lastSyncTimeLabel, equals('刚刚'));
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
