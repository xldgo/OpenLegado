library;

/// 搜索会话的真实宿主 FFI 回归；使用隔离数据库。— Codex + Bridge
@Timeout(Duration(minutes: 3))
import '../helpers/native_ffi.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';

import 'dart:convert';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_legado/src/features/search/search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('在途真实搜索暂停恢复、停止、再搜和迟到 HTTP 响应隔离', () async {
    SharedPreferences.setMockInitialValues({});
    final root = Directory(
      '.dart_tool/search-session-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final arrived = Completer<void>();
    final release = Completer<void>();
    addTearDown(() async {
      if (!release.isCompleted) release.complete();
      await server.close(force: true);
    });
    server.listen((request) async {
      final key = request.uri.queryParameters['key'] ?? '';
      if (key == '旧') {
        if (!arrived.isCompleted) arrived.complete();
        await release.future;
      }
      try {
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          '<html><div class="book"><a href="/book/$key">$key结果</a>'
          '<span class="author">作者</span></div></html>',
        );
        await request.response.close();
      } on HttpException {
        // 取消后客户端已经关闭连接，测试仍释放服务器请求。
      }
    });
    final sourceUrl = 'http://127.0.0.1:${server.port}';
    final api = createTestApplication(
      useMock: false,
      bootstrap: RustBootstrap(
        runtime: nativeTestRuntime(),
        environment: _Environment(root.absolute.path),
        configurationSource: SettingsRuntimeConfiguration(),
      ),
    );
    await initializeTestApplication(api: api);
    await api.bookSourceRepository.importBookSources(
      jsonEncode([
        {
          'bookSourceUrl': sourceUrl,
          'bookSourceName': '本机会话源',
          'enabled': true,
          'searchUrl': '$sourceUrl/search?key={{key}}',
          'ruleSearch': {
            'bookList': '.book',
            'name': 'a@text',
            'author': '.author@text',
            'bookUrl': 'a@href',
          },
        },
      ]),
    );
    final container = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    notifier.toggleSource(sourceUrl);
    await notifier.search('旧');
    await arrived.future.timeout(const Duration(seconds: 15));
    await notifier.pauseSearch();
    expect(container.read(searchNotifierProvider).isPaused, isTrue);
    await notifier.resumeSearch();
    expect(container.read(searchNotifierProvider).isPaused, isFalse);
    await notifier.stop().timeout(const Duration(seconds: 10));
    expect(container.read(searchNotifierProvider).isManualStop, isTrue);
    final completed = Completer<void>();
    final listener = container.listen(searchNotifierProvider, (_, next) {
      if (next.keyword == '新' && !next.isLoading && !completed.isCompleted) {
        completed.complete();
      }
    });
    addTearDown(listener.close);
    await notifier.search('新');
    await completed.future.timeout(const Duration(seconds: 15));
    expect(
      container.read(searchNotifierProvider).results.single.book.name,
      '新结果',
    );
    release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      container.read(searchNotifierProvider).results.single.book.name,
      '新结果',
    );
    expect(container.read(searchNotifierProvider).isManualStop, isFalse);
    expect(container.read(searchNotifierProvider).error, isNull);
  });
}

class _Environment implements AppEnvironment {
  _Environment(this.root);
  final String root;
  @override
  Future<String> databasePath() async =>
      '$root${Platform.pathSeparator}legado.db';
  @override
  Future<void> warmLocalBookStore() async {}
  @override
  Future<String> cacheDirectory(RuntimeCache cache) async =>
      (await Directory('$root${Platform.pathSeparator}${cache.name}')
              .create(recursive: true))
          .path;
  @override
  Future<String?> deviceId() async => 'search-session-fixture';
}
