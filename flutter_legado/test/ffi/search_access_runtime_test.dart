library;

/// 搜索访问接口的真实 Windows FFI 回归；使用隔离数据库。— Codex + Bridge
@Timeout(Duration(minutes: 3))
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';

import 'dart:convert';

void main() {
  if (!Platform.isWindows) {
    test('搜索真实 FFI 需要 Windows DLL', () {}, skip: '没有 Windows DLL');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  test('历史五项和搜索七项经新接口真实调用，使用隔离库与本机 HTTP', () async {
    SharedPreferences.setMockInitialValues({});
    final root = Directory(
      '.dart_tool/search-access-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<html><body><div class="book"><a href="/book/1">边界测试书</a>'
        '<span class="author">边界作者</span></div><h1>边界测试书</h1>'
        '<p id="author">边界作者</p></body></html>',
      );
      await request.response.close();
    });
    final sourceUrl = 'http://127.0.0.1:${server.port}';
    final api = createTestApplication(
      useMock: false,
      bootstrap: RustBootstrap(
        runtime: NativeRustRuntime(
          libraryResolver: Platform.environment['LEGADO_TEST_DLL'] == null
              ? null
              : () => ExternalLibrary.open(
                  Platform.environment['LEGADO_TEST_DLL']!,
                ),
        ),
        environment: _Environment(root.absolute.path),
        configurationSource: SettingsRuntimeConfiguration(),
      ),
    );
    await initializeTestApplication(api: api);
    final history = api.searchHistoryRepository;
    expect(await history.getSearchHistory(), isEmpty);
    await history.addSearchKeyword('边界甲', '书名甲');
    await history.addSearchKeyword('边界乙', '书名乙');
    expect(await history.getSearchHistory(limit: 1), hasLength(1));
    expect(await history.searchHistoryByPrefix('边界甲'), ['边界甲']);
    await history.deleteSearchKeyword('边界甲');
    expect(await history.searchHistoryByPrefix('边界甲'), isEmpty);
    await history.clearSearchHistory();
    expect(await history.getSearchHistory(), isEmpty);
    expect(
      await api.bookSourceRepository.importBookSources(
        jsonEncode([
          {
            'bookSourceUrl': sourceUrl,
            'bookSourceName': '本机搜索边界',
            'bookSourceType': 0,
            'enabled': true,
            'searchUrl': '$sourceUrl/search?key={{key}}&page={{page}}',
            'ruleSearch': {
              'bookList': '.book',
              'name': 'a@text',
              'author': '.author@text',
              'bookUrl': 'a@href',
            },
            'ruleBookInfo': {'name': 'h1@text', 'author': '#author@text'},
          },
        ]),
      ),
      1,
    );
    final service = api.searchService;
    final urls = [sourceUrl];
    final books = await service.searchBooks('边界', sourceUrls: urls);
    expect(books.single.book.name, '边界测试书');
    final precise = await service.preciseSearch(
      '边界测试书',
      '边界作者',
      sourceUrls: urls,
    );
    expect(precise.name, '边界测试书');
    expect(await service.searchMulti('边界', sourceUrls: urls), isNotEmpty);
    final batches = await service
        .searchMultiStream('边界', sourceUrls: urls, page: 2)
        .toList();
    expect(batches, hasLength(1));
    final batch = batches.single;
    expect(batch.sourceUrl, sourceUrl);
    expect(batch.sourceName, '本机搜索边界');
    expect(batch.books.single.book.name, '边界测试书');
    expect(batch.finishedCount, 1);
    expect(batch.totalCount, 1);
    expect(batch.isLast, isTrue);
    expect(batch.hasMore, isTrue);
    expect(batch.error, isNull);
    await service.pauseSearch();
    await service.resumeSearch();
    await service.cancelSearch();
    await api.runtime.initialize();
    expect(api.searchService, same(service));
    expect(api.searchHistoryRepository, same(history));
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
  Future<String?> deviceId() async => 'search-access-fixture';
}
