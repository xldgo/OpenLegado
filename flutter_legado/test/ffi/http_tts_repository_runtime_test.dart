library;

/// 使用已有 Windows DLL 复核配置 CRUD，不访问真实 TTS 网络。— Codex + Bridge
@Timeout(Duration(minutes: 3))
import 'dart:convert';
import 'dart:io';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  if (!Platform.isWindows) {
    test('HTTP 引擎真实 FFI 需要 Windows DLL', () {}, skip: '未提供 Windows DLL');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  test('真实配置直接调用新 Repository，更新导入导出及删除沿用既有语义', () async {
    SharedPreferences.setMockInitialValues({});
    final root = Directory(
      '.dart_tool/http-tts-${DateTime.now().microsecondsSinceEpoch}',
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
    final repository = api.httpTtsRepository;
    expect(await repository.getHttpTts(), isEmpty);
    const input = HttpTts(
      name: '真实引擎',
      url: 'http://example.test/?text={{text}}',
    );
    final added = await repository.addHttpTts(input);
    expect(added.id, greaterThan(0));
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
