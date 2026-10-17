library;

/// 使用真实 Windows DLL 复核拆分后的启动与 JS 配置注入。
@Timeout(Duration(minutes: 3))
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/app_settings_factory.dart';
import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';

void main() {
  if (!Platform.isWindows) {
    test('启动真实 FFI 验证需要 Windows DLL', () {}, skip: '未提供 Windows DLL');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();

  test('应用工厂启动真实运行时，JS 读取原快照，刷新不重复初始化', () async {
    SharedPreferences.setMockInitialValues({
      'app_theme_mode': 'dark',
      'reader_bg_color_index': 4,
      'reader_font_size': 21.6,
    });
    final root = Directory(
      '.dart_tool/rust-bootstrap-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final settings = createAppSettingsService();
    addTearDown(settings.dispose);
    final readerSettings = AppReaderSettingsRepository(settings);
    final source = SettingsRuntimeConfiguration(
      appSettings: settings,
      readerSettings: readerSettings,
    );
    final startup = RustBootstrap(
      runtime: const NativeRustRuntime(),
      environment: _IsolatedEnvironment(root.absolute.path),
      configurationSource: source,
    );
    final api = createTestApplication(useMock: false, bootstrap: startup);
    expect(await initializeTestApplication(api: api), same(api));
    expect(await api.runtime.getVersion(), isNotEmpty);
    expect(await api.bookmarkRepository.getAllBookmarks(), isEmpty);
    expect(
      jsonDecode(
        await api.ruleExecutionService.evalJs('java.getThemeConfig()'),
      ),
      (await source.readThemeConfig()).fields,
    );
    expect(
      await api.ruleExecutionService.evalJs('java.getThemeMode()'),
      'dark',
    );
    expect(
      jsonDecode(
        await api.ruleExecutionService.evalJs('java.getReadBookConfig()'),
      ),
      (await source.readReadBookConfig()).fields,
    );

    await readerSettings.update(fontSize: 28.0);
    await readingConfigSyncFor(api).refreshReadBookConfig();
    expect(
      (jsonDecode(
        await api.ruleExecutionService.evalJs('java.getReadBookConfig()'),
      ) as Map)['textSize'],
      28,
    );
    // 若再次加载 FRB，生成运行时会拒绝重复初始化；Bootstrap 必须直接返回。
    await api.runtime.initialize();
    expect(await api.bookmarkRepository.getAllBookmarks(), isEmpty);
  });
}

/// 只隔离设备路径，运行时及配置注入使用正式实现。
class _IsolatedEnvironment implements AppEnvironment {
  _IsolatedEnvironment(this.root);
  final String root;

  @override
  Future<String> databasePath() async =>
      '$root${Platform.pathSeparator}legado.db';
  @override
  Future<void> warmLocalBookStore() async {}
  @override
  Future<String> cacheDirectory(RuntimeCache cache) async =>
      (await Directory('$root${Platform.pathSeparator}${cache.name}_cache')
              .create(recursive: true))
          .path;
  @override
  Future<String?> deviceId() async => 'bootstrap-fixture-device';
}
