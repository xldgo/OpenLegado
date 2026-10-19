library;

/// 使用当前宿主原生库 复核配置 CRUD，不访问真实 TTS 网络。— Codex + Bridge
@Timeout(Duration(minutes: 3))
import '../helpers/native_ffi.dart';

import 'dart:convert';
import 'dart:io';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('真实配置直接调用新 Repository，更新导入导出及删除沿用既有语义', () async {
    SharedPreferences.setMockInitialValues({});
    final root = Directory(
      '.dart_tool/http-tts-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final api = createTestApplication(
      useMock: false,
      bootstrap: RustBootstrap(
        runtime: nativeTestRuntime(),
        environment: _Environment(root.absolute.path),
        configurationSource: SettingsRuntimeConfiguration(),
      ),
    );
    await initializeTestApplication(api: api);
    final repository = api.httpTtsRepository;
    expect(await repository.getHttpTts(), isEmpty);
    const input = HttpTts(
      name: '真实引擎',
      url: 'http://example.test/?text={{text}}',
      contentType: 'audio/wav',
      pauseDuration: 120,
      concurrentRate: '1000',
      loginUrl: 'login()',
      loginUi: '[{"name":"Key"}]',
      header: '{"X-Test":"1"}',
      jsLib: 'var a=1;',
      enabledCookieJar: true,
      loginCheckJs: 'result',
      speed: 12,
      synthesisThreadCount: 4,
      lastUpdateTime: 9007199254740993,
      isEnabled: false,
    );
    final added = await repository.addHttpTts(input);
    expect(added.id, greaterThan(0));
    expect((await repository.getHttpTts()).single, added);
    expect((await repository.getHttpTts()).single.name, input.name);
    final updated = added.copyWith(
      name: '修改引擎',
      url: 'http://new.test/?text={{text}}',
    );
    await repository.updateHttpTts(updated);
    final stored = (await repository.getHttpTts()).single;
    expect(stored.id, added.id);
    expect(stored.name, updated.name);
    expect(stored.url, updated.url);
    expect(await repository.httpTtsSetEnabled(added.id, false), isTrue);
    expect((await repository.getHttpTts()).single.id, added.id);
    expect(
      await repository.importHttpTts(
        '[{"name":"导入引擎","url":"http://import.test"},{"name":""}]',
      ),
      1,
    );
    final exported = jsonDecode(await repository.exportHttpTts()) as List;
    expect(exported.length, 2);
    expect(exported.map((e) => e['name']), containsAll(['修改引擎', '导入引擎']));
    await repository.deleteHttpTts(added.id);
    await repository.deleteHttpTts(added.id);
    expect((await repository.getHttpTts()).single.name, '导入引擎');
    final remaining = (await repository.getHttpTts()).single;
    await repository.deleteHttpTts(remaining.id);
    expect(await repository.getHttpTts(), isEmpty);
    await api.runtime.initialize();
    expect(api.httpTtsRepository, same(repository));
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
  Future<String?> deviceId() async => 'http-tts-fixture';
}
