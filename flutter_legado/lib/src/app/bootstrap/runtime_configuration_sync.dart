import 'package:flutter/foundation.dart' show debugPrint;

import '../../data/bridge/runtime_configuration.dart';

/// 启动和设置刷新共用的配置注入协调器。— Codex + UI
class RuntimeConfigurationSync implements ReadingConfigSync, ThemeConfigSync {
  RuntimeConfigurationSync({
    required this.source,
    required this.sink,
    void Function(String)? log,
  }) : _log = log ?? debugPrint;

  final RuntimeConfigurationSource source;
  final RuntimeConfigurationSink sink;
  final void Function(String) _log;
  Future<void> _themeTail = Future.value();

  @override
  Future<void> synchronizeThemeConfig() {
    final result = _themeTail.then((_) async {
      await sink.setThemeConfig(await source.readThemeConfig());
      await sink.setThemeMode(await source.readThemeMode());
    });
    _themeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> refreshThemeConfig() async {
    try {
      // 保留先写主题，再读取和写主题模式的顺序及部分成功语义。
      await synchronizeThemeConfig();
    } catch (e) {
      _log('[启动] 主题注入失败，保留 Rust 现有值或默认值：$e');
    }
  }

  @override
  Future<void> refreshReadBookConfig() async {
    try {
      await sink.setReadBookConfig(await source.readReadBookConfig());
    } catch (e) {
      _log('[启动] 阅读配置注入失败，保留 Rust 现有值或默认值：$e');
    }
  }
}
