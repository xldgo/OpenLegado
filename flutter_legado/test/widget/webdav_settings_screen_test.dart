library;

import 'dart:async';

import 'package:flutter_legado/src/domain/models/webdav_probe_result.dart';

import 'package:flutter_legado/src/domain/models/backup_restore_stats.dart';

import '../fixtures/app_test_api.dart';

/// WebDAV 设置页「测试配置」行（差异清单 C7）
///
/// 覆盖「地址为空」提示分支：未填写服务器地址时点击「测试配置」
/// 应弹出 SnackBar「请先填写服务器地址」，且行尾状态保持「未测试」。
///
/// — full-stack-engineer + UI ｜ 2026-09-10

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/domain/contracts/webdav_connection_repository.dart';
import 'package:flutter_legado/src/domain/models/webdav_connection.dart';
import 'package:flutter_legado/src/providers/webdav_connection_provider.dart';
import 'package:flutter_legado/src/domain/contracts/sync_metadata_repository.dart';
import 'package:flutter_legado/src/providers/sync_metadata_provider.dart';
import 'package:flutter_legado/src/features/settings/presentation/webdav_settings_screen.dart';
import 'package:flutter_legado/src/data/services/backup_service.dart';
import 'package:flutter_legado/src/app/bootstrap/restored_settings_refresher.dart';
import 'package:flutter_legado/src/providers/backup_provider.dart';
import 'package:flutter_legado/src/providers/restored_settings_provider.dart';

import '../mocks/mocks.dart';

class _ConnectionRepository extends Fake implements WebDavConnectionRepository {
  WebDavConnection saved = const WebDavConnection(url: 'https://saved.example');
  bool failSave = true;
  bool failLoad = false;
  int saveCalls = 0;

  @override
  Future<WebDavConnection> load() async {
    if (failLoad) throw StateError('模拟读取失败');
    return saved;
  }

  @override
  Future<WebDavConnection> save(WebDavConnection connection) async {
    saveCalls++;
    if (failSave) throw StateError('模拟保存失败');
    return saved = connection.normalized;
  }
}

class _BackupService extends Mock implements BackupService {}

