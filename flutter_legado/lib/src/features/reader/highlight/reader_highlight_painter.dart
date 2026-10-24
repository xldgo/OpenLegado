import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show Matrix4;
import 'package:path_drawing/path_drawing.dart';

import '../layout/reader_layout_element.dart';
import 'reader_highlight_resources.dart';

/// 只绘制既有布局，不参与测量、断行或正文命中测试。
class ReaderHighlightPainter {
  ReaderHighlightPainter(
    List<ReaderGlyph> glyphs,
    this.resources,
    this.baseColor,
  ) {
    var from = 0;
    while (from < glyphs.length) {
      final first = glyphs[from];
      final style = first.style;
      var to = from + 1;
      while (to < glyphs.length &&
          ((glyphs[to - 1].style['matchSpacingAfterPx'] as num?) ?? 0) <= 0 &&
          ((glyphs[to].style['matchSpacingBeforePx'] as num?) ?? 0) <= 0 &&
          const DeepCollectionEquality().equals(
            _decoration(style),
            _decoration(glyphs[to].style),
          )) {
        to++;
      }
      final bounds = glyphs
          .sublist(from, to)
          .fold(
            first.bounds,
            (ui.Rect rect, g) => rect.expandToInclude(g.bounds),
          );
      final underline = style['underline'] as Map?;
      ui.Path? path;
      if (underline?['mode'] == 5 &&
          (underline?['svgPath'] as String?)?.isNotEmpty == true) {
        try {
          path = parseSvgPathData(underline!['svgPath'] as String);
        } on Exception {
          /* 无效资源不影响正文。 */
        }
      }
      _runs.add((
        bounds: bounds,
        baseline: first.baseline,
        style: style,
        svg: path,
      ));
      from = to;
    }
  }
  final ReaderHighlightResources? resources;
  final Color baseColor;
  final _runs =
      <
        ({
          ui.Rect bounds,
          double baseline,
          Map<String, dynamic> style,
          ui.Path? svg,
        })
      >[];
  static Object _decoration(Map<String, dynamic> s) => [
    s['backgroundArgb'],
    s['backgroundImage'],
    s['underline'],
  ];

