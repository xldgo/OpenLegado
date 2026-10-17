library;

/// 使用已有 Windows DLL 验证校验三项直接适配，不访问真实站点。— Codex + Bridge
@Timeout(Duration(minutes: 3))
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' show BridgeError;
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/models/book_source.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';

void main() {
  if (!Platform.isWindows) {
    test('校验真实 FFI 需要 Windows DLL', () {}, skip: '没有 Windows DLL');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();

  test('单源配置、数据库批量进度及取消沿用现有 FRB，初始化保持同一实例', () async {
    SharedPreferences.setMockInitialValues({});
    final root = Directory(
      '.dart_tool/source-checker-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final api = createTestApplication(
      useMock: false,
      bootstrap: RustBootstrap(
        runtime: const NativeRustRuntime(),
        environment: _Environment(root.absolute.path),
        configurationSource: SettingsRuntimeConfiguration(),
      ),
    );
    await initializeTestApplication(api: api);
    final checker = api.sourceChecker;
    const source = BookSource(
      bookSourceUrl: 'fixture://offline-check',
      bookSourceName: '离线校验',
    );
    final config = jsonEncode({
      'check_search': false,
      'check_toc': false,
      'check_content': false,
    });
    await api.bookSourceRepository.addBookSource(source);
    final result = await checker.checkSource(source, configJson: config);
    expect(result['source_url'], source.bookSourceUrl);
    expect(result, containsPair('total_time_ms', isA<num>()));
    await expectLater(
      checker.checkSource(source, configJson: '坏 JSON'),
      throwsA(isA<BridgeError>()),
    );
    final events = await checker.checkSourcesStream([
      source.bookSourceUrl,
      'fixture://missing',
    ], configJson: config).toList();
    expect(events, hasLength(2));
    expect(events.map((event) => event['index']), [0, 1]);
    expect(events.map((event) => event['total']), [2, 2]);
    expect(events.map((event) => event['is_last']), [false, true]);
    expect(events.first['source_name'], source.bookSourceName);
    expect(events.first['result']['source_url'], source.bookSourceUrl);
    expect(events.last['result']['search_ok'], isFalse);
    expect(events.last['result']['search_error'], '书源不存在');
    await checker.cancelCheckSources();
    await api.runtime.initialize();
    expect(api.sourceChecker, same(checker));
    await api.bookSourceRepository.deleteBookSource(source.bookSourceUrl);
    expect(await checker.checkSourcesStream([]).toList(), isEmpty);
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
  Future<String?> deviceId() async => 'source-checker-fixture';
}
