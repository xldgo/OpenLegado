/// 页面布局数据不依赖Flutter几何对象或平台插件。— Codex + UI
enum PaddingRegion { header, body, footer }

enum ReaderPageEdge { header, footer }

final class ReaderPagePadding {
  const ReaderPagePadding({
    this.top = 0,
    this.bottom = 0,
    this.left = 0,
    this.right = 0,
  });
  final double top;
  final double bottom;
  final double left;
  final double right;
  @override
  bool operator ==(Object other) =>
      other is ReaderPagePadding &&
      top == other.top &&
      bottom == other.bottom &&
      left == other.left &&
      right == other.right;
  @override
  int get hashCode => Object.hash(top, bottom, left, right);
}

/// 页眉或页脚的布局与提示编号，正文之外的信息不进入原文坐标。
final class ReaderPageEdgeSettings {
  const ReaderPageEdgeSettings({
    this.padding = const ReaderPagePadding(),
    this.mode = 0,
    this.showLine = false,
    this.leftTip = 0,
    this.middleTip = 0,
    this.rightTip = 0,
  });
  final ReaderPagePadding padding;
  final int mode;
  final bool showLine;
  final int leftTip;
  final int middleTip;
  final int rightTip;
  @override
  bool operator ==(Object other) =>
      other is ReaderPageEdgeSettings &&
      padding == other.padding &&
      mode == other.mode &&
      showLine == other.showLine &&
      leftTip == other.leftTip &&
      middleTip == other.middleTip &&
      rightTip == other.rightTip;
  @override
  int get hashCode =>
      Object.hash(padding, mode, showLine, leftTip, middleTip, rightTip);
}

final class ReaderTitleSettings {
  const ReaderTitleSettings({
    this.mode = 0,
    this.size = 0,
    this.topSpacing = 0,
    this.bottomSpacing = 0,
  });
  final int mode;

  /// 字号相对正文的增量，间距沿用原数值单位。
  final int size;
  final int topSpacing;
  final int bottomSpacing;
  @override
  bool operator ==(Object other) =>
      other is ReaderTitleSettings &&
      mode == other.mode &&
      size == other.size &&
      topSpacing == other.topSpacing &&
      bottomSpacing == other.bottomSpacing;
  @override
  int get hashCode => Object.hash(mode, size, topSpacing, bottomSpacing);
}

final class ReaderPageLayoutSettings {
  const ReaderPageLayoutSettings({
    this.bodyPadding = const ReaderPagePadding(
      top: 24,
      bottom: 24,
      left: 20,
      right: 20,
    ),
    this.header = const ReaderPageEdgeSettings(
      padding: ReaderPagePadding(left: 16, right: 16),
      leftTip: 2,
      rightTip: 3,
    ),
    this.footer = const ReaderPageEdgeSettings(
      padding: ReaderPagePadding(top: 6, bottom: 6, left: 16, right: 16),
      showLine: true,
      leftTip: 7,
      rightTip: 6,
    ),
    this.title = const ReaderTitleSettings(),
    this.doubleHorizontalPage = 0,
  });
  final ReaderPagePadding bodyPadding;
  final ReaderPageEdgeSettings header;
  final ReaderPageEdgeSettings footer;
  final ReaderTitleSettings title;
  final int doubleHorizontalPage;

  ReaderPagePadding paddingFor(PaddingRegion region) => switch (region) {
    PaddingRegion.header => header.padding,
    PaddingRegion.body => bodyPadding,
    PaddingRegion.footer => footer.padding,
  };

  /// 保留当前恢复入口的值，与首次正文缺省分别定义。
  static ReaderPagePadding resetPaddingFor(PaddingRegion region) =>
      switch (region) {
        PaddingRegion.header => const ReaderPagePadding(left: 16, right: 16),
        PaddingRegion.body || PaddingRegion.footer => const ReaderPagePadding(
          top: 6,
          bottom: 6,
          left: 16,
          right: 16,
        ),
      };

  @override
  bool operator ==(Object other) =>
      other is ReaderPageLayoutSettings &&
      bodyPadding == other.bodyPadding &&
      header == other.header &&
      footer == other.footer &&
      title == other.title &&
      doubleHorizontalPage == other.doubleHorizontalPage;
  @override
  int get hashCode =>
      Object.hash(bodyPadding, header, footer, title, doubleHorizontalPage);
}
