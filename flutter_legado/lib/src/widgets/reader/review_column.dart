import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'dart:math' as math;

import '../paragraph_layout_engine.dart';
import 'text_layout_environment.dart';

/// 段末评论角标（对齐原版 [ReviewColumn]）
///
/// Apple 风格：轻量气泡 + 数字，仅 count > 0 时展示。
/// — Bridge/UI · Auto ｜ 2026-08-13
class ReviewColumnBadge extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;
  final Size? layoutSize;
  final bool compact;

  const ReviewColumnBadge({
    super.key,
    required this.count,
    this.onTap,
    this.layoutSize,
    this.compact = false,
  });

  String get _label {
    if (count >= 1000) return '999+';
    return '$count';
  }

  static const _style = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 按封顶文本测量固定槽宽，正数之间变化只需重绘。
  static (Size, double, Size) measure(BuildContext context) {
    final environment = TextLayoutEnvironment.of(context);
    final painter = TextPainter(
      text: TextSpan(
        text: '999+',
        style: environment.baseStyle
            .merge(_style)
            .copyWith(
              fontWeight: MediaQuery.boldTextOf(context)
                  ? FontWeight.bold
                  : _style.fontWeight,
            ),
      ),
      textDirection: environment.direction,
      textScaler: environment.textScaler,
      locale: environment.locale,
      textHeightBehavior: environment.heightBehavior,
      maxLines: 1,
    )..layout();
    final height = math.max(18.0, painter.height + 2);
    final size = Size(6 + math.max(22.0, painter.width + 10), height);
    final baseline =
        (height - painter.height) / 2 +
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    painter.dispose();
    return (size, baseline, Size(24, height));
  }

  static Map<int, InlineReview> measureParagraphs(
    BuildContext context,
    String source,
    Map<int, int>? counts,
  ) {
    if (counts == null || !counts.values.any((count) => count > 0)) return {};
    final (size, baseline, compactSize) = measure(context);
    final paragraphs = splitChapterParagraphs(source);
    return {
      for (var i = 0; i < paragraphs.length; i++)
        if ((counts[i + 1] ?? 0) > 0)
          i + 1: InlineReview(
            paragraphId: i + 1,
            reviewKey: i + 1,
            sourceAnchor: paragraphs[i].endIndex,
            count: counts[i + 1]!,
            size: size,
            baseline: baseline,
            compactSize: compactSize,
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = CupertinoColors.systemBlue.resolveFrom(context);
    final bg = isDark
        ? accent.withValues(alpha: 0.22)
        : accent.withValues(alpha: 0.12);
    final fg = isDark ? Colors.white : accent;

    final size =
        layoutSize ?? (compact ? measure(context).$3 : measure(context).$1);
    return Semantics(
      button: true,
      label: '查看段评，$count条评论',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Padding(
            padding: EdgeInsets.only(left: math.min(6, size.width / 3)),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: compact
                  ? FittedBox(
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 12,
                        color: fg,
                      ),
                    )
                  : Text(_label, style: _style.copyWith(color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}
