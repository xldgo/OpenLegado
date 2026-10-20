import 'package:flutter/foundation.dart' show debugPrint;

import '../../data/bridge/runtime_configuration.dart';
import '../../data/bridge/rust_runtime.dart';
import '../../platform/app_environment.dart';
import 'runtime_configuration_sync.dart';

/// 仅编排依赖与失败边界，平台访问和 FFI 各自实现。— Codex + UI
class RustBootstrap {
  RustBootstrap({
    required this.runtime,
    required this.environment,
    required RuntimeConfigurationSource configurationSource,
    void Function(String)? log,
  }) : configurationSync = RuntimeConfigurationSync(
         source: configurationSource,
         sink: runtime,
         log: log,
       ),
       _log = log ?? debugPrint;

  final RustRuntime runtime;
  final AppEnvironment environment;
  final RuntimeConfigurationSync configurationSync;
  final void Function(String) _log;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await runtime.initialize();
    await runtime.openDatabase(await environment.databasePath());

    try {
      await environment.warmLocalBookStore();
    } catch (_) {
      // 本地书路径预热失败仍按原实现忽略，不阻止启动。
    }
    for (final cache in RuntimeCache.values) {
      try {
        final path = await environment.cacheDirectory(cache);
        switch (cache) {
          case RuntimeCache.tts:
            final ok = await runtime.setTtsCacheDirectory(path);
            _log('[启动] TTS 缓存目录注入：$path（ok=$ok）');
          case RuntimeCache.js:
            await runtime.setJsCacheDirectory(path);
          case RuntimeCache.image:
            await runtime.setImageCacheDirectory(path);
          case RuntimeCache.audio:
            await runtime.setAudioCacheDirectory(path);
        }
      } catch (e) {
        _log('[启动] ${cache.name} 缓存目录注入失败，保留 Rust 默认目录：$e');
      }
    }
    try {
      final id = await environment.deviceId();
      if (id != null && id.isNotEmpty) await runtime.setDeviceId(id);
    } catch (e) {
      _log('[启动] 设备 ID 注入失败：$e');
    }
    await configurationSync.refreshThemeConfig();
    await configurationSync.refreshReadBookConfig();
    _initialized = true;
  }
}
