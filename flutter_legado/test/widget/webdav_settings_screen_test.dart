/// WebDAV 设置页「测试配置」行（差异清单 C7）
///
/// 覆盖「地址为空」提示分支：未填写服务器地址时点击「测试配置」
/// 应弹出 SnackBar「请先填写服务器地址」，且行尾状态保持「未测试」。
///
/// — full-stack-engineer + UI ｜ 2026-09-10
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/domain/contracts/webdav_connection_repository.dart';
import 'package:flutter_legado/src/domain/models/webdav_connection.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/webdav_connection_provider.dart';
import 'package:flutter_legado/src/domain/contracts/sync_metadata_repository.dart';
import 'package:flutter_legado/src/providers/sync_metadata_provider.dart';
import 'package:flutter_legado/src/providers/sync/sync_notifier.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';
import 'package:flutter_legado/src/screens/webdav_settings_screen.dart';

import '../mocks/mocks.dart';

class _ConnectionRepository extends Fake implements WebDavConnectionRepository {
  WebDavConnection saved = const WebDavConnection(url: 'https://saved.example');
  bool failSave = true;
  bool failLoad = false;

  @override
  Future<WebDavConnection> load() async {
    if (failLoad) throw StateError('模拟读取失败');
    return saved;
  }

  @override
  Future<WebDavConnection> save(WebDavConnection connection) async {
    if (failSave) throw StateError('模拟保存失败');
    return saved = connection.normalized;
  }
}

class _MetadataRepository implements SyncMetadataRepository {
  bool failSave = true;
  DateTime? saved = DateTime.fromMillisecondsSinceEpoch(1234);
  @override
  Future<DateTime?> load() async => saved;
  @override
  Future<void> save(DateTime time) async {
    if (failSave) throw StateError('模拟时间保存失败');
    saved = time;
  }
}

void main() {
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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWithValue(mockApi),
          if (repository != null)
            webDavConnectionRepositoryProvider.overrideWithValue(repository),
          if (metadata != null)
            syncMetadataRepositoryProvider.overrideWithValue(metadata),
        ],
        child: const MaterialApp(home: WebDavSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('云端成功但时间记录失败显示持久警告，未接线策略保持禁用', (tester) async {
    SharedPreferences.setMockInitialValues({
      'sync_webdav_url': 'https://dav.example',
      'sync_webdav_username': 'u',
      'sync_webdav_password': 'p',
      'sync_auto': true,
      'sync_book_progress_plus': true,
      'app_backup_path': 'E:/备份',
    });
    when(() => mockApi.webdavFullSync(any(), any(), any()))
        .thenAnswer((_) async => '{}');
    when(() => mockApi.backup(any()))
        .thenAnswer((_) async => 'E:/备份/backup.zip');
    final metadata = _MetadataRepository();
    await pumpScreen(tester, metadata: metadata);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WebDavSettingsScreen)),
    );
    await tester.scrollUntilVisible(find.text('同步书籍进度增强'), 120);
    final enhanced = tester
        .widgetList<SettingSwitchRow>(find.byType(SettingSwitchRow))
        .singleWhere((row) => row.title == '同步书籍进度增强');
    expect(enhanced.onChanged, isNull);
    expect(enhanced.value, isTrue);
    expect(find.text('自动同步'), findsNothing);
    await tester.scrollUntilVisible(find.text('备份'), 120);
    await tester.tap(find.text('备份'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    // 等待本地备份成功的短提示离场，再核对不会随提示计时消失的记录警告。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    const warning = '云端同步已完成，但本地同步时间未保存';
    await tester.scrollUntilVisible(find.text(warning), 150);
    await tester.pumpAndSettle();
    expect(find.text(warning).hitTestable(), findsOneWidget);
    expect(container.read(syncNotifierProvider).status, SyncStatus.success);
    expect(
      container.read(syncNotifierProvider).lastSyncTime?.millisecondsSinceEpoch,
      1234,
    );
    await tester.pump(const Duration(seconds: 6));
    expect(find.text(warning).hitTestable(), findsOneWidget);
    metadata.failSave = false;
    await tester.scrollUntilVisible(find.text('备份'), -120);
    await tester.tap(find.text('备份'));
    await tester.pumpAndSettle();
    expect(find.text(warning), findsNothing);
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
  });

  testWidgets('地址非 http(s)：点击「测试配置」提示地址格式错误', (tester) async {
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

    expect(find.text('服务器地址需要以 http(s):// 开头'), findsOneWidget);
    // 未发起探测，状态保持「未测试」
    expect(find.text('未测试'), findsOneWidget);
  });
}
