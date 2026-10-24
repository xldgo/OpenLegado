import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../domain/models/highlight_rule.dart';
import '../../../services/settings_write_queue.dart';

/// 阅读器持有解码资源，离开阅读器时统一释放。字体只注册一次。
class ReaderHighlightResources {
  final _images = <String, ui.Image>{};
  static final _fonts = <String>{};
  final _failed = <String>{};
  final _queue = SettingsWriteQueue();
  final _ninePatch = <String, Map<String, double>>{};
  bool _disposed = false;
  ui.Image? image(String path) => _images[path];
  Future<Uint8List> _bytes(String path) async {
    if (path.startsWith('assets://')) {
      return (await rootBundle.load('assets/${path.substring(9)}')).buffer
          .asUint8List();
    }
    if (path.startsWith('assets/')) {
      return (await rootBundle.load(path)).buffer.asUint8List();
    }
    return File(
      path.startsWith('file://') ? Uri.parse(path).toFilePath() : path,
    ).readAsBytes();
  }

  Future<void> prepare(List<HighlightMatch> matches) => _queue.run(() async {
    if (_disposed) return;
    final fonts = <String>{};
    final images = <String>{};
    for (final match in matches) {
      final font = match.style['fontPath'] as String?;
      final image = match.style['bgImage'] as String?;
      if (font != null && font.isNotEmpty) fonts.add(font);
      if (image != null && image.isNotEmpty) images.add(image);
    }
    for (final path in fonts.difference(_fonts)) {
      if (_failed.contains(path)) continue;
      try {
        final bytes = await _bytes(path);
        await (FontLoader(
          'Highlight:$path',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        _fonts.add(path);
      } catch (e) {
        _failed.add(path);
        debugPrint('高亮字体无法加载，使用正文默认字体：$e');
      }
    }
    for (final path in images.where(
      (p) => !_images.containsKey(p) && !_failed.contains(p),
    )) {
      try {
        final codec = await ui.instantiateImageCodec(await _bytes(path));
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        if (_disposed) {
          image.dispose();
        } else {
          _images[path] = image;
          if (path.toLowerCase().endsWith('.9.png')) {
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            if (data != null && image.width >= 3 && image.height >= 3) {
              final bytes = data.buffer.asUint8List(
                data.offsetInBytes,
                data.lengthInBytes,
              );
              bool marked(int x, int y) {
                final offset = (y * image.width + x) * 4;
                return bytes[offset + 3] > 0 &&
                    bytes[offset] < 32 &&
                    bytes[offset + 1] < 32 &&
                    bytes[offset + 2] < 32;
              }

              (int, int)? run(int length, bool horizontal) {
                for (var start = 1; start < length - 1; start++) {
                  if (!marked(horizontal ? start : 0, horizontal ? 0 : start)) {
                    continue;
                  }
                  var end = start;
                  while (end + 1 < length - 1 &&
                      marked(
                        horizontal ? end + 1 : 0,
                        horizontal ? 0 : end + 1,
                      )) {
                    end++;
                  }
                  return (start, end);
                }
                return null;
              }

              final x = run(image.width, true), y = run(image.height, false);
              if (x != null && y != null) {
                _ninePatch[path] = {
                  'ninePatchLeft': (x.$1 - 1) / (image.width - 2),
                  'ninePatchRight':
                      (image.width - 2 - x.$2) / (image.width - 2),
                  'ninePatchTop': (y.$1 - 1) / (image.height - 2),
                  'ninePatchBottom':
                      (image.height - 2 - y.$2) / (image.height - 2),
                };
              }
            }
          }
        }
      } catch (e) {
        _failed.add(path);
        debugPrint('高亮背景无法加载，保留正文：$e');
      }
    }
  });

  Map<String, Object?> background(Map<String, dynamic> style) {
    final path = style['bgImage'] as String;
    final image = _images[path];
    final fit = (style['bgImageFit'] as num?)?.toInt() ?? 0;
    var slices = <String, double>{
      'ninePatchLeft': (style['npLeft'] as num?)?.toDouble() ?? .1,
      'ninePatchRight': (style['npRight'] as num?)?.toDouble() ?? .1,
      'ninePatchTop': (style['npTop'] as num?)?.toDouble() ?? .1,
      'ninePatchBottom': (style['npBottom'] as num?)?.toDouble() ?? .1,
    };
    if (style['manualNineSlice'] == false) slices = _ninePatch[path] ?? slices;
    final guide = _ninePatch.containsKey(path) ? 1 : 0;
    final w = (image?.width ?? 0) - guide * 2,
        h = (image?.height ?? 0) - guide * 2;
    int l = 0, r = 0, t = 0, b = 0;
    if (fit == 3 && w > 0 && h > 0) {
      l = (w * slices['ninePatchLeft']!).round();
      r = (w * slices['ninePatchRight']!).round();
      t = (h * slices['ninePatchTop']!).round();
      b = (h * slices['ninePatchBottom']!).round();
      final maxEdges = h - (h * .25).round();
      if (t + b > maxEdges && t + b > 0) {
        t = (t * maxEdges / (t + b)).round();
        b = maxEdges - t;
      }
      if (l + r > w - 1 && l + r > 0) {
        l = (l * (w - 1) / (l + r)).round();
        r = w - 1 - l;
      }
      slices = {
        'ninePatchLeft': l / w,
        'ninePatchRight': r / w,
        'ninePatchTop': t / h,
        'ninePatchBottom': b / h,
      };
    }
    return {
      'source': path,
      'fit': fit,
      'scale': style['bgImageScale'] ?? 1,
      ...slices,
      'lengthOffsetLeftPx': style['bgLengthOffsetLeft'] ?? 0,
      'lengthOffsetRightPx': style['bgLengthOffsetRight'] ?? 0,
      'contentInsetLeftPx': l.toDouble(),
      'contentInsetRightPx': r.toDouble(),
      'contentInsetTopPx': t.toDouble(),
      'contentInsetBottomPx': b.toDouble(),
      'contentBandHeightPx': (h - t - b).toDouble(),
    };
  }

  bool hasGuide(String path) => _ninePatch.containsKey(path);

  void dispose() {
    _disposed = true;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }
}

class ReaderHighlightResourceScope extends InheritedWidget {
  const ReaderHighlightResourceScope({
    super.key,
    required this.resources,
    required super.child,
  });
  final ReaderHighlightResources resources;
  static ReaderHighlightResources? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ReaderHighlightResourceScope>()
      ?.resources;
  @override
  bool updateShouldNotify(ReaderHighlightResourceScope oldWidget) =>
      !identical(resources, oldWidget.resources);
}
