/// 已接线的跨功能普通偏好，保留原键与默认值。— Codex + UI
final class GeneralSettings {
  const GeneralSettings({
    this.defaultBookTreeUri = '',
    this.showAddToShelfAlert = true,
    this.webPort = 1122,
    this.defaultToRead = false,
  });

  final String defaultBookTreeUri;
  final bool showAddToShelfAlert;
  final int webPort;

  /// 冷启动默认进入上次阅读（对齐上游 OtherSettings.defaultToRead）
  final bool defaultToRead;

  @override
  bool operator ==(Object other) =>
      other is GeneralSettings &&
      defaultBookTreeUri == other.defaultBookTreeUri &&
      showAddToShelfAlert == other.showAddToShelfAlert &&
      webPort == other.webPort &&
      defaultToRead == other.defaultToRead;

  @override
  int get hashCode => Object.hash(
    defaultBookTreeUri,
    showAddToShelfAlert,
    webPort,
    defaultToRead,
  );
}
