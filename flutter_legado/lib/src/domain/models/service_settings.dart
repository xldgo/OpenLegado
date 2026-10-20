/// 服务普通设置的类型化快照，存储键仅由数据层解释。— Codex + UI
final class ServiceSettings {
  const ServiceSettings({
    this.webAutoStart = false,
    this.autoTaskEnabled = false,
    this.mcpPort = 0,
    this.customHosts = '',
  });
  final bool webAutoStart;
  final bool autoTaskEnabled;
  final int mcpPort;
  final String customHosts;
  ServiceSettings copyWith({
    bool? webAutoStart,
    bool? autoTaskEnabled,
    int? mcpPort,
    String? customHosts,
  }) => ServiceSettings(
    webAutoStart: webAutoStart ?? this.webAutoStart,
    autoTaskEnabled: autoTaskEnabled ?? this.autoTaskEnabled,
    mcpPort: mcpPort ?? this.mcpPort,
    customHosts: customHosts ?? this.customHosts,
  );
}
