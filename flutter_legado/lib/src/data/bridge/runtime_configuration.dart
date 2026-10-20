import 'dart:convert';

/// 进程注入的纯数据快照，不包含主题对象或平台插件。— Codex + Bridge
class RuntimeConfigSnapshot {
  RuntimeConfigSnapshot(Map<String, Object?> fields)
    : fields = Map.unmodifiable(fields);

  /// 现有主题、阅读协议均为只含标量的平面对象。
  final Map<String, Object?> fields;

  String encode() => jsonEncode(fields);
}

/// 设置层生成数据，Bridge 不读取 UI 主题或偏好。
abstract interface class RuntimeConfigurationSource {
  Future<RuntimeConfigSnapshot> readThemeConfig();
  Future<String> readThemeMode();
  Future<RuntimeConfigSnapshot> readReadBookConfig();
}

/// 原生注入入口，参数不依赖 Material/Cupertino。
abstract interface class RuntimeConfigurationSink {
  Future<void> setThemeConfig(RuntimeConfigSnapshot snapshot);
  Future<void> setThemeMode(String mode);
  Future<void> setReadBookConfig(RuntimeConfigSnapshot snapshot);
}

/// 阅读设置消费者只依赖配置刷新能力。
abstract interface class ReadingConfigSync {
  Future<void> refreshReadBookConfig();
}

/// 设置已经保存后的主题注入；失败向调用方报告，不回滚偏好。— Codex + Bridge
abstract interface class ThemeConfigSync {
  Future<void> synchronizeThemeConfig();
}

class NoopThemeConfigSync implements ThemeConfigSync {
  const NoopThemeConfigSync();

  @override
  Future<void> synchronizeThemeConfig() async {}
}

/// Mock 不启动原生运行时，也不注入配置。
class NoopReadingConfigSync implements ReadingConfigSync {
  const NoopReadingConfigSync();

  @override
  Future<void> refreshReadBookConfig() async {}
}