void main() {
  Future<void> scrollTo(WidgetTester tester, Finder target, double delta) =>
      tester.scrollUntilVisible(
        target,
        delta,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );

  late MockRustApi mockApi;

  setUpAll(registerFallbacks);

  setUp(() {
    // 页面 initState 会触发 SyncNotifier.loadConfig 与 CrashLogService 读偏好
    SharedPreferences.setMockInitialValues({});
    mockApi = MockRustApi();
    when(() => mockApi.bookshelfRepository.getBooks())
        .thenAnswer((_) async => const []);
    when(() => mockApi.bookSourceRepository.getBookSources())
        .thenAnswer((_) async => const []);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    WebDavConnectionRepository? repository,
    SyncMetadataRepository? metadata,
    BackupService? backup,
    RestoredSettingsRefresher? refresher,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...mockApi.overrides,
          if (repository != null)
            webDavConnectionRepositoryProvider.overrideWithValue(repository),
          if (metadata != null)
            syncMetadataRepositoryProvider.overrideWithValue(metadata),
          if (backup != null) backupServiceProvider.overrideWithValue(backup),
          if (refresher != null)
            restoredSettingsRefresherProvider.overrideWithValue(refresher),
        ]),
        child: const MaterialApp(home: WebDavSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('恢复提交后界面刷新失败仍保留统计与失败项', (tester) async {
    SharedPreferences.setMockInitialValues({
      'sync_webdav_url': 'https://dav.example',
      'sync_webdav_username': 'user',
      'sync_webdav_password': 'secret',
    });
    final backup = _BackupService();
    when(() => backup.listRemoteBackups(any()))
        .thenAnswer((_) async => ['fixture.zip']);
    when(() => backup.restoreFromWebDav(any(), fileName: 'fixture.zip'))
        .thenAnswer(
          (_) async => (
            stats: const BackupRestoreStats(
              books: 1,
              bookmarks: 0,
              replaceRules: 0,
              bookSources: 2,
              rssSources: 0,
              readRecords: 0,
            ),
            preferencesError: null,
            warnings: <String>[],
          ),
        );
    var refreshedShelf = false;
    final refresher = RestoredSettingsRefresher([
      ('主题', () async => throw StateError('模拟刷新失败')),
      (
        '书架',
        () async {
          refreshedShelf = true;
        },
      ),
    ]);
    await pumpScreen(tester, backup: backup, refresher: refresher);
    await scrollTo(tester, find.text('恢复').hitTestable(), 120);
    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('fixture.zip'));
    await tester.pumpAndSettle();
    expect(refreshedShelf, isTrue);
    expect(find.textContaining('已恢复3条业务记录').hitTestable(), findsOneWidget);
    expect(find.textContaining('部分界面刷新失败：主题').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('连接保存失败提示并保持已保存展示，再编辑成功可重试', (tester) async {
    final repository = _ConnectionRepository();
    await pumpScreen(tester, repository: repository);
    expect(find.text('https://saved.example'), findsOneWidget);

    await tester.tap(find.text('WebDAV 服务器地址'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://unsaved.example');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('WebDAV 连接保存失败，请重试'), findsOneWidget);
    expect(find.text('https://saved.example'), findsOneWidget);
    expect(find.text('https://unsaved.example'), findsNothing);
    expect(repository.saved.url, 'https://saved.example');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('WebDAV 服务器地址'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'https://saved.example',
    );
    repository.failSave = false;
    await tester.enterText(find.byType(TextField), ' https://retry.example ');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('https://retry.example'), findsOneWidget);
    expect(repository.saved.url, 'https://retry.example');
    expect(tester.takeException(), isNull);
  });

  testWidgets('连接读取异常由页面提示处理', (tester) async {
    final repository = _ConnectionRepository()..failLoad = true;
    await pumpScreen(tester, repository: repository);
    expect(find.text('备份设置读取失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('地址为空：点击「测试配置」提示「请先填写服务器地址」', (tester) async {
    await pumpScreen(tester);

    // 行尾初始为「未测试」
    expect(find.text('未测试'), findsOneWidget);

    await tester.tap(find.text('测试配置'));
    await tester.pumpAndSettle();

    expect(find.text('请先填写服务器地址'), findsOneWidget);
    // 未发起探测，状态保持「未测试」
    expect(find.text('未测试'), findsOneWidget);
    expect(find.text('✗ 失败'), findsNothing);
    verifyNever(() => mockApi.webDavService.webdavProbe(any()));
  });

  testWidgets('连接测试展示异步结果，失败后可重试且不保存或同步', (tester) async {
    final repository = _ConnectionRepository();
    final pending = Completer<WebDavProbeResult>();
    when(() => mockApi.webDavService.webdavProbe(any()))
        .thenAnswer((_) => pending.future);
    await pumpScreen(tester, repository: repository);
    await tester.tap(find.text('测试配置'));
    await tester.pump();
    await tester.tap(find.text('测试配置'));
    verify(() => mockApi.webDavService.webdavProbe(repository.saved)).called(1);
    pending.complete(
      const WebDavProbeResult(
        WebDavProbeStatus.authenticationFailed,
        statusCode: 401,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('认证失败，请检查账号/密码'), findsOneWidget);
    expect(find.text('✗ 失败'), findsOneWidget);

    when(() => mockApi.webDavService.webdavProbe(any())).thenAnswer(
      (_) async =>
          const WebDavProbeResult(WebDavProbeStatus.success, statusCode: 207),
    );
    await tester.tap(find.text('测试配置'));
    await tester.pumpAndSettle();
    expect(find.text('✓ 连接成功'), findsOneWidget);
    expect(repository.saveCalls, 0);
    verify(() => mockApi.webDavService.webdavProbe(repository.saved)).called(1);
    verifyNever(
      () => mockApi.webDavService.webdavFullSync(any(), any(), any()),
    );
  });

  testWidgets('地址非 http(s)：点击「测试配置」提示地址格式错误', (tester) async {
    when(() => mockApi.webDavService.webdavProbe(any())).thenAnswer(
      (_) async => const WebDavProbeResult(WebDavProbeStatus.invalidUrl),
    );
    await pumpScreen(tester);

    // 通过「WebDAV 服务器地址」行填入非法地址（弹框前该文案仅行标题一处）
    await tester.tap(find.text('WebDAV 服务器地址'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'dav.example.com');
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    // 此时 subtitle 显示已填地址，行可点击
    expect(find.text('dav.example.com'), findsWidgets);

    await tester.tap(find.text('测试配置'));
    await tester.pumpAndSettle();

    expect(find.text('服务器地址无效，请填写完整的 http(s):// 地址'), findsOneWidget);
    expect(find.text('✗ 失败'), findsOneWidget);
    final tested =
        verify(() => mockApi.webDavService.webdavProbe(captureAny()))
                .captured
                .single
            as WebDavConnection;
    expect(tested.url, 'dav.example.com');
  });
}
