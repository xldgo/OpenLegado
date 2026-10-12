import 'package:flutter/widgets.dart';

/// 同一次排版与绘制共用的文字环境，不含正文配色。
@immutable
class TextLayoutEnvironment {
  final TextStyle baseStyle;
  final TextScaler textScaler;
  final TextDirection direction;
  final Locale? locale;
  final TextHeightBehavior? heightBehavior;

  const TextLayoutEnvironment({
    required this.baseStyle,
    required this.textScaler,
    required this.direction,
    this.locale,
    this.heightBehavior,
  });

  factory TextLayoutEnvironment.of(
    BuildContext context, {
    TextStyle? baseStyle,
    TextScaler? textScaler,
  }) => TextLayoutEnvironment(
    baseStyle: baseStyle ?? DefaultTextStyle.of(context).style,
    textScaler: textScaler ?? MediaQuery.textScalerOf(context),
    direction: Directionality.of(context),
    locale: Localizations.maybeLocaleOf(context),
    heightBehavior:
        DefaultTextStyle.of(context).textHeightBehavior ??
        DefaultTextHeightBehavior.maybeOf(context),
  );

  @override
  bool operator ==(Object other) =>
      other is TextLayoutEnvironment &&
      baseStyle == other.baseStyle &&
      textScaler == other.textScaler &&
      direction == other.direction &&
      locale == other.locale &&
      heightBehavior == other.heightBehavior;

  @override
  int get hashCode =>
      Object.hash(baseStyle, textScaler, direction, locale, heightBehavior);
}

/// 字形簇边界只在此处转换为原文 UTF-16 偏移。
class TextClusterMap {
  final List<String> clusters;
  final List<int> sourceOffsets;
  final Map<int, int> _clusterIndices;

  TextClusterMap(String text)
    : clusters = text.characters.toList(),
      sourceOffsets = [0],
      _clusterIndices = {0: 0} {
    for (final cluster in clusters) {
      sourceOffsets.add(sourceOffsets.last + cluster.length);
      _clusterIndices[sourceOffsets.last] = sourceOffsets.length - 1;
    }
  }

  int clusterIndex(int sourceOffset) =>
      _clusterIndices[sourceOffset] ??
      (throw ArgumentError.value(sourceOffset, 'sourceOffset', '不在字形簇边界'));
}
