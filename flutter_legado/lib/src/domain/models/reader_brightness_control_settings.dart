/// 菜单内亮度控件的显示方式，与实际亮度值分开保存。— Codex + UI
final class ReaderBrightnessControlSettings {
  const ReaderBrightnessControlSettings({this.mode = 0, this.onLeft = false});

  /// 0关闭，1横向，2纵向；关闭或横向时保留原侧栏位置。
  final int mode;
  final bool onLeft;

  @override
  bool operator ==(Object other) =>
      other is ReaderBrightnessControlSettings &&
      mode == other.mode &&
      onLeft == other.onLeft;

  @override
  int get hashCode => Object.hash(mode, onLeft);
}
