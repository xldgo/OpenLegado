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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWithValue(mockApi),
          if (repository != null)
            webDavConnectionRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: WebDavSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

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
