/// 已接线的跨功能普通偏好，保留原键与默认值。— Codex + UI
final class GeneralSettings {
  const GeneralSettings({
    this.defaultBookTreeUri = '',
    this.showAddToShelfAlert = true,
    this.showMangaUi = true,
    this.webPort = 1122,
    this.defaultToRead = false,
    this.sourceEditMaxLines = 0,
  });

  final String defaultBookTreeUri;
  final bool showAddToShelfAlert;
  final bool showMangaUi;
  final int webPort;

  /// 冷启动默认进入上次阅读（对齐上游 OtherSettings.defaultToRead）
  final bool defaultToRead;

  /// 0为不限；有限行数只限制源编辑框高度，不限制文本长度。— Codex + UI
  final int sourceEditMaxLines;
  static const minimumSourceEditMaxLines = 10;

  @override
  bool operator ==(Object other) =>
      other is GeneralSettings &&
      defaultBookTreeUri == other.defaultBookTreeUri &&
      showAddToShelfAlert == other.showAddToShelfAlert &&
      showMangaUi == other.showMangaUi &&
      webPort == other.webPort &&
      defaultToRead == other.defaultToRead &&
      sourceEditMaxLines == other.sourceEditMaxLines;

  @override
  int get hashCode => Object.hash(
    defaultBookTreeUri,
    showAddToShelfAlert,
    showMangaUi,
    webPort,
    defaultToRead,
    sourceEditMaxLines,
  );
}