  void paintBackground(ui.Canvas canvas, ui.Offset offset) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    for (final run in _runs) {
      final color = run.style['backgroundArgb'] as num?;
      if (color != null) {
        canvas.drawRect(run.bounds, ui.Paint()..color = Color(color.toInt()));
      }
      final background = run.style['backgroundImage'] as Map?;
      final source = background?['source'] as String?;
      final image = source == null ? null : resources?.image(source);
      if (image != null && background != null) {
        _image(canvas, image, run.bounds, background);
      }
      final u = run.style['underline'] as Map?;
      if (u?['mode'] == 7) {
        final p = ui.Paint()
          ..color =
              (u!['inheritColor'] == true
                      ? baseColor
                      : Color((u['colorArgb'] as num).toInt()))
                  .withValues(alpha: .4);
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(run.bounds, const ui.Radius.circular(2)),
          p,
        );
      }
    }
    canvas.restore();
  }

  void paintLines(ui.Canvas canvas, ui.Offset offset) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    for (final run in _runs) {
      final u = run.style['underline'] as Map?;
      final mode = (u?['mode'] as num?)?.toInt() ?? 0;
      if (mode == 0 || mode == 7) continue;
      final width = (u!['widthPx'] as num).toDouble();
      final p = ui.Paint()
        ..color = (u['inheritColor'] == true
            ? baseColor
            : Color((u['colorArgb'] as num).toInt()))
        ..strokeWidth = width
        ..style = ui.PaintingStyle.stroke;
      final y = mode == 6
          ? run.baseline - run.bounds.height * .3
          : run.baseline + (u['offsetPx'] as num).toDouble();
      final start = ui.Offset(run.bounds.left, y),
          end = ui.Offset(run.bounds.right, y);
      switch (mode) {
        case 2:
          for (var x = start.dx; x < end.dx; x += 13) {
            canvas.drawLine(
              ui.Offset(x, y),
              ui.Offset(math.min(x + 8, end.dx), y),
              p,
            );
          }
        case 3:
          final path = ui.Path()..moveTo(start.dx, y);
          for (var x = start.dx; x <= end.dx; x += 1) {
            path.lineTo(x, y + math.sin((x - start.dx) * math.pi / 6) * 3);
          }
          canvas.drawPath(path, p);
        case 4:
          canvas.drawLine(start, end, p);
          canvas.drawLine(
            start + const ui.Offset(0, 3),
            end + const ui.Offset(0, 3),
            p,
          );
        case 5:
          final path = run.svg;
          if (path == null) continue;
          final bounds = path.getBounds();
          if (bounds.width <= 0) continue;
          canvas.save();
          canvas.translate(start.dx, y);
          canvas.scale(run.bounds.width / bounds.width, 1);
          canvas.translate(-bounds.left, -bounds.top);
          canvas.drawPath(path, p);
          canvas.restore();
        default:
          canvas.drawLine(start, end, p);
      }
    }
    canvas.restore();
  }

  void _image(
    ui.Canvas canvas,
    ui.Image image,
    ui.Rect bounds,
    Map background,
  ) {
    final scale = (background['scale'] as num).toDouble();
    final fit = (background['fit'] as num).toInt();
    final left = (background['lengthOffsetLeftPx'] as num?)?.toDouble() ?? 0;
    final right = (background['lengthOffsetRightPx'] as num?)?.toDouble() ?? 0;
    var destination = ui.Rect.fromLTRB(
      bounds.left - left,
      bounds.top,
      bounds.right + right,
      bounds.bottom,
    );
    final border = resources?.hasGuide(background['source'] as String) == true
        ? 1.0
        : 0.0;
    final source = ui.Rect.fromLTRB(
      border,
      border,
      image.width - border,
      image.height - border,
    );
    if (destination.isEmpty) return;
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..isAntiAlias = false;
    if (fit == 3) {
      final l = (background['contentInsetLeftPx'] as num).toDouble();
      final r = (background['contentInsetRightPx'] as num).toDouble();
      final t = (background['contentInsetTopPx'] as num).toDouble();
      final b = (background['contentInsetBottomPx'] as num).toDouble();
      final band = (background['contentBandHeightPx'] as num).toDouble();
      if (band <= 0) return;
      final factor = bounds.height * scale / band;
      final overhang = bounds.height * (scale - 1) / 2;
      destination = ui.Rect.fromLTRB(
        destination.left - l * factor,
        destination.top - overhang - t * factor,
        destination.right + r * factor,
        destination.bottom + overhang + b * factor,
      );
      final xs = [source.left, source.left + l, source.right - r, source.right];
      final ys = [source.top, source.top + t, source.bottom - b, source.bottom];
      final dx = [
        destination.left,
        destination.left + l * factor,
        destination.right - r * factor,
        destination.right,
      ];
      final dy = [
        destination.top,
        destination.top + t * factor,
        destination.bottom - b * factor,
        destination.bottom,
      ];
      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 3; x++) {
          final src = ui.Rect.fromLTRB(xs[x], ys[y], xs[x + 1], ys[y + 1]);
          final dst = ui.Rect.fromLTRB(dx[x], dy[y], dx[x + 1], dy[y + 1]);
          if (!src.isEmpty && !dst.isEmpty) {
            canvas.drawImageRect(image, src, dst, paint);
          }
        }
      }
    } else if (fit == 0) {
      canvas.save();
      canvas.clipRect(destination);
      final matrix = Matrix4.identity()
        ..translateByDouble(destination.left, destination.top, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
      final shader = ui.ImageShader(
        image,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        matrix.storage,
      );
      paint.shader = shader;
      canvas.drawRect(destination, paint);
      paint.shader = null;
      shader.dispose();
      canvas.restore();
    } else {
      final width = fit == 1
          ? destination.width * scale
          : source.width *
                math.max(
                  destination.width / source.width,
                  destination.height / source.height,
                ) *
                scale;
      final height = fit == 1
          ? destination.height * scale
          : width * source.height / source.width;
      final target = ui.Rect.fromCenter(
        center: destination.center,
        width: width,
        height: height,
      );
      canvas.save();
      canvas.clipRect(destination);
      canvas.drawImageRect(image, source, target, paint);
      canvas.restore();
    }
  }
}
