import 'text_break_rules.dart';

/// 按 MD3 ChineseLineBreaker 的推进、回退和坐标契约移植。
/// 来源：HapeLee/legado-with-MD3，070ca1a9，core/layout/ChineseLineBreaker.kt。
/// Flutter 提供真实簇宽；首行容量独立传入，缩进不混进原文。
class ChineseLineBreaker {
  final List<String> clusters;
  final List<double> widths;
  final double width;
  final double firstLineWidth;
  final double ideographWidth;
  final List<int> clusterStarts = [0];
  final List<int> sourceStarts = [0];
  final List<double> lineWidths = [];

  ChineseLineBreaker({
    required this.clusters,
    required this.widths,
    required this.width,
    required this.firstLineWidth,
    required this.ideographWidth,
  }) {
    if (clusters.length != widths.length) {
      throw ArgumentError('字形簇与宽度数量不一致');
    }
    _breakLines();
  }

  void _addStart(int cluster, int source) {
    clusterStarts.add(cluster);
    sourceStarts.add(source);
  }

  int _safeStart(int candidate, int lineStart) {
    if (candidate <= lineStart || candidate >= clusters.length) {
      return candidate;
    }
    if (!TextBreakRules.insideWord(
      clusters[candidate - 1],
      clusters[candidate],
    )) {
      return candidate;
    }
    var wordStart = candidate;
    while (wordStart > lineStart &&
        TextBreakRules.insideWord(
          clusters[wordStart - 1],
          clusters[wordStart],
        )) {
      wordStart--;
    }
    return wordStart > lineStart &&
            !TextBreakRules.forbidden(
              clusters[wordStart - 1],
              clusters[wordStart],
            )
        ? wordStart
        : candidate;
  }

  void _breakLines() {
    var lineWidth = 0.0;
    var sourceOffset = 0;
    for (var index = 0; index < clusters.length; index++) {
      final cluster = clusters[index];
      lineWidth += widths[index];
      var carriedWidth = 0.0;
      var carriedSource = 0;
      var hung = false;
      final limit = lineWidths.isEmpty ? firstLineWidth : width;
      final lineStart = clusterStarts.last;
      // 单个字形簇不能拆分；最终整行宽度由 Flutter 塑形再次核对。
      if (lineWidth > limit && index > lineStart) {
        void carryFrom(int candidate) {
          final start = _safeStart(
            candidate,
            lineStart,
          ).clamp(lineStart + 1, index);
          for (var i = start; i <= index; i++) {
            carriedWidth += widths[i];
            carriedSource += clusters[i].length;
          }
          _addStart(start, sourceOffset + cluster.length - carriedSource);
        }

        bool compressible(int at) =>
            at >= lineStart &&
            at < widths.length &&
            widths[at] < ideographWidth;
        final previousClosing = TextBreakRules.closing.contains(
          clusters[index - 1],
        );
        final previousOpening = TextBreakRules.opening.contains(
          clusters[index - 1],
        );
        final secondOpening =
            index > lineStart + 1 &&
            TextBreakRules.opening.contains(clusters[index - 2]);
        final nextClosing =
            index < clusters.length - 1 &&
            TextBreakRules.closing.contains(clusters[index + 1]);
        final currentClosing = TextBreakRules.closing.contains(cluster);
        final compressibleAround = switch ((
          previousOpening,
          secondOpening,
          currentClosing,
          previousClosing,
        )) {
          (true, true, _, _) =>
            compressible(index - 1) || compressible(index - 2),
          (_, _, true, true) => compressible(index) || compressible(index - 1),
          (_, true, true, _) => compressible(index) || compressible(index - 2),
          _ => false,
        };
        final hangs =
            !compressibleAround &&
            !nextClosing &&
            ((previousOpening && secondOpening) ||
                (currentClosing && (previousClosing || secondOpening)));
        if (hangs) {
          _addStart(index + 1, sourceOffset + cluster.length);
          hung = true;
        } else if (previousOpening || currentClosing) {
          var candidate = index - 1;
          if (previousClosing || nextClosing || compressibleAround) {
            for (var at = index; at > lineStart; at--) {
              if (!TextBreakRules.forbidden(clusters[at - 1], clusters[at])) {
                candidate = at;
                break;
              }
            }
          }
          carryFrom(candidate);
        } else {
          carryFrom(index);
        }
        lineWidths.add(lineWidth - carriedWidth);
        lineWidth = carriedWidth;
      }
      if (index == clusters.length - 1 && !hung) {
        _addStart(index + 1, sourceOffset + cluster.length);
        lineWidths.add(lineWidth);
      }
      sourceOffset += cluster.length;
    }
  }
}
