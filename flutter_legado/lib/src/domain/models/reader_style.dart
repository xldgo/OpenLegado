import 'dart:math' as math;

/// 一套阅读样式中的日间或夜间配色；空值表示使用默认背景或自动文字色。— Codex + UI
final class ReaderColors {
  const ReaderColors({this.background, this.text});
  final int? background;
  final int? text;

  /// 正文、预览与配置注入共用解析；亮度计算与 Flutter 的 sRGB 定义一致。
  ({int background, int text}) resolve({
    required bool isNight,
    required bool amoled,
  }) {
    final background =
        this.background ??
        (isNight
            ? amoled
                  ? 0xFF000000
                  : 0xFF1A1A1A
            : 0xFFFFFFFF);
    double channel(int shift) {
      final value = ((background >> shift) & 0xFF) / 255;
      return value <= 0.04045
          ? value / 12.92
          : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    }

    final luminance =
        0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
    return (
      background: background,
      text: text ?? (luminance < 0.5 ? 0xFFCCCCCC : 0xFF333333),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderColors &&
      background == other.background &&
      text == other.text;
  @override
  int get hashCode => Object.hash(background, text);
}

/// 样式的配色投影；排版由ReaderSettingsRepository按当前样式统一提供。— Codex + UI
final class ReaderStyle {
  const ReaderStyle({
    required this.id,
    required this.name,
    required this.day,
    required this.night,
  });
  final String id;
  final String name;
  final ReaderColors day;
  final ReaderColors night;

  bool get isPreset => readerStylePresets.any((preset) => preset.id == id);

  ReaderColors colors(bool isNight) => isNight ? night : day;
  ReaderStyle withColors(bool isNight, ReaderColors colors) => ReaderStyle(
    id: id,
    name: name,
    day: isNight ? day : colors,
    night: isNight ? colors : night,
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderStyle &&
      id == other.id &&
      name == other.name &&
      day == other.day &&
      night == other.night;
  @override
  int get hashCode => Object.hash(id, name, day, night);
}

/// 色值来自 HapeLee/legado-with-MD3@60a7cca 的 defaultData/readConfig.json。
/// 独立布局在首次关闭共用时以当前排版初始化，不套用Android的排版单位。— Codex + UI
const readerStylePresets = <ReaderStyle>[
  ReaderStyle(
    id: 'wechat',
    name: '微信读书',
    day: ReaderColors(background: 0xFFC0EDC6, text: 0xFF0B0B0B),
    night: ReaderColors(background: 0xFF000000, text: 0xFFADADAD),
  ),
  ReaderStyle(
    id: 'preset1',
    name: '预设1',
    day: ReaderColors(background: 0xFFFFFFFF, text: 0xFF000000),
    night: ReaderColors(background: 0xFF000000, text: 0xFFFFFFFF),
  ),
  ReaderStyle(
    id: 'preset2',
    name: '预设2',
    day: ReaderColors(background: 0xFFDDC090, text: 0xFF3E3422),
    night: ReaderColors(background: 0xFF3C3F43, text: 0xFFDCDFE1),
  ),
  ReaderStyle(
    id: 'preset3',
    name: '预设3',
    day: ReaderColors(background: 0xFFC2D8AA, text: 0xFF596C44),
    night: ReaderColors(background: 0xFF3C3F43, text: 0xFF88C16F),
  ),
  ReaderStyle(
    id: 'preset4',
    name: '预设4',
    day: ReaderColors(background: 0xFFDBB8E2, text: 0xFF68516C),
    night: ReaderColors(background: 0xFF3C3F43, text: 0xFFF6AEAE),
  ),
  ReaderStyle(
    id: 'preset5',
    name: '预设5',
    day: ReaderColors(background: 0xFFABCEE0, text: 0xFF3D4C54),
    night: ReaderColors(background: 0xFF3C3F43, text: 0xFF90BFF5),
  ),
];

/// 模板集合与当前选择的不可变快照；自定义配色随所属模板保存。
final class ReaderStyles {
  ReaderStyles({
    required this.selectedId,
    required Iterable<ReaderStyle> styles,
    this.shareLayout = true,
  }) : styles = List.unmodifiable(styles);
  factory ReaderStyles.defaults() => ReaderStyles(
    selectedId: 'custom',
    styles: [
      ...readerStylePresets,
      const ReaderStyle(
        id: 'custom',
        name: '自定义',
        day: ReaderColors(),
        night: ReaderColors(),
      ),
    ],
  );
  final String selectedId;
  final bool shareLayout;
  final List<ReaderStyle> styles;
  ReaderStyle get selected =>
      styles.firstWhere((style) => style.id == selectedId);
  ReaderStyles select(String id) {
    if (!styles.any((style) => style.id == id)) {
      throw ArgumentError('阅读样式不存在：$id');
    }
    return ReaderStyles(
      selectedId: id,
      styles: styles,
      shareLayout: shareLayout,
    );
  }

  ReaderStyles withShareLayout(bool value) =>
      ReaderStyles(selectedId: selectedId, styles: styles, shareLayout: value);

  ReaderStyles replace(ReaderStyle style) => ReaderStyles(
    selectedId: selectedId,
    shareLayout: shareLayout,
    styles: [
      for (final current in styles) current.id == style.id ? style : current,
    ],
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderStyles &&
      selectedId == other.selectedId &&
      shareLayout == other.shareLayout &&
      styles.length == other.styles.length &&
      List.generate(
        styles.length,
        (i) => styles[i] == other.styles[i],
      ).every((same) => same);
  @override
  int get hashCode =>
      Object.hash(selectedId, shareLayout, Object.hashAll(styles));
}
