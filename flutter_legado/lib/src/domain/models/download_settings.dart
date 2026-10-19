/// 正文前后预下载偏好，数量范围与参考版一致。— Codex + UI
final class DownloadSettings {
  const DownloadSettings({
    this.preDownloadNum = 10,
    this.preDownloadNumPrev = 0,
  });

  static const minChapters = 0;
  static const maxChapters = 100;
  final int preDownloadNum;
  final int preDownloadNumPrev;

  DownloadSettings copyWith({int? preDownloadNum, int? preDownloadNumPrev}) =>
      DownloadSettings(
        preDownloadNum: preDownloadNum ?? this.preDownloadNum,
        preDownloadNumPrev: preDownloadNumPrev ?? this.preDownloadNumPrev,
      );

  @override
  bool operator ==(Object other) =>
      other is DownloadSettings &&
      preDownloadNum == other.preDownloadNum &&
      preDownloadNumPrev == other.preDownloadNumPrev;

  @override
  int get hashCode => Object.hash(preDownloadNum, preDownloadNumPrev);
}
