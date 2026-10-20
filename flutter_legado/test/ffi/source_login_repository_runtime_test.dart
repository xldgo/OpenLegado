@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

/// 原始凭据接口的真实宿主 FFI 回归；使用隔离数据库。— Codex + Bridge
import '../helpers/native_ffi.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('凭据两类字符串按源隔离，清空、覆盖和重复初始化保持', () async {
    SharedPreferences.setMockInitialValues({});
    final root = Directory(
      '.dart_tool/source-login-${DateTime.now().microsecondsSinceEpoch}',
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
    final repository = api.sourceLoginRepository;
    expect(await repository.getLoginInfo('fixture://A'), '');
    const info = '{"邮箱":"a@test","密码":"fixture-only","unknown":{"n":1}}';
    const header = '{"Cookie":"sid=a=b","Authorization":"fixture"}';
    await repository.putLoginInfo('fixture://A', info);
    await repository.putLoginHeader('fixture://A', header);
    expect(await repository.getLoginInfo('fixture://A'), info);
    expect(await repository.getLoginHeader('fixture://A'), header);
    expect(await repository.getLoginHeader('fixture://B'), '');
    await repository.putLoginInfo('fixture://B', '非 JSON 字符串');
    expect(await repository.getLoginInfo('fixture://B'), '非 JSON 字符串');
    await repository.putLoginHeader('fixture://A', '');
    expect(await repository.getLoginHeader('fixture://A'), '');
    expect(await repository.getLoginInfo('fixture://A'), info);
    await repository.putLoginInfo('fixture://A', '{"token":"new"}');
    expect(await repository.getLoginInfo('fixture://A'), '{"token":"new"}');
    await api.runtime.initialize();
    expect(api.sourceLoginRepository, same(repository));
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
  Future<String?> deviceId() async => 'source-login-fixture';
}
