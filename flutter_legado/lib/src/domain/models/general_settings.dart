/// 已接线的跨功能普通偏好，保留原键与默认值。— Codex + UI
final class GeneralSettings {
  const GeneralSettings({
    this.defaultBookTreeUri = '',
    this.showAddToShelfAlert = true,
    this.webPort = 1122,
  });

  final String defaultBookTreeUri;
  final bool showAddToShelfAlert;
  final int webPort;

  @override
  bool operator ==(Object other) =>
      other is GeneralSettings &&
      defaultBookTreeUri == other.defaultBookTreeUri &&
      showAddToShelfAlert == other.showAddToShelfAlert &&
      webPort == other.webPort;

  @override
  int get hashCode =>
      Object.hash(defaultBookTreeUri, showAddToShelfAlert, webPort);
}
